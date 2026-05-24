from datetime import date
from typing import Any, Dict, List
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from app import main as app_main
from app.db import BehavioralStateManager


# ── Helpers ──────────────────────────────────────────────────────────────────

class _FakeRecord:
    def __init__(self, data: Dict[str, Any]) -> None:
        self._data = data

    def __getitem__(self, key: str) -> Any:
        return self._data[key]


def _fake_session(rows: List[Dict[str, Any]]) -> MagicMock:
    session = MagicMock()
    session.__enter__ = MagicMock(return_value=session)
    session.__exit__ = MagicMock(return_value=None)
    session.run.return_value = [_FakeRecord(r) for r in rows]
    return session


def _mgr_with_session(rows: List[Dict[str, Any]]) -> BehavioralStateManager:
    mgr = BehavioralStateManager.__new__(BehavioralStateManager)
    mgr.is_available = True
    mock_driver = MagicMock()
    mock_driver.session.return_value = _fake_session(rows)
    mgr.driver = mock_driver
    return mgr


# ── Unit tests for get_weekly_activity() ─────────────────────────────────────

def test_returns_seven_booleans():
    mgr = _mgr_with_session([])
    result = mgr.get_weekly_activity()
    assert len(result) == 7
    assert all(isinstance(v, bool) for v in result)


def test_all_false_when_no_entries():
    mgr = _mgr_with_session([])
    assert mgr.get_weekly_activity() == [False] * 7


def test_today_is_true_when_helped_today():
    today_str = date.today().isoformat()
    mgr = _mgr_with_session([{"active_date": today_str}])
    result = mgr.get_weekly_activity()
    today_idx = date.today().weekday()  # 0=Mon, 6=Sun
    assert result[today_idx] is True


def test_other_days_remain_false():
    today_str = date.today().isoformat()
    mgr = _mgr_with_session([{"active_date": today_str}])
    result = mgr.get_weekly_activity()
    today_idx = date.today().weekday()
    for i, val in enumerate(result):
        if i != today_idx:
            assert val is False


def test_unavailable_returns_all_false():
    mgr = BehavioralStateManager.__new__(BehavioralStateManager)
    mgr.is_available = False
    assert mgr.get_weekly_activity() == [False] * 7


# ── Endpoint test: /insight includes weekly_activity ─────────────────────────

class _InsightFakeDB:
    def get_ai_insight(self):
        return {
            "top_loop": "Stress",
            "count": 2,
            "success_rate": 50.0,
            "trend": "stable",
            "streak": 1,
            "missing_need": None,
            "trigger_count": 0,
            "coaching_message": "Keep going!",
        }

    def get_weekly_activity(self) -> list:
        return [True, True, False, False, False, False, False]

    def close(self):
        pass


@pytest.fixture
def insight_client():
    fake_db = _InsightFakeDB()
    app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db
    yield TestClient(app_main.app)
    app_main.app.dependency_overrides.clear()


def test_insight_includes_weekly_activity(insight_client):
    response = insight_client.get("/insight")
    assert response.status_code == 200
    data = response.json()
    assert "weekly_activity" in data
    assert isinstance(data["weekly_activity"], list)
    assert len(data["weekly_activity"]) == 7


def test_insight_weekly_activity_values(insight_client):
    response = insight_client.get("/insight")
    data = response.json()
    assert data["weekly_activity"][0] is True
    assert data["weekly_activity"][1] is True
    assert data["weekly_activity"][2] is False
