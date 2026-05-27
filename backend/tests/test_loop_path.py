"""Tests for Phase 6.2 loop path visualization.

Covers:
- GET /loop-path returns state transition sequences
- analyze_loop_path: most common entry point, cycle length, total cycles
- FEATURE_LOOP_PATH flag controls endpoint availability
- Empty path handled gracefully
"""

from typing import Any, Dict, List

import pytest
from fastapi.testclient import TestClient

from app import main as app_main


class _FakeDB:
    def __init__(self, path: List[Dict] = None):
        self._path = path or []
        self.is_available = True

    def get_loop_path(self, days: int = 30) -> List[Dict]:
        return self._path

    def analyze_loop_path(self, days: int = 30) -> Dict[str, Any]:
        if not self._path:
            return {}
        # Minimal real analysis mirroring db.analyze_loop_path logic
        from datetime import datetime
        entry_counts: Dict[str, int] = {}
        last_ts = None
        current_start = None
        for entry in self._path:
            ts = entry["timestamp"]
            if last_ts:
                diff = (datetime.fromisoformat(ts) - datetime.fromisoformat(last_ts)).total_seconds() / 3600
                if diff > 6:
                    current_start = entry["state"]
            else:
                current_start = entry["state"]
            if current_start:
                entry_counts[current_start] = entry_counts.get(current_start, 0) + 1
            last_ts = ts
        most_common = max(entry_counts, key=entry_counts.get) if entry_counts else None
        return {
            "most_common_entry": most_common,
            "cycle_length_hours": None,
            "total_cycles": len(entry_counts),
        }

    def get_history(self, start_date=None, end_date=None, limit=500):
        return []


_SAMPLE_PATH = [
    {"timestamp": "2026-05-01T10:00:00", "state": "Stress", "confidence": 0.9, "has_intervention": True},
    {"timestamp": "2026-05-01T14:00:00", "state": "Procrastination", "confidence": 0.85, "has_intervention": False},
    {"timestamp": "2026-05-02T10:00:00", "state": "Stress", "confidence": 0.88, "has_intervention": True},
]


@pytest.fixture(autouse=True)
def setup_crisis_service():
    from app.crisis import CrisisSafetyService
    app_main.app.state.crisis_service = CrisisSafetyService()


class TestLoopPathEndpoint:
    """Integration tests for GET /loop-path."""

    @pytest.fixture(autouse=True)
    def enable_flag(self, monkeypatch):
        monkeypatch.setattr(app_main, "FEATURE_LOOP_PATH", True)

    @pytest.fixture
    def client_with_path(self):
        def make(path):
            fake_db = _FakeDB(path=path)
            app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
            return TestClient(app_main.app)
        yield make
        app_main.app.dependency_overrides.clear()

    def test_loop_path_returns_200(self, client_with_path):
        """GET /loop-path returns 200 OK."""
        client = client_with_path(_SAMPLE_PATH)
        response = client.get("/loop-path")
        assert response.status_code == 200

    def test_loop_path_response_has_path_and_analysis(self, client_with_path):
        """Response contains 'path' list and 'analysis' dict."""
        client = client_with_path(_SAMPLE_PATH)
        data = client.get("/loop-path").json()
        assert "path" in data
        assert "analysis" in data
        assert isinstance(data["path"], list)
        assert isinstance(data["analysis"], dict)

    def test_loop_path_returns_entries(self, client_with_path):
        """path list contains correct number of entries."""
        client = client_with_path(_SAMPLE_PATH)
        data = client.get("/loop-path").json()
        assert len(data["path"]) == 3

    def test_loop_path_entry_has_required_fields(self, client_with_path):
        """Each path entry has timestamp, state, confidence, has_intervention."""
        client = client_with_path(_SAMPLE_PATH)
        data = client.get("/loop-path").json()
        entry = data["path"][0]
        assert "timestamp" in entry
        assert "state" in entry
        assert "confidence" in entry
        assert "has_intervention" in entry

    def test_loop_path_analysis_has_most_common_entry(self, client_with_path):
        """analysis.most_common_entry is returned."""
        client = client_with_path(_SAMPLE_PATH)
        data = client.get("/loop-path").json()
        assert "most_common_entry" in data["analysis"]

    def test_loop_path_empty_returns_empty_path_and_analysis(self, client_with_path):
        """Empty DB returns path=[] and analysis={}."""
        client = client_with_path([])
        data = client.get("/loop-path").json()
        assert data["path"] == []
        assert data["analysis"] == {}

    def test_loop_path_days_param_accepted(self, client_with_path):
        """?days=7 query param is accepted without error."""
        client = client_with_path(_SAMPLE_PATH)
        response = client.get("/loop-path?days=7")
        assert response.status_code == 200

    def test_loop_path_most_common_entry_is_stress(self, client_with_path):
        """With Stress appearing twice (in separate cycles), most_common_entry is Stress."""
        client = client_with_path(_SAMPLE_PATH)
        data = client.get("/loop-path").json()
        assert data["analysis"]["most_common_entry"] == "Stress"


class TestLoopPathFeatureFlag:
    """Tests for FEATURE_LOOP_PATH flag."""

    @pytest.fixture(autouse=True)
    def setup_db(self):
        fake_db = _FakeDB(path=_SAMPLE_PATH)
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        yield
        app_main.app.dependency_overrides.clear()

    def test_endpoint_returns_404_when_flag_disabled(self, monkeypatch):
        """GET /loop-path returns 404 when FEATURE_LOOP_PATH=False."""
        monkeypatch.setattr(app_main, "FEATURE_LOOP_PATH", False)
        client = TestClient(app_main.app)
        response = client.get("/loop-path")
        assert response.status_code == 404

    def test_endpoint_returns_200_when_flag_enabled(self, monkeypatch):
        """GET /loop-path returns 200 when FEATURE_LOOP_PATH=True."""
        monkeypatch.setattr(app_main, "FEATURE_LOOP_PATH", True)
        client = TestClient(app_main.app)
        response = client.get("/loop-path")
        assert response.status_code == 200
