from typing import Any, Dict, List

import pytest
from fastapi.testclient import TestClient

from app import main as app_main


class _FakeRecord:
    def __init__(self, data: Dict[str, Any]) -> None:
        self._data = data

    def data(self) -> Dict[str, Any]:
        return self._data


class _FakeSession:
    def __init__(self, rows: List[Dict[str, Any]]) -> None:
        self._rows = rows

    def __enter__(self) -> "._FakeSession":  # type: ignore[name-match]
        return self

    def __exit__(self, exc_type, exc, tb) -> None:  # type: ignore[override]
        return None

    def run(self, _query: str):
        return [_FakeRecord(row) for row in self._rows]


class _FakeDriver:
    def __init__(self, rows: List[Dict[str, Any]]) -> None:
        self._rows = rows

    def session(self):
        return _FakeSession(self._rows)


class _FakeDBManager:
    def __init__(self) -> None:
        self.logged = []
        self.feedback = []
        self.feedback_needs = []
        self.node_history: List[str] = []
        self.insight_data = {
            "top_loop": "Stress",
            "count": 3,
            "success_rate": 66.6667,
            "trend": "improving",
            "streak": 3,
            "missing_need": "hydration",
            "trigger_count": 2,
            "coaching_message": "Pattern insight: unmet hydration often appears before repeat high-risk stress loops.",
        }
        self._history = [
            {
                "time": "2025-01-01T12:00:00",
                "state": "Stress",
                "intervention": "Physiological Sigh",
                "confidence": 0.9,
                "was_successful": True,
            }
        ]

    def log_and_analyze(
        self,
        node_name: str,
        confidence: float,
        title: str,
        task: str,
        sublabel: str = "General",
    ):
        self.logged.append((node_name, sublabel, confidence, title, task))
        self.node_history.append(node_name)
        recent = self.node_history[-3:]
        is_loop = len(recent) == 3 and len(set(recent)) == 1

        risk = "High" if is_loop else "Low"
        if sublabel in ["Overwhelmed", "Burnout", "Burnt-out"]:
            risk = "High"

        return risk, is_loop

    def resolve_intervention(self, was_successful: bool, needs_check: Dict[str, bool] | None = None):
        self.feedback.append(was_successful)
        self.feedback_needs.append(needs_check)
        if was_successful:
            self.node_history = []

    def get_ai_insight(self):
        return self.insight_data

    def get_history(self):
        return self._history

    def reset_all_data(self):
        self._history = []
        return True


@pytest.fixture(autouse=True)
def _patch_dependencies(monkeypatch):
    # Patch AI to avoid hitting the real model server
    async def fake_query_local_ai(text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Stress",
            "emotion_sublabel": "Overwhelmed",
            "confidence": 0.95,
            "reasoning": "test input",
        }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_local_ai)

    # Override the DB dependency with a fake in-memory implementation
    fake_db = _FakeDBManager()
    app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db

    yield fake_db

    app_main.app.dependency_overrides.clear()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app_main.app)


def test_analyze_endpoint(client: TestClient, _patch_dependencies: _FakeDBManager):
    response = client.post("/analyze", json={"user_text": "I feel stressed"})
    assert response.status_code == 200
    body = response.json()

    assert body["detected_node"] == "Stress"
    assert body["sublabel"] == "Overwhelmed"
    assert body["risk_level"] == "High"
    assert body["loop_detected"] is False


def test_history_endpoint(client: TestClient, _patch_dependencies: _FakeDBManager):
    response = client.get("/history")
    assert response.status_code == 200
    body = response.json()

    assert isinstance(body, list)
    assert body, "Expected at least one history item from fake DB manager"
    first = body[0]
    assert first["state"] == "Stress"
    assert first["was_successful"] is True


def test_request_id_header_added_to_responses(client: TestClient, _patch_dependencies: _FakeDBManager):
    response = client.get("/history")
    assert response.status_code == 200
    assert "X-Request-ID" in response.headers
    assert response.headers["X-Request-ID"]


def test_feedback_with_halt_results(client: TestClient, _patch_dependencies: _FakeDBManager):
    response = client.post(
        "/feedback",
        json={
            "success": True,
            "halt_results": {
                "hydration": True,
                "fuel": False,
                "rest": True,
                "movement": False,
            },
        },
    )
    assert response.status_code == 200
    assert response.json()["status"] == "recorded"
    assert _patch_dependencies.feedback[-1] is True
    assert _patch_dependencies.feedback_needs[-1] == {
        "hydration": True,
        "fuel": False,
        "rest": True,
        "movement": False,
    }


def test_feedback_with_needs_check_compatibility(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
):
    response = client.post(
        "/feedback",
        json={
            "success": False,
            "needs_check": {
                "hydration": False,
                "fuel": True,
                "rest": False,
                "movement": True,
            },
        },
    )
    assert response.status_code == 200
    assert response.json()["status"] == "recorded"
    assert _patch_dependencies.feedback[-1] is False
    assert _patch_dependencies.feedback_needs[-1] == {
        "hydration": False,
        "fuel": True,
        "rest": False,
        "movement": True,
    }


def test_insight_endpoint(client: TestClient, _patch_dependencies: _FakeDBManager):
    response = client.get("/insight")
    assert response.status_code == 200
    body = response.json()

    assert "message" in body
    assert body["top_loop"] == "Stress"
    assert body["success_rate"] == 66.67
    assert body["trend"] == "improving"
    assert body["streak"] == 3
    assert body["missing_need"] == "hydration"
    assert body["trigger_count"] == 2


def test_insight_fallback_when_db_error(client: TestClient, monkeypatch: pytest.MonkeyPatch):
    class BrokenDB:
        def get_ai_insight(self):
            raise RuntimeError("DB unavailable")

    app_main.app.dependency_overrides[app_main.get_db] = lambda: BrokenDB()
    try:
        response = client.get("/insight")
        assert response.status_code == 503
        body = response.json()
        assert "temporarily unavailable" in body["detail"]
    finally:
        app_main.app.dependency_overrides[app_main.get_db] = lambda: _patch_dependencies


def test_history_fallback_when_db_error(client: TestClient, monkeypatch: pytest.MonkeyPatch):
    class BrokenDB:
        def get_history(self):
            raise RuntimeError("DB error")

    app_main.app.dependency_overrides[app_main.get_db] = lambda: BrokenDB()
    try:
        response = client.get("/history")
        assert response.status_code == 503
        body = response.json()
        assert "temporarily unavailable" in body["detail"]
    finally:
        app_main.app.dependency_overrides[app_main.get_db] = lambda: _patch_dependencies


def test_reset_returns_503_when_db_unavailable(client: TestClient, monkeypatch: pytest.MonkeyPatch):
    class BrokenDB:
        def reset_all_data(self):
            return False

    app_main.app.dependency_overrides[app_main.get_db] = lambda: BrokenDB()
    try:
        response = client.delete("/reset", headers={"X-Confirm-Reset": "CONFIRM"})
        assert response.status_code == 503
    finally:
        app_main.app.dependency_overrides[app_main.get_db] = lambda: _patch_dependencies


def test_insight_trend_logic(client: TestClient, _patch_dependencies: _FakeDBManager):
    _patch_dependencies.insight_data = {
        "top_loop": "Stress",
        "count": 5,
        "success_rate": 85.0,
        "trend": "improving",
        "streak": 3,
    }

    response = client.get("/insight")
    assert response.status_code == 200
    body = response.json()

    assert body["trend"] == "improving"
    assert body["streak"] >= 0


def test_reset_endpoint(client: TestClient, _patch_dependencies: _FakeDBManager):
    response = client.delete("/reset", headers={"X-Confirm-Reset": "CONFIRM"})
    assert response.status_code == 200
    assert response.json()["status"] == "Database reset successful"


def test_reset_rejected_without_header(client: TestClient, _patch_dependencies: _FakeDBManager):
    response = client.delete("/reset")
    assert response.status_code == 400


def test_chronic_loop_detection(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
    monkeypatch: pytest.MonkeyPatch,
):
    async def low_granularity_stress(_text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Stress",
            "emotion_sublabel": "General",
            "confidence": 0.82,
            "reasoning": "stress persists",
        }

    monkeypatch.setattr(app_main, "query_local_ai", low_granularity_stress)

    first = client.post("/analyze", json={"user_text": "stressed once"}).json()
    second = client.post("/analyze", json={"user_text": "still stressed"}).json()
    third = client.post("/analyze", json={"user_text": "again stressed"}).json()

    assert first["risk_level"] == "Low"
    assert first["loop_detected"] is False

    assert second["risk_level"] == "Low"
    assert second["loop_detected"] is False

    assert third["risk_level"] == "High"
    assert third["loop_detected"] is True


def test_intervention_resets_loop(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
    monkeypatch: pytest.MonkeyPatch,
):
    async def low_granularity_stress(_text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Stress",
            "emotion_sublabel": "General",
            "confidence": 0.82,
            "reasoning": "stress persists",
        }

    monkeypatch.setattr(app_main, "query_local_ai", low_granularity_stress)

    client.post("/analyze", json={"user_text": "stressed once"})
    client.post("/analyze", json={"user_text": "still stressed"})
    before_reset = client.post("/analyze", json={"user_text": "again stressed"}).json()

    assert before_reset["risk_level"] == "High"
    assert before_reset["loop_detected"] is True

    feedback_response = client.post("/feedback", json={"success": True})
    assert feedback_response.status_code == 200

    after_reset = client.post("/analyze", json={"user_text": "fresh start"}).json()
    assert after_reset["risk_level"] == "Low"
    assert after_reset["loop_detected"] is False


# Q1.1.4 — Degraded DB behavior tests

def test_analyze_degraded_db(client: TestClient, monkeypatch: pytest.MonkeyPatch):
    """Test /analyze when DB is degraded (returns Low/False)."""

    class DegradedDBManager:
        def log_and_analyze(self, *args, **kwargs):
            # Degraded mode: return Low risk, no loop
            return ("Low", False)

        def cleanup_stale_interventions(self, *args, **kwargs):
            pass

        def resolve_intervention(self, *args, **kwargs):
            pass

    app_main.app.dependency_overrides[app_main.get_db] = lambda: DegradedDBManager()
    try:
        async def ai_response(_text: str, request_id: str = "") -> Dict[str, Any]:
            return {
                "detected_node": "Stress",
                "emotion_sublabel": "Anxious",
                "confidence": 0.8,
                "reasoning": "test",
            }

        monkeypatch.setattr(app_main, "query_local_ai", ai_response)

        response = client.post("/analyze", json={"user_text": "test"})
        assert response.status_code == 200
        body = response.json()
        # Degraded DB returns Low risk, no loop detected
        assert body["risk_level"] == "Low"
        assert body["loop_detected"] is False
    finally:
        del app_main.app.dependency_overrides[app_main.get_db]


def test_insight_when_get_ai_insight_returns_none(client: TestClient):
    """Test /insight when get_ai_insight returns None (degraded mode)."""

    class DegradedDBManager:
        def get_ai_insight(self):
            return None

    app_main.app.dependency_overrides[app_main.get_db] = lambda: DegradedDBManager()
    try:
        response = client.get("/insight")
        assert response.status_code == 200
        body = response.json()
        # Should return welcome message for empty/degraded state
        assert body["message"] == "Welcome! Start journaling to track your resilience."
        assert body["success_rate"] == 0
    finally:
        del app_main.app.dependency_overrides[app_main.get_db]


def test_history_empty_degraded(client: TestClient):
    """Test /history when get_history returns empty list (degraded mode)."""

    class DegradedDBManager:
        def get_history(self):
            return []

    app_main.app.dependency_overrides[app_main.get_db] = lambda: DegradedDBManager()
    try:
        response = client.get("/history")
        assert response.status_code == 200
        body = response.json()
        # /history returns a list directly
        assert body == []
    finally:
        del app_main.app.dependency_overrides[app_main.get_db]


def test_feedback_when_db_unavailable(client: TestClient):
    """Test /feedback when resolve_intervention is unavailable (no-op)."""

    class DegradedDBManager:
        def resolve_intervention(self, *args, **kwargs):
            # No-op, doesn't crash
            pass

    app_main.app.dependency_overrides[app_main.get_db] = lambda: DegradedDBManager()
    try:
        response = client.post("/feedback", json={"success": True})
        # Should still return 200 (feedback is fire-and-forget)
        assert response.status_code == 200
    finally:
        del app_main.app.dependency_overrides[app_main.get_db]
