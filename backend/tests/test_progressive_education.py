"""Tests for Phase 6.1 progressive neuroscience education depth.

Covers:
- get_intervention_seen_count() returns count from DB
- /analyze returns education_depth based on seen_count (introduce/reinforce/deepen)
- FEATURE_PROGRESSIVE_EDUCATION flag controls depth selection
- Education text is selected from the correct depth key
"""

from typing import Any, Dict
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app import main as app_main


class _FakeDB:
    def __init__(self, seen_count: int = 0):
        self._seen_count = seen_count
        self.is_available = True

    def get_intervention_seen_count(self, title: str) -> int:
        return self._seen_count

    def increment_intervention_seen_count(self, title: str) -> None:
        pass

    def log_and_analyze(self, node_name, confidence, title, task, sublabel="unspecified"):
        return "Low", False

    def get_history(self, start_date=None, end_date=None, limit=500):
        return []

    def analyze_loop_path(self, days: int = 30):
        return {}

    def get_intervention_effectiveness(self, state: str, sublabel: str = None):
        return {}

    def save_journal_entry(self, **kwargs):
        pass

    def get_shame_count_24h(self):
        return 0

    def get_crisis_events(self, days: int = 7):
        return []

    def log_crisis_event(self, user_id, keywords, detected_state, ip_address):
        return "fake-crisis-id"


async def _fake_ai(text: str, request_id: str = "") -> Dict[str, Any]:
    return {
        "detected_node": "Stress",
        "emotion_sublabel": "Overload",
        "confidence": 0.9,
        "reasoning": "stress detected",
    }


class TestGetInterventionSeenCount:
    """Unit tests for db.get_intervention_seen_count()."""

    def test_returns_zero_when_intervention_never_seen(self):
        """get_intervention_seen_count returns 0 for unseen intervention."""
        from app.db import BehavioralStateManager
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = False  # Simulate unavailable DB
        result = db.get_intervention_seen_count("Physiological Sigh")
        assert result == 0

    def test_returns_zero_when_db_unavailable(self):
        """get_intervention_seen_count returns 0 gracefully when DB unavailable."""
        from app.db import BehavioralStateManager
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = False
        result = db.get_intervention_seen_count("Some Intervention")
        assert result == 0


class TestEducationDepthSelection:
    """Tests for education depth selection in /analyze based on seen_count."""

    @pytest.fixture(autouse=True)
    def patch_ai(self, monkeypatch):
        monkeypatch.setattr(app_main, "query_local_ai", _fake_ai)
        monkeypatch.setattr(app_main, "FEATURE_PROGRESSIVE_EDUCATION", True)
        from app.crisis import CrisisSafetyService
        app_main.app.state.crisis_service = CrisisSafetyService()

    @pytest.fixture
    def client_with_seen_count(self):
        def make_client(seen_count: int) -> TestClient:
            fake_db = _FakeDB(seen_count=seen_count)
            app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
            return TestClient(app_main.app)
        yield make_client
        app_main.app.dependency_overrides.clear()

    def test_education_depth_is_introduce_on_first_exposure(self, client_with_seen_count):
        """seen_count=0 → education_depth='introduce'."""
        client = client_with_seen_count(0)
        response = client.post("/analyze", json={"user_text": "I feel stressed out"})
        assert response.status_code == 200
        data = response.json()
        assert data["education_depth"] == "introduce"

    def test_education_depth_is_introduce_for_seen_count_one(self, client_with_seen_count):
        """seen_count=1 → education_depth='introduce'."""
        client = client_with_seen_count(1)
        response = client.post("/analyze", json={"user_text": "I feel stressed out"})
        assert response.status_code == 200
        assert response.json()["education_depth"] == "introduce"

    def test_education_depth_is_reinforce_for_seen_count_two(self, client_with_seen_count):
        """seen_count=2 → education_depth='reinforce'."""
        client = client_with_seen_count(2)
        response = client.post("/analyze", json={"user_text": "I feel stressed out"})
        assert response.status_code == 200
        assert response.json()["education_depth"] == "reinforce"

    def test_education_depth_is_reinforce_for_seen_count_four(self, client_with_seen_count):
        """seen_count=4 → education_depth='reinforce'."""
        client = client_with_seen_count(4)
        response = client.post("/analyze", json={"user_text": "I feel stressed out"})
        assert response.status_code == 200
        assert response.json()["education_depth"] == "reinforce"

    def test_education_depth_is_deepen_for_seen_count_five(self, client_with_seen_count):
        """seen_count=5 → education_depth='deepen'."""
        client = client_with_seen_count(5)
        response = client.post("/analyze", json={"user_text": "I feel stressed out"})
        assert response.status_code == 200
        assert response.json()["education_depth"] == "deepen"

    def test_education_depth_is_deepen_for_high_seen_count(self, client_with_seen_count):
        """seen_count=20 → education_depth='deepen'."""
        client = client_with_seen_count(20)
        response = client.post("/analyze", json={"user_text": "I feel stressed out"})
        assert response.status_code == 200
        assert response.json()["education_depth"] == "deepen"

    def test_education_info_content_changes_with_depth(self, client_with_seen_count):
        """education_info text differs between introduce and deepen depths."""
        # Make introduce request first (seen_count=0)
        client = client_with_seen_count(0)
        resp_intro = client.post("/analyze", json={"user_text": "I feel stressed out"})
        intro_text = resp_intro.json().get("education_info", "")

        # Then switch to deepen (seen_count=5) — must re-create client to update DB override
        client = client_with_seen_count(5)
        resp_deep = client.post("/analyze", json={"user_text": "I feel stressed out"})
        deep_text = resp_deep.json().get("education_info", "")

        assert intro_text, "introduce education_info should not be empty"
        assert deep_text, "deepen education_info should not be empty"
        assert intro_text != deep_text, "introduce and deepen education_info should differ"


class TestFeatureProgressiveEducation:
    """Tests that FEATURE_PROGRESSIVE_EDUCATION flag controls depth lookup."""

    @pytest.fixture(autouse=True)
    def patch_ai(self, monkeypatch):
        monkeypatch.setattr(app_main, "query_local_ai", _fake_ai)
        from app.crisis import CrisisSafetyService
        app_main.app.state.crisis_service = CrisisSafetyService()

    @pytest.fixture(autouse=True)
    def setup_db(self):
        # seen_count=10 so without flag we'd get "deepen"; with flag disabled we get "introduce"
        fake_db = _FakeDB(seen_count=10)
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        yield
        app_main.app.dependency_overrides.clear()

    def test_flag_disabled_returns_introduce(self, monkeypatch):
        """When FEATURE_PROGRESSIVE_EDUCATION=False, depth is always 'introduce'."""
        monkeypatch.setattr(app_main, "FEATURE_PROGRESSIVE_EDUCATION", False)
        client = TestClient(app_main.app)
        response = client.post("/analyze", json={"user_text": "I feel stressed out"})
        assert response.status_code == 200
        assert response.json()["education_depth"] == "introduce"

    def test_flag_enabled_returns_deepen_for_high_seen_count(self, monkeypatch):
        """When FEATURE_PROGRESSIVE_EDUCATION=True and seen_count=10, depth is 'deepen'."""
        monkeypatch.setattr(app_main, "FEATURE_PROGRESSIVE_EDUCATION", True)
        client = TestClient(app_main.app)
        response = client.post("/analyze", json={"user_text": "I feel stressed out"})
        assert response.status_code == 200
        assert response.json()["education_depth"] == "deepen"
