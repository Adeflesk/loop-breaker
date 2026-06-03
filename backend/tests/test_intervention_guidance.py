"""Tests for intervention guidance (steps + alternatives) feature."""
import pytest
from app.models import AlternativeIntervention, AnalysisResponse


class TestAlternativeInterventionModel:
    def test_valid_alternative_has_required_fields(self):
        alt = AlternativeIntervention(
            title="Cognitive Reframe",
            task="Notice the thought...",
            education="Shame activates negativity bias...",
            type="cognitive",
        )
        assert alt.title == "Cognitive Reframe"
        assert alt.task == "Notice the thought..."
        assert alt.education == "Shame activates negativity bias..."
        assert alt.type == "cognitive"

    def test_alternatives_field_on_analysis_response(self):
        response = AnalysisResponse(
            detected_node="Shame",
            confidence=0.9,
            reasoning="test",
            risk_level="low",
            loop_detected=False,
            intervention_title="Mindful Self-Compassion",
            intervention_task="Take a breath.",
            alternatives=[
                AlternativeIntervention(
                    title="Cognitive Reframe",
                    task="Notice the thought...",
                    education="Shame activates...",
                    type="cognitive",
                )
            ],
        )
        assert response.alternatives is not None
        assert len(response.alternatives) == 1
        assert response.alternatives[0].title == "Cognitive Reframe"

    def test_alternatives_defaults_to_none(self):
        response = AnalysisResponse(
            detected_node="Stress",
            confidence=0.8,
            reasoning="test",
            risk_level="medium",
            loop_detected=False,
            intervention_title="Physiological Sigh",
            intervention_task="Take a breath.",
        )
        assert response.alternatives is None


class TestGetAlternatives:
    def test_shame_returns_two_alternatives(self):
        from app.main import get_alternatives
        alts = get_alternatives("Shame", None)
        assert len(alts) == 2
        assert alts[0]["title"] == "Cognitive Reframe"
        assert alts[1]["title"] == "Zone 2 Walk"

    def test_shame_alternatives_have_required_keys(self):
        from app.main import get_alternatives
        alts = get_alternatives("Shame", None)
        for alt in alts:
            assert "title" in alt
            assert "task" in alt
            assert "education" in alt
            assert "type" in alt

    def test_numbness_returns_empty_alternatives(self):
        from app.main import get_alternatives
        alts = get_alternatives("Numbness", None)
        assert alts == []

    def test_isolation_returns_empty_alternatives(self):
        from app.main import get_alternatives
        alts = get_alternatives("Isolation", None)
        assert alts == []

    def test_unknown_state_returns_empty_alternatives(self):
        from app.main import get_alternatives
        alts = get_alternatives("UnknownState", None)
        assert alts == []


class TestAnalyzeResponseAlternatives:
    def setup_method(self):
        from unittest.mock import MagicMock
        from app import main as app_main
        from fastapi.testclient import TestClient
        app_main.app.state.db = self._make_fake_db()
        app_main.app.state.crisis_service = MagicMock()
        app_main.app.state.crisis_service.detect_crisis.return_value = (False, [])
        self.client = TestClient(app_main.app)
        self.app_main = app_main

    def _make_fake_db(self):
        from unittest.mock import MagicMock
        db = MagicMock()
        db.save_state.return_value = None
        db.get_loop_count.return_value = 0
        db.get_recent_states.return_value = []
        db.get_shame_count_24h.return_value = 0
        db.get_intervention_seen_count.return_value = 0
        db.increment_intervention_seen_count.return_value = None
        db.save_journal_entry.return_value = None
        db.get_personal_loop_context.return_value = None
        db.get_intervention_effectiveness.return_value = None
        return db

    def test_shame_response_includes_alternatives(self):
        from unittest.mock import patch, AsyncMock
        mock = AsyncMock(return_value={
            "detected_node": "Shame",
            "emotion_sublabel": None,
            "confidence": 0.85,
            "reasoning": "User expressed shame",
        })
        with patch.object(self.app_main, "query_local_ai", mock):
            response = self.client.post("/analyze", json={"user_text": "I feel so ashamed of myself"})
        assert response.status_code == 200
        data = response.json()
        assert "alternatives" in data
        assert data["alternatives"] is not None
        assert len(data["alternatives"]) == 2
        assert data["alternatives"][0]["title"] == "Cognitive Reframe"
        assert data["alternatives"][1]["title"] == "Zone 2 Walk"

    def test_shame_response_includes_msc_steps(self):
        from unittest.mock import patch, AsyncMock
        mock = AsyncMock(return_value={
            "detected_node": "Shame",
            "emotion_sublabel": None,
            "confidence": 0.85,
            "reasoning": "User expressed shame",
        })
        with patch.object(self.app_main, "query_local_ai", mock):
            response = self.client.post("/analyze", json={"user_text": "I feel so ashamed of myself"})
        assert response.status_code == 200
        data = response.json()
        assert "msc_steps" in data
        assert data["msc_steps"] is not None
        assert len(data["msc_steps"]) == 3
        assert data["msc_steps"][0]["name"] == "Mindfulness"

    def test_non_shame_state_has_null_or_empty_alternatives(self):
        from unittest.mock import patch, AsyncMock
        mock = AsyncMock(return_value={
            "detected_node": "Numbness",
            "emotion_sublabel": None,
            "confidence": 0.75,
            "reasoning": "User feels numb",
        })
        with patch.object(self.app_main, "query_local_ai", mock):
            response = self.client.post("/analyze", json={"user_text": "I feel completely numb"})
        assert response.status_code == 200
        data = response.json()
        alts = data.get("alternatives")
        assert alts is None or alts == []

    def test_non_shame_state_has_null_msc_steps(self):
        from unittest.mock import patch, AsyncMock
        mock = AsyncMock(return_value={
            "detected_node": "Stress",
            "emotion_sublabel": None,
            "confidence": 0.8,
            "reasoning": "User is stressed",
        })
        with patch.object(self.app_main, "query_local_ai", mock):
            response = self.client.post("/analyze", json={"user_text": "I am so stressed"})
        assert response.status_code == 200
        data = response.json()
        assert data.get("msc_steps") is None
