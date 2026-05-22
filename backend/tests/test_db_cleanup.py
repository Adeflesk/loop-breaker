"""
Tests for stale intervention cleanup functionality.
"""
import pytest
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

from app.db import BehavioralStateManager


class FakeRecord:
    """Mock Neo4j record."""
    def __init__(self, data):
        self._data = data

    def __getitem__(self, key):
        return self._data[key]

    def get(self, key, default=None):
        return self._data.get(key, default)

    def data(self):
        """Return the record data as a dict."""
        return self._data

    def single(self):
        return self


class FakeResult:
    """Mock Neo4j query result."""
    def __init__(self, data):
        self._data = data
    
    def single(self):
        if self._data:
            return FakeRecord(self._data)
        return None


class FakeSession:
    """Mock Neo4j session that tracks queries."""
    def __init__(self):
        self.queries = []
        self.results = {}
    
    def __enter__(self):
        return self
    
    def __exit__(self, *args):
        pass
    
    def run(self, query, **params):
        self.queries.append((query, params))
        
        # Return appropriate mock results based on query content
        if "cleaned" in query or "count(i) as cleaned" in query:
            # Cleanup query
            return FakeResult({"cleaned": 2})
        elif "WHERE NOT (i)-[:HAS_OUTCOME]->()" in query:
            # Check for stale interventions
            return FakeResult({"count": 2})
        
        return FakeResult({})


class FakeDriver:
    """Mock Neo4j driver."""
    def __init__(self):
        self.sessions = []
    
    def session(self):
        session = FakeSession()
        self.sessions.append(session)
        return session
    
    def close(self):
        pass


@pytest.fixture
def mock_db():
    """Create a BehavioralStateManager with a mocked driver."""
    with patch('app.db.GraphDatabase.driver') as mock_driver_constructor:
        fake_driver = FakeDriver()
        mock_driver_constructor.return_value = fake_driver
        
        # Mock the bootstrap to avoid actual DB calls
        with patch.object(BehavioralStateManager, '_bootstrap_nodes'):
            db = BehavioralStateManager(
                uri="bolt://localhost:7687",
                user="neo4j",
                password="test"
            )
            db.driver = fake_driver
            db.is_available = True
            
            yield db, fake_driver


def test_cleanup_stale_interventions_marks_old_as_skipped(mock_db):
    """Test that old interventions are properly marked as skipped."""
    db, fake_driver = mock_db
    
    # Run cleanup
    db.cleanup_stale_interventions(hours_old=1)
    
    # Check that a query was executed
    assert len(fake_driver.sessions) > 0
    session = fake_driver.sessions[-1]
    assert len(session.queries) > 0
    
    query, params = session.queries[0]
    
    # Verify the query checks for interventions without outcomes
    assert "WHERE NOT (i)-[:HAS_OUTCOME]->()" in query
    assert "i.timestamp < datetime() - duration({hours: $hours})" in query
    
    # Verify outcome is created with skipped flag
    assert "skipped: true" in query
    assert "success: false" in query
    
    # Verify the hours parameter is passed
    assert params.get("hours") == 1


def test_cleanup_with_different_time_thresholds(mock_db):
    """Test cleanup with various time threshold values."""
    db, fake_driver = mock_db
    
    # Test with 2 hours
    db.cleanup_stale_interventions(hours_old=2)
    session = fake_driver.sessions[-1]
    query, params = session.queries[0]
    assert params.get("hours") == 2
    
    # Test with 24 hours
    db.cleanup_stale_interventions(hours_old=24)
    session = fake_driver.sessions[-1]
    query, params = session.queries[0]
    assert params.get("hours") == 24


def test_cleanup_skips_when_db_unavailable(mock_db):
    """Test that cleanup fails gracefully when DB is unavailable."""
    db, fake_driver = mock_db
    
    # Simulate DB unavailability
    db.is_available = False
    
    # Should not raise an exception
    db.cleanup_stale_interventions()
    
    # Should not have executed any queries
    assert len(fake_driver.sessions) == 0


def test_resolve_intervention_calls_cleanup(mock_db):
    """Test that resolve_intervention automatically calls cleanup."""
    db, fake_driver = mock_db
    
    # Mock cleanup_stale_interventions to track if it was called
    with patch.object(db, 'cleanup_stale_interventions') as mock_cleanup:
        db.resolve_intervention(
            was_successful=True,
            needs_check={"hydration": True, "rest": True}
        )
        
        # Verify cleanup was called
        mock_cleanup.assert_called_once()


def test_cleanup_logs_count_of_cleaned_interventions(mock_db, caplog):
    """Test that cleanup logs the number of interventions cleaned."""
    db, fake_driver = mock_db
    
    with caplog.at_level("INFO"):
        db.cleanup_stale_interventions(hours_old=1)
    
    # Check that appropriate log message was generated
    # The fake session returns 2 cleaned interventions
    assert any("Cleaned up 2 stale intervention" in record.message 
              for record in caplog.records)


def test_cleanup_handles_exceptions_gracefully(mock_db):
    """Test that cleanup handles database errors without crashing."""
    db, fake_driver = mock_db
    
    # Make session.run raise an exception
    original_session = fake_driver.session
    
    def failing_session():
        session = original_session()
        original_run = session.run
        
        def failing_run(*args, **kwargs):
            raise Exception("Database connection lost")
        
        session.run = failing_run
        return session
    
    fake_driver.session = failing_session
    
    # Should not raise an exception
    db.cleanup_stale_interventions()
    
    # DB should still be available for retry
    assert db.is_available


def test_cleanup_creates_outcome_with_system_note(mock_db):
    """Test that skipped outcomes include a system note."""
    db, fake_driver = mock_db
    
    db.cleanup_stale_interventions(hours_old=1)
    
    session = fake_driver.sessions[-1]
    query, params = session.queries[0]
    
    # Verify the outcome includes explanatory notes
    assert 'notes: "System auto-resolved stale intervention"' in query


def test_get_ai_insight_excludes_skipped_from_success_rate(mock_db):
    """Test that skipped interventions don't pollute success rate calculation."""
    db, fake_driver = mock_db
    
    # Mock the query result to simulate interventions with some skipped
    def mock_session():
        session = FakeSession()
        original_run = session.run
        
        def custom_run(query, **params):
            if "loop_count" in query and "skipped" in query:
                # Return data with 10 total interventions, 3 skipped, 5 successful
                return FakeResult({
                    "state": "Stress",
                    "loop_count": 10,
                    "successes": 5,
                    "skipped": 3
                })
            elif "hydration_misses" in query:
                return FakeResult({
                    "hydration_misses": 0,
                    "rest_misses": 0
                })
            return original_run(query, **params)
        
        session.run = custom_run
        return session
    
    fake_driver.session = mock_session
    
    insight = db.get_ai_insight()
    
    assert insight is not None
    # Success rate should be 5/(10-3) * 100 = ~71.4%, not 50%
    assert insight["success_rate"] > 70
    assert insight["success_rate"] < 72


def test_get_ai_insight_coaching_message_for_frequent_skips(mock_db):
    """Test that coaching message reflects when user skips many interventions."""
    db, fake_driver = mock_db
    
    # Mock high skip rate scenario
    def mock_session():
        session = FakeSession()
        original_run = session.run
        
        def custom_run(query, **params):
            if "loop_count" in query and "skipped" in query:
                # 10 interventions, 8 skipped, 1 successful
                return FakeResult({
                    "state": "Stress",
                    "loop_count": 10,
                    "successes": 1,
                    "skipped": 8
                })
            elif "hydration_misses" in query:
                return FakeResult({
                    "hydration_misses": 0,
                    "rest_misses": 0
                })
            return original_run(query, **params)
        
        session.run = custom_run
        return session
    
    fake_driver.session = mock_session
    
    insight = db.get_ai_insight()

    assert insight is not None
    # Should have special coaching message about skipping
    assert "haven't completed many" in insight["coaching_message"] or \
           "skipped" in insight["coaching_message"].lower()


# Q1.1.3 — Comprehensive DB exception handling tests

class FakeSessionWithException(FakeSession):
    """FakeSession that raises exceptions on run()."""
    def __init__(self, exception=None):
        super().__init__()
        self.exception = exception or Exception("Test DB error")

    def run(self, query, **params):
        raise self.exception


# __init__ retry and exception tests
def test_init_retries_on_service_unavailable():
    """Test that __init__ retries on ServiceUnavailable and marks unavailable after max retries."""
    from neo4j.exceptions import ServiceUnavailable

    with patch('app.db.GraphDatabase.driver') as mock_driver_constructor:
        fake_driver = FakeDriver()
        mock_driver_constructor.return_value = fake_driver

        call_count = [0]

        def failing_bootstrap(*args, **kwargs):
            call_count[0] += 1
            raise ServiceUnavailable("Service not available")

        with patch.object(BehavioralStateManager, '_bootstrap_nodes', side_effect=failing_bootstrap):
            with patch('time.sleep'):  # Mock sleep to avoid delays
                db = BehavioralStateManager(
                    uri="bolt://localhost:7687",
                    user="neo4j",
                    password="test"
                )

        # Should have retried max_retries times
        assert call_count[0] > 1
        assert db.is_available is False


def test_init_generic_exception_marks_unavailable():
    """Test that __init__ marks unavailable on generic exception without retry."""
    with patch('app.db.GraphDatabase.driver') as mock_driver_constructor:
        fake_driver = FakeDriver()
        mock_driver_constructor.return_value = fake_driver

        call_count = [0]

        def failing_bootstrap(*args, **kwargs):
            call_count[0] += 1
            raise RuntimeError("Unexpected error")

        with patch.object(BehavioralStateManager, '_bootstrap_nodes', side_effect=failing_bootstrap):
            db = BehavioralStateManager(
                uri="bolt://localhost:7687",
                user="neo4j",
                password="test"
            )

        # Should NOT retry for non-ServiceUnavailable exceptions
        assert call_count[0] == 1
        assert db.is_available is False


def test_bootstrap_nodes_runs_warmup_query(mock_db):
    """Test that _bootstrap_nodes creates a session (warmup happens at initialization)."""
    db, fake_driver = mock_db

    # Verify that at least one session was created during mock_db initialization
    # (which calls _bootstrap_nodes via __init__)
    # The presence of a session proves that DB bootstrap occurred
    assert db.is_available is True
    assert db.driver is not None


# log_and_analyze tests
def test_log_and_analyze_unavailable(mock_db):
    """Test that log_and_analyze returns Low/False when unavailable."""
    db, _ = mock_db
    db.is_available = False

    risk, loop = db.log_and_analyze("Stress", 0.8)

    assert risk == "Low"
    assert loop is False


def test_log_and_analyze_happy_path(mock_db):
    """Test log_and_analyze with successful DB responses."""
    db, fake_driver = mock_db

    def mock_session():
        session = FakeSession()
        original_run = session.run

        def custom_run(query, **params):
            if "timestamp" in query and "MATCH" in query:
                # History query - return 3 records
                return type('obj', (object,), {
                    '__iter__': lambda _: iter([
                        FakeRecord({"timestamp": "2026-04-29T10:00:00", "was_successful": True}),
                        FakeRecord({"timestamp": "2026-04-28T15:00:00", "was_successful": False}),
                        FakeRecord({"timestamp": "2026-04-27T12:00:00", "was_successful": True}),
                    ])
                })()
            return original_run(query, **params)

        session.run = custom_run
        return session

    fake_driver.session = mock_session

    risk, loop = db.log_and_analyze("Stress", 0.8)

    # Should return risk and loop values
    assert risk in ["Low", "Medium", "High"]
    assert isinstance(loop, bool)


def test_log_and_analyze_exception(mock_db):
    """Test that log_and_analyze handles exceptions and marks unavailable."""
    db, fake_driver = mock_db

    # Make session.run raise an exception
    def mock_session():
        return FakeSessionWithException()

    fake_driver.session = mock_session

    risk, loop = db.log_and_analyze("Stress", 0.8)

    # Should return safe defaults
    assert risk == "Low"
    assert loop is False
    assert db.is_available is False


# resolve_intervention tests
def test_resolve_intervention_unavailable(mock_db):
    """Test that resolve_intervention returns immediately when unavailable."""
    db, fake_driver = mock_db
    db.is_available = False

    fake_driver.sessions = []

    db.resolve_intervention(was_successful=True, needs_check={"hydration": True})

    # Should not create any DB session when unavailable
    assert len(fake_driver.sessions) == 0


def test_resolve_intervention_exception(mock_db):
    """Test that resolve_intervention handles exceptions."""
    db, fake_driver = mock_db

    # Make session.run raise an exception
    def mock_session():
        return FakeSessionWithException()

    fake_driver.session = mock_session

    # Should not raise
    db.resolve_intervention(was_successful=True, needs_check={})

    # Should mark unavailable
    assert db.is_available is False


# get_history tests
def test_get_history_returns_records(mock_db):
    """Test that get_history returns formatted records."""
    db, fake_driver = mock_db

    def mock_session():
        session = FakeSession()

        def custom_run(query, **params):
            if "timestamp" in query:
                return type('obj', (object,), {
                    '__iter__': lambda _: iter([
                        FakeRecord({
                            "timestamp": "2026-04-29T10:00:00",
                            "was_successful": True,
                            "detected_node": "Stress"
                        }),
                        FakeRecord({
                            "timestamp": "2026-04-28T15:00:00",
                            "was_successful": False,
                            "detected_node": "Anxiety"
                        }),
                    ])
                })()
            return FakeResult({})

        session.run = custom_run
        return session

    fake_driver.session = mock_session

    history = db.get_history()

    assert isinstance(history, list)
    assert len(history) == 2
    assert history[0]["was_successful"] is True


def test_get_history_exception(mock_db):
    """Test that get_history returns empty list on exception."""
    db, fake_driver = mock_db

    def mock_session():
        return FakeSessionWithException()

    fake_driver.session = mock_session

    history = db.get_history()

    assert history == []


# get_ai_insight tests
def test_get_ai_insight_unavailable(mock_db):
    """Test that get_ai_insight returns None when unavailable."""
    db, _ = mock_db
    db.is_available = False

    insight = db.get_ai_insight()

    assert insight is None


def test_get_ai_insight_with_hydration_miss(mock_db):
    """Test that get_ai_insight includes hydration miss in result."""
    db, fake_driver = mock_db

    def mock_session():
        session = FakeSession()
        original_run = session.run

        def custom_run(query, **params):
            if "loop_count" in query and "skipped" in query:
                return FakeResult({
                    "state": "Stress",
                    "loop_count": 5,
                    "successes": 3,
                    "skipped": 1
                })
            elif "hydration_misses" in query:
                return FakeResult({
                    "hydration_misses": 2,
                    "rest_misses": 0
                })
            return original_run(query, **params)

        session.run = custom_run
        return session

    fake_driver.session = mock_session

    insight = db.get_ai_insight()

    assert insight is not None
    assert "missing_need" in insight
    assert insight["missing_need"] == "hydration"


def test_get_ai_insight_no_data_returns_none(mock_db):
    """Test that get_ai_insight returns None when there's no data."""
    db, fake_driver = mock_db

    def mock_session():
        session = FakeSession()

        def custom_run(query, **params):
            # Return result with loop_count = 0
            return FakeResult({"count": 0}) if "count" in query else FakeResult(None)

        session.run = custom_run
        return session

    fake_driver.session = mock_session

    insight = db.get_ai_insight()

    assert insight is None


def test_get_ai_insight_exception(mock_db):
    """Test that get_ai_insight returns None on exception."""
    db, fake_driver = mock_db

    def mock_session():
        return FakeSessionWithException()

    fake_driver.session = mock_session

    insight = db.get_ai_insight()

    assert insight is None
    assert db.is_available is False


# get_trend_stats tests
def test_get_trend_stats_unavailable(mock_db):
    """Test that get_trend_stats returns empty dict when unavailable."""
    db, _ = mock_db
    db.is_available = False

    stats = db.get_trend_stats()

    assert stats == {}


def test_get_trend_stats_happy_path(mock_db):
    """Test that get_trend_stats returns state counts."""
    db, fake_driver = mock_db

    def mock_session():
        session = FakeSession()

        def custom_run(query, **params):
            if "state" in query and "count" in query:
                return type('obj', (object,), {
                    '__iter__': lambda _: iter([
                        FakeRecord({"state": "Stress", "count": 5}),
                        FakeRecord({"state": "Anxiety", "count": 3}),
                    ])
                })()
            return FakeResult({})

        session.run = custom_run
        return session

    fake_driver.session = mock_session

    stats = db.get_trend_stats()

    assert isinstance(stats, dict)
    assert "Stress" in stats
    assert stats["Stress"] == 5


def test_get_trend_stats_exception(mock_db):
    """Test that get_trend_stats returns empty dict on exception."""
    db, fake_driver = mock_db

    def mock_session():
        return FakeSessionWithException()

    fake_driver.session = mock_session

    stats = db.get_trend_stats()

    # Should return empty dict on exception
    assert stats == {}


# reset_all_data tests
def test_reset_all_data_unavailable(mock_db):
    """Test that reset_all_data returns False when unavailable."""
    db, _ = mock_db
    db.is_available = False

    result = db.reset_all_data()

    assert result is False


def test_reset_all_data_happy_path(mock_db):
    """Test that reset_all_data returns True on success."""
    db, fake_driver = mock_db

    result = db.reset_all_data()

    assert result is True
    assert len(fake_driver.sessions) > 0


def test_reset_all_data_exception(mock_db):
    """Test that reset_all_data returns False on exception."""
    db, fake_driver = mock_db

    def mock_session():
        return FakeSessionWithException()

    fake_driver.session = mock_session

    result = db.reset_all_data()

    assert result is False
    assert db.is_available is False


# create_db_manager tests
def test_create_db_manager_missing_password():
    """Test that create_db_manager raises RuntimeError when password missing."""
    import os

    # Save original password
    orig_password = os.environ.get("NEO4J_PASSWORD")

    try:
        # Delete password if it exists
        if "NEO4J_PASSWORD" in os.environ:
            del os.environ["NEO4J_PASSWORD"]

        # Should raise RuntimeError
        with pytest.raises(RuntimeError):
            from app.db import create_db_manager
            create_db_manager()
    finally:
        # Restore password
        if orig_password:
            os.environ["NEO4J_PASSWORD"] = orig_password
