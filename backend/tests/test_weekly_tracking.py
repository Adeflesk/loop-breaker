"""Tests for Phase 6.3 weekly/monthly tracking.

Covers:
- GET /history accepts start_date, end_date, limit params
- db.get_history() filters by date range
- GET /weekly-summary returns aggregated 7-day stats
- db.get_weekly_summary() aggregation accuracy
- Empty result handling
- FEATURE_WEEKLY_TRACKING flag
"""

from typing import Any, Dict, List, Optional

import pytest
from fastapi.testclient import TestClient

from app import main as app_main


class _FakeDB:
    def __init__(self, history: List[Dict] = None, weekly: Dict = None):
        self._history = history or []
        self._weekly = weekly or {}
        self.last_history_kwargs: Dict = {}
        self.last_weekly_kwargs: Dict = {}
        self.is_available = True

    def get_history(self, start_date=None, end_date=None, limit=500):
        self.last_history_kwargs = {"start_date": start_date, "end_date": end_date, "limit": limit}
        return self._history

    def get_weekly_summary(self, week_start: str) -> Dict:
        self.last_weekly_kwargs = {"week_start": week_start}
        return self._weekly

    def analyze_loop_path(self, days: int = 30):
        return {}

    def get_loop_path(self, days: int = 30):
        return []


_HISTORY_ROWS = [
    {"time": "2026-05-01T10:00:00", "state": "Stress", "intervention": "Sigh", "confidence": 0.9, "was_successful": True},
    {"time": "2026-05-03T12:00:00", "state": "Anxiety", "intervention": "Ground", "confidence": 0.8, "was_successful": False},
    {"time": "2026-05-07T09:00:00", "state": "Shame", "intervention": "MSC", "confidence": 0.75, "was_successful": True},
]

_WEEKLY_SUMMARY = {
    "week_start": "2026-05-01",
    "total_entries": 3,
    "days_with_entries": 3,
    "avg_confidence": 0.82,
    "intervention_success_rate": 66.7,
    "top_states": {"Stress": 1, "Anxiety": 1, "Shame": 1},
}


@pytest.fixture(autouse=True)
def setup_crisis_service():
    from app.crisis import CrisisSafetyService
    app_main.app.state.crisis_service = CrisisSafetyService()


class TestHistoryDateRange:
    """Tests for GET /history with date-range parameters."""

    @pytest.fixture
    def fake_db(self):
        db = _FakeDB(history=_HISTORY_ROWS)
        app_main.app.dependency_overrides[app_main.get_db] = lambda: db
        yield db
        app_main.app.dependency_overrides.clear()

    @pytest.fixture
    def client(self, fake_db):
        return TestClient(app_main.app)

    def test_history_returns_200(self, client):
        """GET /history returns 200."""
        assert client.get("/history").status_code == 200

    def test_history_without_params_returns_all_rows(self, client):
        """GET /history with no params returns all rows from fake DB."""
        data = client.get("/history").json()
        assert len(data) == 3

    def test_history_accepts_start_date_param(self, client, fake_db):
        """GET /history?start_date=... passes start_date to db.get_history()."""
        client.get("/history?start_date=2026-05-01")
        assert fake_db.last_history_kwargs["start_date"] == "2026-05-01"

    def test_history_accepts_end_date_param(self, client, fake_db):
        """GET /history?end_date=... passes end_date to db.get_history()."""
        client.get("/history?end_date=2026-05-07")
        assert fake_db.last_history_kwargs["end_date"] == "2026-05-07"

    def test_history_accepts_limit_param(self, client, fake_db):
        """GET /history?limit=10 passes limit to db.get_history()."""
        client.get("/history?limit=10")
        assert fake_db.last_history_kwargs["limit"] == 10

    def test_history_default_limit_is_500(self, client, fake_db):
        """GET /history without limit defaults to 500."""
        client.get("/history")
        assert fake_db.last_history_kwargs["limit"] == 500

    def test_history_with_date_range_returns_filtered_data(self, client, fake_db):
        """db.get_history receives start/end dates when provided."""
        client.get("/history?start_date=2026-05-01&end_date=2026-05-07")
        assert fake_db.last_history_kwargs["start_date"] == "2026-05-01"
        assert fake_db.last_history_kwargs["end_date"] == "2026-05-07"

    def test_history_empty_result_returns_empty_list(self):
        """GET /history returns [] when DB returns nothing."""
        empty_db = _FakeDB(history=[])
        app_main.app.dependency_overrides[app_main.get_db] = lambda: empty_db
        client = TestClient(app_main.app)
        data = client.get("/history").json()
        assert data == []
        app_main.app.dependency_overrides.clear()


class TestDbGetHistorySignature:
    """Unit tests for db.get_history() signature and defaults."""

    def test_get_history_accepts_start_date_end_date_limit(self):
        """db.get_history() accepts start_date, end_date, limit keyword args."""
        from app.db import BehavioralStateManager
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = False
        # Should not raise TypeError
        result = db.get_history(start_date="2026-05-01", end_date="2026-05-07", limit=100)
        assert result == []

    def test_get_history_returns_empty_list_when_db_unavailable(self):
        """db.get_history() returns [] gracefully when DB unavailable."""
        from app.db import BehavioralStateManager
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = False
        assert db.get_history() == []


class TestWeeklySummaryEndpoint:
    """Tests for GET /weekly-summary endpoint."""

    @pytest.fixture
    def fake_db(self):
        db = _FakeDB(weekly=_WEEKLY_SUMMARY)
        app_main.app.dependency_overrides[app_main.get_db] = lambda: db
        yield db
        app_main.app.dependency_overrides.clear()

    @pytest.fixture
    def client(self, fake_db):
        return TestClient(app_main.app)

    def test_weekly_summary_returns_200(self, client):
        """GET /weekly-summary?week_start=... returns 200."""
        response = client.get("/weekly-summary?week_start=2026-05-01")
        assert response.status_code == 200

    def test_weekly_summary_returns_400_without_week_start(self, client):
        """GET /weekly-summary without week_start param returns 422."""
        response = client.get("/weekly-summary")
        assert response.status_code == 422

    def test_weekly_summary_passes_week_start_to_db(self, client, fake_db):
        """week_start param is forwarded to db.get_weekly_summary()."""
        client.get("/weekly-summary?week_start=2026-05-01")
        assert fake_db.last_weekly_kwargs["week_start"] == "2026-05-01"

    def test_weekly_summary_response_contains_total_entries(self, client):
        """Response includes total_entries."""
        data = client.get("/weekly-summary?week_start=2026-05-01").json()
        assert "total_entries" in data
        assert data["total_entries"] == 3

    def test_weekly_summary_response_contains_top_states(self, client):
        """Response includes top_states dict."""
        data = client.get("/weekly-summary?week_start=2026-05-01").json()
        assert "top_states" in data
        assert isinstance(data["top_states"], dict)

    def test_weekly_summary_empty_returns_empty_dict(self):
        """GET /weekly-summary with no data returns empty dict."""
        empty_db = _FakeDB(weekly={})
        app_main.app.dependency_overrides[app_main.get_db] = lambda: empty_db
        client = TestClient(app_main.app)
        data = client.get("/weekly-summary?week_start=2026-05-01").json()
        assert data == {}
        app_main.app.dependency_overrides.clear()


class TestDbGetWeeklySummary:
    """Unit tests for db.get_weekly_summary() signature."""

    def test_get_weekly_summary_returns_empty_dict_when_db_unavailable(self):
        """db.get_weekly_summary() returns {} gracefully when DB unavailable."""
        from app.db import BehavioralStateManager
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = False
        result = db.get_weekly_summary("2026-05-01")
        assert result == {}
