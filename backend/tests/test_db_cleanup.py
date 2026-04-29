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
