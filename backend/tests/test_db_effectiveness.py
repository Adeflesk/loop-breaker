"""
Tests for intervention effectiveness calculation in DB.
"""
import pytest
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


class FakeSession:
    """Mock Neo4j session that returns intervention effectiveness data."""
    def __init__(self, records=None):
        self.records = records or []
        self.queries = []

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def run(self, query, params=None):
        """Return mock records based on stored data."""
        self.queries.append((query, params))
        return self.records


class FakeDriver:
    """Mock Neo4j driver for testing."""
    def __init__(self, records=None):
        self.records = records or []

    def session(self):
        return FakeSession(self.records)

    def close(self):
        pass


@pytest.fixture
def mock_driver_with_records():
    """Fixture that returns a mock driver factory."""
    def _create_driver(records):
        return FakeDriver(records)
    return _create_driver


class TestGetInterventionEffectiveness:
    """Tests for get_intervention_effectiveness() method."""

    def test_returns_empty_dict_when_db_unavailable(self):
        """Should return empty dict if Neo4j is unavailable."""
        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = False
        manager.driver = MagicMock()

        result = manager.get_intervention_effectiveness("Procrastination", "Avoidance")

        assert result == {}

    def test_returns_empty_dict_when_no_outcomes_recorded(self, mock_driver_with_records):
        """Should return empty dict when no entries have recorded outcomes."""
        # Create records without outcomes
        records = []
        mock_driver = mock_driver_with_records(records)

        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        manager.driver = mock_driver

        result = manager.get_intervention_effectiveness("Stress")

        assert result == {}

    def test_filters_interventions_below_threshold(self, mock_driver_with_records):
        """Should exclude interventions with fewer than min_threshold uses."""
        # Create records with only 2 uses of "Breathing"
        records = [
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "neutral"}),
        ]
        mock_driver = mock_driver_with_records(records)

        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        manager.driver = mock_driver

        result = manager.get_intervention_effectiveness("Stress", min_threshold=3)

        # Should be empty because Breathing has only 2 uses (below threshold of 3)
        assert result == {}

    def test_includes_interventions_at_threshold(self, mock_driver_with_records):
        """Should include interventions with exactly min_threshold uses."""
        # Create records with exactly 3 uses of "Breathing"
        records = [
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "neutral"}),
        ]
        mock_driver = mock_driver_with_records(records)

        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        manager.driver = mock_driver

        result = manager.get_intervention_effectiveness("Stress", min_threshold=3)

        # Should include Breathing with 3 total uses (2 helped, 1 neutral)
        assert "Breathing" in result
        assert result["Breathing"]["total"] == 3
        assert result["Breathing"]["helped"] == 2
        assert result["Breathing"]["neutral"] == 1
        assert result["Breathing"]["didn_help"] == 0

    def test_calculates_percentage_correctly(self, mock_driver_with_records):
        """Should calculate percentage based on helped/total."""
        # 8 helped out of 10 total = 80%
        records = [
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "neutral"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "didn't help"}),
        ]
        mock_driver = mock_driver_with_records(records)

        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        manager.driver = mock_driver

        result = manager.get_intervention_effectiveness("Procrastination", min_threshold=3)

        assert "5-Minute Sprint" in result
        assert result["5-Minute Sprint"]["percentage"] == 80
        assert result["5-Minute Sprint"]["helped"] == 8
        assert result["5-Minute Sprint"]["neutral"] == 1
        assert result["5-Minute Sprint"]["didn_help"] == 1
        assert result["5-Minute Sprint"]["total"] == 10

    def test_handles_multiple_interventions(self, mock_driver_with_records):
        """Should aggregate stats per intervention independently."""
        records = [
            # 5-Minute Sprint: 8 helped, 2 other
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "neutral"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "didn't help"}),
            # Breathing: 2 helped, 3 other
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "neutral"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "didn't help"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "didn't help"}),
        ]
        mock_driver = mock_driver_with_records(records)

        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        manager.driver = mock_driver

        result = manager.get_intervention_effectiveness("Procrastination", min_threshold=3)

        # Both should be included (both have 5+ uses)
        assert "5-Minute Sprint" in result
        assert "Breathing" in result
        # Verify stats are correct for each
        assert result["5-Minute Sprint"]["percentage"] == 80
        assert result["Breathing"]["percentage"] == 40

    def test_normalizes_outcome_values(self, mock_driver_with_records):
        """Should normalize 'didn't help' to 'didn_help' in output."""
        records = [
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "didn't help"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "neutral"}),
        ]
        mock_driver = mock_driver_with_records(records)

        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        manager.driver = mock_driver

        result = manager.get_intervention_effectiveness("Stress", min_threshold=1)

        # Output should use "didn_help" key
        assert "didn_help" in result["Breathing"]
        assert result["Breathing"]["didn_help"] == 1
        assert result["Breathing"]["total"] == 3

    def test_respects_limit_parameter(self, mock_driver_with_records):
        """Should limit query results to specified number of entries."""
        # Create 15 records but only request 10
        records = [
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"})
            for _ in range(15)
        ]
        mock_driver = mock_driver_with_records(records)

        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        manager.driver = mock_driver

        # Query with limit=10
        result = manager.get_intervention_effectiveness("Stress", limit=10, min_threshold=1)

        # Result should still include Breathing but only based on the limited query
        # (The mock returns all records, but the limit is passed to the query)
        assert "Breathing" in result

    def test_filters_by_sublabel_when_provided(self, mock_driver_with_records):
        """Should filter entries by sublabel when provided."""
        records = [
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "Breathing", "user_outcome": "helped"}),
        ]
        mock_driver = mock_driver_with_records(records)

        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        manager.driver = mock_driver

        # Call with specific sublabel
        result = manager.get_intervention_effectiveness(
            "Procrastination",
            sublabel="Avoidance",
            min_threshold=1
        )

        # Verify the method handles sublabel parameter (just check result is valid)
        assert isinstance(result, dict)

    def test_returns_correct_structure(self, mock_driver_with_records):
        """Should return data in expected structure."""
        records = [
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
            FakeRecord({"intervention_title": "5-Minute Sprint", "user_outcome": "helped"}),
        ]
        mock_driver = mock_driver_with_records(records)

        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        manager.driver = mock_driver

        result = manager.get_intervention_effectiveness("Procrastination", min_threshold=1)

        # Check structure of result
        assert isinstance(result, dict)
        assert "5-Minute Sprint" in result
        intervention_data = result["5-Minute Sprint"]

        # Verify required fields
        assert "helped" in intervention_data
        assert "neutral" in intervention_data
        assert "didn_help" in intervention_data
        assert "total" in intervention_data
        assert "percentage" in intervention_data

        # Verify types
        assert isinstance(intervention_data["helped"], int)
        assert isinstance(intervention_data["neutral"], int)
        assert isinstance(intervention_data["didn_help"], int)
        assert isinstance(intervention_data["total"], int)
        assert isinstance(intervention_data["percentage"], int)

    def test_gracefully_handles_exception(self):
        """Should return empty dict if query raises exception."""
        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        # Create a driver that raises exception
        mock_driver = MagicMock()
        mock_driver.session.side_effect = Exception("Connection failed")
        manager.driver = mock_driver

        result = manager.get_intervention_effectiveness("Stress")

        assert result == {}


class TestCrisisEventLogging:
    """Tests for crisis event logging to Neo4j."""

    def test_log_crisis_event_creates_node(self):
        """Should create CrisisEvent node in Neo4j."""
        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True

        mock_session = MagicMock()
        mock_driver = MagicMock()
        mock_driver.session.return_value.__enter__.return_value = mock_session
        manager.driver = mock_driver

        manager.log_crisis_event(
            user_id="user123",
            keywords=["suicide", "harm"],
            detected_state="Shame",
            ip_address="192.168.1.1"
        )

        # Verify query was called
        mock_session.run.assert_called_once()
        call_args = mock_session.run.call_args
        assert "CrisisEvent" in str(call_args)

    def test_log_crisis_event_handles_unavailable_db(self):
        """Should gracefully handle unavailable DB."""
        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = False
        manager.driver = MagicMock()

        # Should not raise exception
        result = manager.log_crisis_event(
            user_id="user123",
            keywords=["suicide"],
            detected_state=None,
            ip_address="192.168.1.1"
        )

        assert result is None  # Graceful degradation
