"""Integration tests for intervention variant selection."""

from typing import Any, Dict, List

import pytest
from fastapi.testclient import TestClient

from app import main as app_main


class _FakeDBManager:
    def __init__(self):
        self.logged = []
        self.feedback = []
        self.feedback_needs = []
        self.node_history = []

    def log_and_analyze(
        self,
        node_name: str,
        confidence: float,
        title: str,
        task: str,
        sublabel: str = "unspecified",
    ):
        self.logged.append((node_name, sublabel, confidence, title, task))
        return "Low", False

    def resolve_intervention(self, was_successful: bool, needs_check: Dict[str, bool] | None = None):
        self.feedback.append(was_successful)

    def get_history(self):
        return []

    def reset_all_data(self):
        return True


@pytest.fixture(autouse=True)
def _patch_dependencies(monkeypatch):
    # Patch AI to return different nodes for different test inputs
    async def fake_query_local_ai(text: str, request_id: str = "") -> Dict[str, Any]:
        if "procrastination" in text.lower() or "avoid" in text.lower() or "fail" in text.lower():
            return {
                "detected_node": "Procrastination",
                "emotion_sublabel": "Fear of Failure",
                "confidence": 0.95,
                "reasoning": "procrastination detected",
            }
        elif "anxiety" in text.lower() or "hypervigilant" in text.lower():
            return {
                "detected_node": "Anxiety",
                "emotion_sublabel": "Hypervigilance",
                "confidence": 0.95,
                "reasoning": "anxiety detected",
            }
        elif "overwhelm" in text.lower() or "paralyz" in text.lower():
            return {
                "detected_node": "Overwhelm",
                "emotion_sublabel": "Paralysis",
                "confidence": 0.95,
                "reasoning": "overwhelm detected",
            }
        elif "shame" in text.lower() or "ashamed" in text.lower():
            return {
                "detected_node": "Shame",
                "emotion_sublabel": "Self-Blame",
                "confidence": 0.95,
                "reasoning": "shame detected",
            }
        else:
            return {
                "detected_node": "Stress",
                "emotion_sublabel": "Overload",
                "confidence": 0.95,
                "reasoning": "stress detected",
            }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_local_ai)

    fake_db = _FakeDBManager()
    app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db

    yield fake_db

    app_main.app.dependency_overrides.clear()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app_main.app)


class TestInterventionVariantsAPI:
    """Tests for intervention variants in /analyze endpoint."""

    def test_analyze_returns_intervention_variants_for_procrastination(self, client):
        """Procrastination /analyze response includes intervention_variants."""
        response = client.post(
            "/analyze",
            json={"user_text": "I procrastinate because I fear failing"},
        )
        assert response.status_code == 200
        data = response.json()

        assert data["detected_node"] == "Procrastination"
        assert "intervention_variants" in data
        # Procrastination has 3 variants, should return them
        if data["intervention_variants"]:
            variants = data["intervention_variants"]
            assert len(variants) > 0
            # Each variant should have required fields
            for variant in variants:
                assert "title" in variant
                assert "task" in variant
                assert "education" in variant
                assert "type" in variant

    def test_analyze_returns_intervention_variants_for_anxiety(self, client):
        """Anxiety /analyze response includes intervention_variants if available."""
        response = client.post(
            "/analyze",
            json={"user_text": "I'm hypervigilant and scanning for threats"},
        )
        assert response.status_code == 200
        data = response.json()

        assert data["detected_node"] == "Anxiety"
        assert "intervention_variants" in data
        # Anxiety has variants
        if data.get("intervention_variants"):
            variants = data["intervention_variants"]
            assert len(variants) > 0
            for variant in variants:
                assert "title" in variant
                assert "task" in variant
                assert "education" in variant

    def test_analyze_returns_intervention_variants_for_overwhelm(self, client):
        """Overwhelm with Paralysis /analyze response includes intervention_variants."""
        response = client.post(
            "/analyze",
            json={"user_text": "I'm paralyzed and can't take action"},
        )
        assert response.status_code == 200
        data = response.json()

        assert data["detected_node"] == "Overwhelm"
        assert "intervention_variants" in data
        if data.get("intervention_variants"):
            variants = data["intervention_variants"]
            for variant in variants:
                assert "title" in variant
                assert "task" in variant

    def test_analyze_shame_has_no_variants(self, client):
        """Shame state has no variants (simple intervention)."""
        response = client.post(
            "/analyze",
            json={"user_text": "I feel ashamed and self-blame"},
        )
        assert response.status_code == 200
        data = response.json()

        assert data["detected_node"] == "Shame"
        # Shame should have no variants or None
        variants = data.get("intervention_variants")
        # Shame has no variants structure, so intervention_variants should be None/empty
        assert variants is None or len(variants) == 0

    def test_analyze_response_contract_with_variants(self, client):
        """AnalysisResponse contract is maintained with intervention_variants field."""
        response = client.post(
            "/analyze",
            json={"user_text": "I feel stressed"},
        )
        assert response.status_code == 200
        data = response.json()

        # Required fields
        assert "detected_node" in data
        assert "confidence" in data
        assert "reasoning" in data
        assert "risk_level" in data
        assert "loop_detected" in data
        assert "intervention_title" in data
        assert "intervention_task" in data

        # New fields
        assert "node_arc_position" in data
        assert "node_arc_label" in data
        assert "intervention_variants" in data  # Optional but present

        # Types
        assert isinstance(data["detected_node"], str)
        assert isinstance(data["confidence"], (int, float))
        assert isinstance(data["intervention_title"], str)
        assert isinstance(data["intervention_type"], str)
        if data["intervention_variants"]:
            assert isinstance(data["intervention_variants"], list)
            for variant in data["intervention_variants"]:
                assert "title" in variant
                assert "task" in variant


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
