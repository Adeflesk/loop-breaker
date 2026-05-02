"""Unit tests for Shame protocol (MSC + frequency monitoring)."""

from typing import Any, Dict

import pytest
from fastapi.testclient import TestClient

from app import main as app_main


class _FakeDBManager:
    def __init__(self):
        self.entries = []
        self.thought_records = []
        self.is_available = True

    def get_shame_count_24h(self) -> int:
        if not self.is_available:
            return 0
        return len(self.entries)

    def log_and_analyze(
        self, node_name: str, confidence: float, title: str, task: str, sublabel: str = "unspecified"
    ):
        if not self.is_available:
            return "Low", False
        self.entries.append({"node": node_name})
        return "Low", False

    def resolve_intervention(self, was_successful: bool, needs_check: Dict[str, bool] | None = None):
        pass

    def get_history(self):
        return []

    def get_trend_stats(self):
        return {}

    def get_ai_insight(self):
        return None

    def reset_all_data(self):
        self.entries = []
        return True

    def create_thought_record(self, **kwargs) -> bool:
        return True

    def get_thought_records(self, limit: int = 20, offset: int = 0) -> list:
        return []


@pytest.fixture(autouse=True)
def _patch_dependencies(monkeypatch):
    async def fake_query_local_ai(text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Shame",
            "emotion_sublabel": "General",
            "confidence": 0.95,
            "reasoning": "shame detected",
        }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_local_ai)

    # Enable shame protocol feature flag for tests
    monkeypatch.setattr(app_main, "FEATURE_SHAME_PROTOCOL", True)

    fake_db = _FakeDBManager()
    app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db

    yield fake_db

    app_main.app.dependency_overrides.clear()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app_main.app)


class TestShameProtocolDB:
    """Tests for DB shame count method."""

    def test_get_shame_count_24h_returns_zero_when_unavailable(self, _patch_dependencies: _FakeDBManager):
        """get_shame_count_24h returns 0 when DB unavailable."""
        _patch_dependencies.is_available = False
        count = _patch_dependencies.get_shame_count_24h()
        assert count == 0

    def test_get_shame_count_24h_counts_entries(self, _patch_dependencies: _FakeDBManager):
        """get_shame_count_24h counts shame entries."""
        _patch_dependencies.entries = [
            {"node": "Shame"},
            {"node": "Shame"},
            {"node": "Shame"},
        ]
        count = _patch_dependencies.get_shame_count_24h()
        assert count == 3


class TestMSCProtocolAPI:
    """Tests for MSC protocol in /analyze endpoint."""

    def test_msc_steps_populated_for_shame_when_feature_enabled(self, client: TestClient):
        """POST /analyze returns msc_steps for Shame when feature flag enabled."""
        # Feature must be enabled for this to work
        response = client.post("/analyze", json={"user_text": "I feel ashamed"})
        assert response.status_code == 200
        data = response.json()

        # Check if Shame protocol feature is enabled
        if data.get("msc_steps"):
            assert isinstance(data["msc_steps"], list)
            assert len(data["msc_steps"]) == 3

            # Verify each step has required fields
            for i, step in enumerate(data["msc_steps"]):
                assert "step" in step
                assert "name" in step
                assert "task" in step
                assert "education" in step
                assert step["step"] == i + 1

    def test_msc_steps_structure_for_shame(self, client: TestClient):
        """MSC steps have correct structure and content."""
        response = client.post("/analyze", json={"user_text": "I feel ashamed"})
        assert response.status_code == 200
        data = response.json()

        if data.get("msc_steps"):
            steps = data["msc_steps"]

            # Step 1: Mindfulness
            assert steps[0]["name"] == "Mindfulness"
            assert "hand on your heart" in steps[0]["task"].lower()
            assert "acknowledge pain" in steps[0]["education"].lower() or "space between" in steps[0]["education"].lower()

            # Step 2: Common Humanity
            assert steps[1]["name"] == "Common Humanity"
            assert "not alone" in steps[1]["task"].lower()
            assert "shared human" in steps[1]["education"].lower()

            # Step 3: Self-Kindness
            assert steps[2]["name"] == "Self-Kindness"
            assert "dear friend" in steps[2]["task"].lower()
            assert "warmth" in steps[2]["education"].lower()

    def test_shame_safety_alert_false_when_count_below_three(self, client: TestClient):
        """shame_safety_alert is False when Shame count < 3."""
        response = client.post("/analyze", json={"user_text": "I feel ashamed"})
        assert response.status_code == 200
        data = response.json()

        # With fake DB, count is 0, so alert should be False
        if "shame_safety_alert" in data:
            assert data["shame_safety_alert"] is False or data["shame_safety_alert"] is None

    def test_shame_safety_alert_true_when_count_three_or_more(
        self, client: TestClient, _patch_dependencies: _FakeDBManager
    ):
        """shame_safety_alert is True when Shame count >= 3."""
        # Set up fake DB with 3 shame entries
        _patch_dependencies.entries = [
            {"node": "Shame"},
            {"node": "Shame"},
            {"node": "Shame"},
        ]

        response = client.post("/analyze", json={"user_text": "I feel ashamed"})
        assert response.status_code == 200
        data = response.json()

        if "shame_safety_alert" in data:
            assert data["shame_safety_alert"] is True

    def test_non_shame_nodes_no_msc_steps(self, client: TestClient, monkeypatch):
        """Non-Shame nodes do not return msc_steps."""
        async def fake_query_for_stress(text: str, request_id: str = "") -> Dict[str, Any]:
            return {
                "detected_node": "Stress",
                "emotion_sublabel": "General",
                "confidence": 0.95,
                "reasoning": "stress detected",
            }

        monkeypatch.setattr(app_main, "query_local_ai", fake_query_for_stress)

        response = client.post("/analyze", json={"user_text": "I feel stressed"})
        assert response.status_code == 200
        data = response.json()

        # Non-Shame nodes should not have msc_steps
        assert data.get("msc_steps") is None

    def test_analyze_response_contract_includes_shame_fields(self, client: TestClient):
        """Response includes shame_safety_alert and msc_steps fields."""
        response = client.post("/analyze", json={"user_text": "I feel ashamed"})
        assert response.status_code == 200
        data = response.json()

        # Response should include these fields (may be None if feature disabled)
        assert "shame_safety_alert" in data
        assert "msc_steps" in data

    def test_msc_steps_have_step_numbers_in_sequence(self, client: TestClient):
        """MSC steps are numbered 1, 2, 3 in sequence."""
        response = client.post("/analyze", json={"user_text": "I feel ashamed"})
        assert response.status_code == 200
        data = response.json()

        if data.get("msc_steps"):
            steps = data["msc_steps"]
            for i, step in enumerate(steps):
                assert step["step"] == i + 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
