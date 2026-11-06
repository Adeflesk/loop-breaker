"""Tests for Phase 7.1 proactive daily practice mode.

Covers:
- PracticeSessionRequest and PracticeStatsResponse Pydantic models
- POST /practice creates a PracticeSession record
- GET /practice-stats returns practice streak, weekly count, total, and recent sessions
- GET /insight includes practice_streak and days_practiced_this_week
- FEATURE_DAILY_PRACTICE flag controls endpoint availability
- db.create_practice_session() and db.get_practice_stats() unit tests
"""

from datetime import date, timedelta
from typing import Any, Dict
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app import main as app_main
from app.db import BehavioralStateManager
from app.models import PracticeSessionRequest, PracticeStatsResponse


class _FakePracticeDB:
    def __init__(self, create_result: bool = True, stats: Dict[str, Any] = None):
        self._create_result = create_result
        self._stats = stats or {
            "practice_streak": 3,
            "days_practiced_this_week": 4,
            "total_sessions": 9,
            "recent_sessions": [
                {
                    "timestamp": "2026-11-02T08:00:00Z",
                    "intention": "Pause before reacting",
                    "gratitude": "Morning coffee and quiet focus",
                    "breathing_seconds": 60,
                }
            ],
        }
        self.last_create_kwargs: Dict[str, Any] = {}

    def create_practice_session(
        self, intention: str, gratitude: str, breathing_seconds: int = 60
    ) -> bool:
        self.last_create_kwargs = {
            "intention": intention,
            "gratitude": gratitude,
            "breathing_seconds": breathing_seconds,
        }
        return self._create_result

    def get_practice_stats(self, limit: int = 10) -> Dict[str, Any]:
        return self._stats

    def get_ai_insight(self):
        return {
            "top_loop": "Stress",
            "count": 4,
            "success_rate": 75.0,
            "trend": "improving",
            "streak": 3,
            "missing_need": None,
            "trigger_count": 0,
            "coaching_message": "Great job!",
        }

    def get_weekly_activity(self):
        return [True, True, False, False, False, False, False]


class TestPracticeModels:
    def test_valid_practice_request(self):
        req = PracticeSessionRequest(
            intention="Stay present in meetings",
            gratitude="Supportive teammates",
            breathing_seconds=90,
        )
        assert req.intention == "Stay present in meetings"
        assert req.gratitude == "Supportive teammates"
        assert req.breathing_seconds == 90

    def test_empty_intention_rejected(self):
        with pytest.raises(ValidationError):
            PracticeSessionRequest(intention="", gratitude="Grateful")

    def test_negative_breathing_seconds_rejected(self):
        with pytest.raises(ValidationError):
            PracticeSessionRequest(
                intention="Focus", gratitude="Health", breathing_seconds=-5
            )

    def test_practice_stats_response_model(self):
        resp = PracticeStatsResponse(
            practice_streak=2,
            days_practiced_this_week=3,
            total_sessions=5,
            recent_sessions=[],
        )
        assert resp.practice_streak == 2
        assert resp.days_practiced_this_week == 3


class TestPracticeEndpoints:
    def test_post_practice_returns_201(self, monkeypatch):
        monkeypatch.setattr(app_main, "FEATURE_DAILY_PRACTICE", True)
        fake_db = _FakePracticeDB(create_result=True)
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            resp = client.post(
                "/practice",
                json={
                    "intention": "Respond instead of react",
                    "gratitude": "Good sleep last night",
                    "breathing_seconds": 60,
                },
            )
            assert resp.status_code == 201
            assert resp.json() == {"status": "recorded"}
            assert fake_db.last_create_kwargs["intention"] == "Respond instead of react"
        finally:
            app_main.app.dependency_overrides.clear()

    def test_post_practice_returns_404_when_flag_disabled(self, monkeypatch):
        monkeypatch.setattr(app_main, "FEATURE_DAILY_PRACTICE", False)
        fake_db = _FakePracticeDB()
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            resp = client.post(
                "/practice",
                json={"intention": "Focus", "gratitude": "Sun"},
            )
            assert resp.status_code == 404
        finally:
            app_main.app.dependency_overrides.clear()

    def test_post_practice_returns_503_when_db_fails(self, monkeypatch):
        monkeypatch.setattr(app_main, "FEATURE_DAILY_PRACTICE", True)
        fake_db = _FakePracticeDB(create_result=False)
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            resp = client.post(
                "/practice",
                json={"intention": "Focus", "gratitude": "Sun"},
            )
            assert resp.status_code == 503
        finally:
            app_main.app.dependency_overrides.clear()

    def test_get_practice_stats_returns_200(self, monkeypatch):
        monkeypatch.setattr(app_main, "FEATURE_DAILY_PRACTICE", True)
        fake_db = _FakePracticeDB()
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            resp = client.get("/practice-stats")
            assert resp.status_code == 200
            body = resp.json()
            assert body["practice_streak"] == 3
            assert body["days_practiced_this_week"] == 4
            assert body["total_sessions"] == 9
            assert len(body["recent_sessions"]) == 1
        finally:
            app_main.app.dependency_overrides.clear()

    def test_get_practice_stats_returns_404_when_disabled(self, monkeypatch):
        monkeypatch.setattr(app_main, "FEATURE_DAILY_PRACTICE", False)
        fake_db = _FakePracticeDB()
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            resp = client.get("/practice-stats")
            assert resp.status_code == 404
        finally:
            app_main.app.dependency_overrides.clear()

    def test_insight_includes_practice_streak(self, monkeypatch):
        monkeypatch.setattr(app_main, "FEATURE_DAILY_PRACTICE", True)
        fake_db = _FakePracticeDB()
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            resp = client.get("/insight")
            assert resp.status_code == 200
            body = resp.json()
            assert body["practice_streak"] == 3
            assert body["days_practiced_this_week"] == 4
        finally:
            app_main.app.dependency_overrides.clear()


class TestDBPracticeMethods:
    def _make_manager(self):
        with patch("app.db.GraphDatabase.driver") as mock_driver_fn:
            mock_driver = MagicMock()
            mock_driver_fn.return_value = mock_driver
            mgr = BehavioralStateManager("bolt://localhost:7687", "neo4j", "test")
            mock_session = MagicMock()
            mock_driver.session.return_value.__enter__.return_value = mock_session
            return mgr, mock_session

    def test_create_practice_session_success(self):
        mgr, mock_session = self._make_manager()
        assert mgr.create_practice_session("Calm focus", "Family", 60) is True
        mock_session.run.assert_called_once()

    def test_create_practice_session_unavailable(self):
        mgr, _ = self._make_manager()
        mgr.is_available = False
        assert mgr.create_practice_session("Calm focus", "Family", 60) is False

    def test_create_practice_session_exception(self):
        mgr, mock_session = self._make_manager()
        mock_session.run.side_effect = RuntimeError("DB failure")
        assert mgr.create_practice_session("Calm focus", "Family", 60) is False
        assert mgr.is_available is False

    def test_get_practice_stats_computes_streak_and_weekly_days(self):
        mgr, mock_session = self._make_manager()
        today = date.today()
        yesterday = today - timedelta(days=1)

        mock_session.run.return_value = [
            {
                "timestamp": f"{today.isoformat()}T08:00:00Z",
                "practice_date": today.isoformat(),
                "intention": "Today intention",
                "gratitude": "Today gratitude",
                "breathing_seconds": 60,
            },
            {
                "timestamp": f"{yesterday.isoformat()}T08:00:00Z",
                "practice_date": yesterday.isoformat(),
                "intention": "Yesterday intention",
                "gratitude": "Yesterday gratitude",
                "breathing_seconds": 60,
            },
        ]

        stats = mgr.get_practice_stats(limit=5)
        assert stats["practice_streak"] == 2
        assert stats["total_sessions"] == 2
        assert stats["days_practiced_this_week"] >= 1
        assert len(stats["recent_sessions"]) == 2

    def test_get_practice_stats_unavailable(self):
        mgr, _ = self._make_manager()
        mgr.is_available = False
        stats = mgr.get_practice_stats()
        assert stats == {
            "practice_streak": 0,
            "days_practiced_this_week": 0,
            "total_sessions": 0,
            "recent_sessions": [],
        }

    def test_get_practice_stats_exception(self):
        mgr, mock_session = self._make_manager()
        mock_session.run.side_effect = RuntimeError("DB error")
        stats = mgr.get_practice_stats()
        assert stats["practice_streak"] == 0
        assert stats["total_sessions"] == 0

    def test_save_and_get_user_profile(self):
        mgr, mock_session = self._make_manager()
        assert mgr.save_user_profile(["Presence", "Focus"], "I am someone who pauses first") is True
        mock_session.run.assert_called_once()

        mock_result = MagicMock()
        mock_result.single.return_value = {
            "values": ["Presence", "Focus"],
            "identity_statement": "I am someone who pauses first",
        }
        mock_session.run.return_value = mock_result
        profile = mgr.get_user_profile()
        assert profile["values"] == ["Presence", "Focus"]
        assert profile["identity_statement"] == "I am someone who pauses first"

    def test_user_profile_unavailable_and_error(self):
        mgr, mock_session = self._make_manager()
        mgr.is_available = False
        assert mgr.save_user_profile(["Presence"], "Statement") is False
        assert mgr.get_user_profile() == {"values": [], "identity_statement": ""}

        mgr.is_available = True
        mock_session.run.side_effect = RuntimeError("DB failure")
        assert mgr.save_user_profile(["Presence"], "Statement") is False
        mgr.is_available = True
        assert mgr.get_user_profile() == {"values": [], "identity_statement": ""}


class TestProfileEndpoints:
    def test_post_and_get_profile(self, monkeypatch):
        monkeypatch.setattr(app_main, "FEATURE_IDENTITY_LAYER", True)
        fake_db = _FakePracticeDB()
        fake_db.save_user_profile = lambda values, identity_statement: True
        fake_db.get_user_profile = lambda: {
            "values": ["Presence", "Courage"],
            "identity_statement": "I am someone who responds with intention",
        }
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            post_resp = client.post(
                "/profile",
                json={
                    "values": ["Presence", "Courage"],
                    "identity_statement": "I am someone who responds with intention",
                },
            )
            assert post_resp.status_code == 200
            assert post_resp.json() == {"status": "saved"}

            get_resp = client.get("/profile")
            assert get_resp.status_code == 200
            assert get_resp.json()["values"] == ["Presence", "Courage"]

            insight_resp = client.get("/insight")
            assert insight_resp.status_code == 200
            assert "Presence" in (insight_resp.json().get("values_nudge") or "")
            assert (
                insight_resp.json().get("identity_statement")
                == "I am someone who responds with intention"
            )
        finally:
            app_main.app.dependency_overrides.clear()

    def test_profile_returns_404_when_disabled(self, monkeypatch):
        monkeypatch.setattr(app_main, "FEATURE_IDENTITY_LAYER", False)
        fake_db = _FakePracticeDB()
        app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
        client = TestClient(app_main.app)
        try:
            assert client.get("/profile").status_code == 404
            assert (
                client.post(
                    "/profile",
                    json={"values": ["Focus"], "identity_statement": "I focus"},
                ).status_code
                == 404
            )
        finally:
            app_main.app.dependency_overrides.clear()

