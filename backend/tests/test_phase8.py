"""Tests for Phase 8: Environmental Design Toolkit, Advanced Pattern Intelligence, and Export."""

from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from app import main as app_main
from app.ai import generate_weekly_narrative
from app.db import BehavioralStateManager


class _FakePhase8DB:
    def __init__(self, save_result: bool = True):
        self._save_result = save_result

    def save_environment_audit(self, target_loop, checked_items, custom_friction_step=""):
        return self._save_result

    def get_environment_audit(self):
        return {
            "target_loop": "Procrastination",
            "checked_items": ["Phone in another room", "Single browser tab open"],
            "custom_friction_step": "Log out of social feeds at 9pm",
            "updated_at": "2026-11-08T10:00:00Z",
        }

    def get_ai_insight(self):
        return {
            "top_loop": "Procrastination",
            "count": 6,
            "success_rate": 80.0,
            "trend": "improving",
            "streak": 4,
            "missing_need": None,
            "trigger_count": 0,
            "coaching_message": "Strong progress!",
        }

    def get_weekly_activity(self):
        return [True, True, True, False, False, False, False]

    def get_practice_stats(self, limit: int = 10):
        return {
            "practice_streak": 3,
            "days_practiced_this_week": 3,
            "total_sessions": 6,
            "recent_sessions": [],
        }

    def get_user_profile(self):
        return {
            "values": ["Focus"],
            "identity_statement": "I am someone who starts with 5 minutes",
        }

    def get_advanced_patterns(self, days: int = 30):
        return {
            "peak_time_window": "afternoon",
            "pre_loop_signal": "Stress",
        }

    def get_history(self, start_date=None, end_date=None, limit=500):
        return [{"state": "Procrastination", "confidence": 0.85, "was_successful": True}]

    def get_thought_records(self, limit=100, offset=0):
        return []


class TestWeeklyNarrative:
    def test_generate_weekly_narrative_empty(self):
        text = generate_weekly_narrative({"top_loop": "None"})
        assert "just beginning" in text

    def test_generate_weekly_narrative_full(self):
        text = generate_weekly_narrative(
            {
                "top_loop": "Procrastination",
                "success_rate": 82.4,
                "practice_streak": 4,
                "peak_time_window": "late_night",
                "pre_loop_signal": "Stress",
            }
        )
        assert "Procrastination" in text
        assert "82%" in text
        assert "late night" in text
        assert "Stress" in text
        assert "4-day" in text


class TestPhase8Endpoints:
    def test_post_and_get_environment_audit(self):
        fake_db = _FakePhase8DB()
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            post_resp = client.post(
                "/environment-audit",
                json={
                    "target_loop": "Procrastination",
                    "checked_items": ["Phone in another room"],
                    "custom_friction_step": "Use site blocker",
                },
            )
            assert post_resp.status_code == 200
            assert post_resp.json() == {"status": "saved"}

            get_resp = client.get("/environment-audit")
            assert get_resp.status_code == 200
            assert get_resp.json()["target_loop"] == "Procrastination"
            assert len(get_resp.json()["checked_items"]) == 2
        finally:
            app_main.app.dependency_overrides.clear()

    def test_weekly_narrative_endpoint(self):
        fake_db = _FakePhase8DB()
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            resp = client.get("/weekly-narrative")
            assert resp.status_code == 200
            body = resp.json()
            assert "Procrastination" in body["narrative"]
            assert body["peak_time_window"] == "afternoon"
            assert body["pre_loop_signal"] == "Stress"
        finally:
            app_main.app.dependency_overrides.clear()

    def test_export_endpoint(self):
        fake_db = _FakePhase8DB()
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            resp = client.get("/export")
            assert resp.status_code == 200
            body = resp.json()
            assert "generated_at" in body
            assert body["insight"]["top_loop"] == "Procrastination"
            assert len(body["history"]) == 1
            assert body["environment_audit"]["target_loop"] == "Procrastination"
        finally:
            app_main.app.dependency_overrides.clear()

    def test_insight_includes_phase8_fields(self):
        fake_db = _FakePhase8DB()
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            resp = client.get("/insight")
            assert resp.status_code == 200
            body = resp.json()
            assert body["peak_time_window"] == "afternoon"
            assert body["pre_loop_signal"] == "Stress"
            assert body["environment_audit_prompt"] is True
        finally:
            app_main.app.dependency_overrides.clear()


class TestDBPhase8Methods:
    def _make_manager(self):
        with patch("app.db.GraphDatabase.driver") as mock_driver_fn:
            mock_driver = MagicMock()
            mock_driver_fn.return_value = mock_driver
            mgr = BehavioralStateManager("bolt://localhost:7687", "neo4j", "test")
            mock_session = MagicMock()
            mock_driver.session.return_value.__enter__.return_value = mock_session
            return mgr, mock_session

    def test_save_and_get_environment_audit(self):
        mgr, mock_session = self._make_manager()
        assert (
            mgr.save_environment_audit(
                "Stress", ["Clear desk", "Water bottle visible"], "Close Slack"
            )
            is True
        )

        mock_result = MagicMock()
        mock_result.single.return_value = {
            "target_loop": "Stress",
            "checked_items": ["Clear desk", "Water bottle visible"],
            "custom_friction_step": "Close Slack",
            "updated_at": "2026-11-08T10:00:00Z",
        }
        mock_session.run.return_value = mock_result
        audit = mgr.get_environment_audit()
        assert audit["target_loop"] == "Stress"
        assert len(audit["checked_items"]) == 2

    def test_environment_audit_unavailable_and_error(self):
        mgr, mock_session = self._make_manager()
        mgr.is_available = False
        assert mgr.save_environment_audit("Stress", []) is False
        assert mgr.get_environment_audit()["target_loop"] == ""

        mgr.is_available = True
        mock_session.run.side_effect = RuntimeError("DB error")
        assert mgr.save_environment_audit("Stress", []) is False
        mgr.is_available = True
        assert mgr.get_environment_audit()["target_loop"] == ""

    def test_get_advanced_patterns(self):
        mgr, _ = self._make_manager()
        mgr.get_loop_path = MagicMock(
            return_value=[
                {
                    "timestamp": "2026-11-07T14:00:00+00:00",
                    "state": "Stress",
                    "confidence": 0.8,
                    "has_intervention": False,
                },
                {
                    "timestamp": "2026-11-07T15:30:00+00:00",
                    "state": "Procrastination",
                    "confidence": 0.9,
                    "has_intervention": True,
                },
                {
                    "timestamp": "2026-11-08T09:00:00+00:00",
                    "state": "Anxiety",
                    "confidence": 0.7,
                    "has_intervention": False,
                },
                {
                    "timestamp": "2026-11-08T19:00:00+00:00",
                    "state": "Stress",
                    "confidence": 0.75,
                    "has_intervention": False,
                },
                {
                    "timestamp": "2026-11-08T23:30:00+00:00",
                    "state": "Procrastination",
                    "confidence": 0.85,
                    "has_intervention": True,
                },
            ]
        )

        patterns = mgr.get_advanced_patterns(days=30)
        assert patterns["peak_time_window"] == "afternoon"
        assert patterns["pre_loop_signal"] == "Stress"
