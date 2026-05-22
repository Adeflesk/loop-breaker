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

    def __enter__(self) -> "_FakeSession":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
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
        self.node_history: List[str] = []

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
        return "Low", False

    def resolve_intervention(self, was_successful: bool, needs_check: Dict[str, bool] | None = None):
        pass

    def get_ai_insight(self):
        return {}

    def get_history(self):
        return []

    def save_journal_entry(self, **kwargs):
        pass

    def increment_intervention_seen_count(self, title: str):
        pass

    def close(self):
        pass


@pytest.fixture(autouse=True)
def _patch_dependencies(monkeypatch):
    # Patch AI to avoid hitting the real model server
    async def fake_query_local_ai(text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Stress",
            "emotion_sublabel": "General",
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


def test_movement_protocol_included_when_flag_enabled(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
    monkeypatch: pytest.MonkeyPatch,
):
    """Test that movement_protocol is included in response when FEATURE_MOVEMENT_PROTOCOLS=true."""
    monkeypatch.setattr(app_main, "FEATURE_MOVEMENT_PROTOCOLS", True)

    response = client.post("/analyze", json={"user_text": "I feel stressed"})
    assert response.status_code == 200
    body = response.json()

    assert body["detected_node"] == "Stress"
    assert body["movement_protocol"] is not None
    assert body["movement_protocol"]["title"] == "Cortisol Discharge Walk"
    assert "task" in body["movement_protocol"]
    assert "education" in body["movement_protocol"]
    assert body["movement_protocol"]["type"] == "movement"


def test_movement_protocol_excluded_when_flag_disabled(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
    monkeypatch: pytest.MonkeyPatch,
):
    """Test that movement_protocol is null when FEATURE_MOVEMENT_PROTOCOLS=false."""
    monkeypatch.setattr(app_main, "FEATURE_MOVEMENT_PROTOCOLS", False)

    response = client.post("/analyze", json={"user_text": "I feel stressed"})
    assert response.status_code == 200
    body = response.json()

    assert body["detected_node"] == "Stress"
    assert body["movement_protocol"] is None


def test_restlessness_arc_position_correct(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
    monkeypatch: pytest.MonkeyPatch,
):
    """Test that Restlessness has correct arc position (6)."""
    async def fake_query_restlessness(text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Restlessness",
            "emotion_sublabel": "General",
            "confidence": 0.85,
            "reasoning": "test restlessness",
        }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_restlessness)

    response = client.post("/analyze", json={"user_text": "I feel restless"})
    assert response.status_code == 200
    body = response.json()

    assert body["detected_node"] == "Restlessness"
    assert body["node_arc_position"] == 6
    assert "Trapped Activation" in body["node_arc_label"]


def test_state_without_movement_returns_none(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
    monkeypatch: pytest.MonkeyPatch,
):
    """Test that states without movement protocol (e.g. Shame) return None even when flag is on."""
    async def fake_query_shame(text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Shame",
            "emotion_sublabel": "General",
            "confidence": 0.9,
            "reasoning": "test shame",
        }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_shame)
    monkeypatch.setattr(app_main, "FEATURE_MOVEMENT_PROTOCOLS", True)

    response = client.post("/analyze", json={"user_text": "I feel ashamed"})
    assert response.status_code == 200
    body = response.json()

    assert body["detected_node"] == "Shame"
    assert body["movement_protocol"] is None


def test_anxiety_movement_protocol_with_flag(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
    monkeypatch: pytest.MonkeyPatch,
):
    """Test that Anxiety includes movement protocol when flag is enabled."""
    async def fake_query_anxiety(text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Anxiety",
            "emotion_sublabel": "General",
            "confidence": 0.88,
            "reasoning": "test anxiety",
        }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_anxiety)
    monkeypatch.setattr(app_main, "FEATURE_MOVEMENT_PROTOCOLS", True)

    response = client.post("/analyze", json={"user_text": "I feel anxious"})
    assert response.status_code == 200
    body = response.json()

    assert body["detected_node"] == "Anxiety"
    assert body["movement_protocol"] is not None
    assert body["movement_protocol"]["title"] == "Vigorous Physical Discharge"
    assert body["movement_protocol"]["type"] == "movement"


def test_procrastination_movement_protocol(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
    monkeypatch: pytest.MonkeyPatch,
):
    """Test that Procrastination includes movement protocol when flag is enabled."""
    async def fake_query_procrastination(text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Procrastination",
            "emotion_sublabel": "General",
            "confidence": 0.92,
            "reasoning": "test procrastination",
        }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_procrastination)
    monkeypatch.setattr(app_main, "FEATURE_MOVEMENT_PROTOCOLS", True)

    response = client.post("/analyze", json={"user_text": "I'm procrastinating"})
    assert response.status_code == 200
    body = response.json()

    assert body["detected_node"] == "Procrastination"
    assert body["movement_protocol"] is not None
    assert body["movement_protocol"]["title"] == "2-Minute Body Break"
    assert body["movement_protocol"]["type"] == "movement"


def test_overwhelm_movement_protocol(
    client: TestClient,
    _patch_dependencies: _FakeDBManager,
    monkeypatch: pytest.MonkeyPatch,
):
    """Test that Overwhelm includes movement protocol when flag is enabled."""
    async def fake_query_overwhelm(text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Overwhelm",
            "emotion_sublabel": "General",
            "confidence": 0.87,
            "reasoning": "test overwhelm",
        }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_overwhelm)
    monkeypatch.setattr(app_main, "FEATURE_MOVEMENT_PROTOCOLS", True)

    response = client.post("/analyze", json={"user_text": "I feel overwhelmed"})
    assert response.status_code == 200
    body = response.json()

    assert body["detected_node"] == "Overwhelm"
    assert body["movement_protocol"] is not None
    assert body["movement_protocol"]["title"] == "Tension Release Shake"
    assert body["movement_protocol"]["type"] == "movement"
