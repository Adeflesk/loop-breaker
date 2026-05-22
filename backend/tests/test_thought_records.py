"""Unit tests for thought record (cognitive restructuring) functionality."""

from typing import Any, Dict

import pytest
from fastapi.testclient import TestClient

from app import main as app_main


class _FakeDBManager:
    def __init__(self):
        self.thought_records = []
        self.is_available = True

    def create_thought_record(
        self,
        situation: str,
        automatic_thought: str,
        evidence_for: str,
        evidence_against: str,
        balanced_thought: str,
        linked_node: str = None,
    ) -> bool:
        if not self.is_available:
            return False
        self.thought_records.append({
            "timestamp": "2026-05-02T12:00:00Z",
            "situation": situation,
            "automatic_thought": automatic_thought,
            "evidence_for": evidence_for,
            "evidence_against": evidence_against,
            "balanced_thought": balanced_thought,
            "linked_node": linked_node,
        })
        return True

    def get_thought_records(self, limit: int = 20, offset: int = 0) -> list:
        if not self.is_available:
            return []
        return self.thought_records[offset : offset + limit]

    def log_and_analyze(
        self, node_name: str, confidence: float, title: str, task: str, sublabel: str = "unspecified"
    ):
        return "Low", False

    def resolve_intervention(self, was_successful: bool, needs_check: Dict[str, bool] | None = None):
        pass

    def get_history(self):
        return []

    def reset_all_data(self):
        self.thought_records = []
        return True


@pytest.fixture(autouse=True)
def _patch_dependencies(monkeypatch):
    async def fake_query_local_ai(text: str, request_id: str = "") -> Dict[str, Any]:
        return {
            "detected_node": "Procrastination",
            "emotion_sublabel": "Avoidance",
            "confidence": 0.95,
            "reasoning": "avoidance detected",
        }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_local_ai)

    fake_db = _FakeDBManager()
    app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db

    yield fake_db

    app_main.app.dependency_overrides.clear()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app_main.app)


class TestThoughtRecordDB:
    """Tests for DB thought record methods."""

    def test_create_thought_record_success(self, _patch_dependencies: _FakeDBManager):
        """create_thought_record returns True on success."""
        result = _patch_dependencies.create_thought_record(
            situation="I avoided starting my project",
            automatic_thought="I will fail",
            evidence_for="I failed once before",
            evidence_against="I succeeded at similar tasks",
            balanced_thought="I can try and learn from this",
            linked_node="Procrastination",
        )
        assert result is True
        assert len(_patch_dependencies.thought_records) == 1

    def test_create_thought_record_unavailable(self, _patch_dependencies: _FakeDBManager):
        """create_thought_record returns False when DB unavailable."""
        _patch_dependencies.is_available = False
        result = _patch_dependencies.create_thought_record(
            situation="test", automatic_thought="test", evidence_for="test",
            evidence_against="test", balanced_thought="test",
        )
        assert result is False

    def test_get_thought_records_empty(self, _patch_dependencies: _FakeDBManager):
        """get_thought_records returns empty list when no records."""
        records = _patch_dependencies.get_thought_records()
        assert records == []

    def test_get_thought_records_with_data(self, _patch_dependencies: _FakeDBManager):
        """get_thought_records returns created records."""
        _patch_dependencies.create_thought_record(
            situation="Situation 1",
            automatic_thought="Thought 1",
            evidence_for="Evidence for 1",
            evidence_against="Evidence against 1",
            balanced_thought="Balanced 1",
            linked_node="Procrastination",
        )
        records = _patch_dependencies.get_thought_records()
        assert len(records) == 1
        assert records[0]["situation"] == "Situation 1"
        assert records[0]["linked_node"] == "Procrastination"

    def test_get_thought_records_pagination(self, _patch_dependencies: _FakeDBManager):
        """get_thought_records respects limit and offset."""
        for i in range(5):
            _patch_dependencies.create_thought_record(
                situation=f"Situation {i}",
                automatic_thought=f"Thought {i}",
                evidence_for=f"For {i}",
                evidence_against=f"Against {i}",
                balanced_thought=f"Balanced {i}",
            )

        # Get first 2
        records = _patch_dependencies.get_thought_records(limit=2, offset=0)
        assert len(records) == 2

        # Get next 2
        records = _patch_dependencies.get_thought_records(limit=2, offset=2)
        assert len(records) == 2

        # Get beyond available
        records = _patch_dependencies.get_thought_records(limit=10, offset=5)
        assert len(records) == 0

    def test_get_thought_records_unavailable(self, _patch_dependencies: _FakeDBManager):
        """get_thought_records returns empty list when DB unavailable."""
        _patch_dependencies.is_available = False
        records = _patch_dependencies.get_thought_records()
        assert records == []


class TestThoughtRecordAPI:
    """Tests for thought record endpoints."""

    def test_create_thought_record_endpoint(self, client: TestClient):
        """POST /thought-record creates a record and returns 201."""
        response = client.post(
            "/thought-record",
            json={
                "situation": "I avoided starting my work",
                "automatic_thought": "I will definitely fail",
                "evidence_for": "I failed once before",
                "evidence_against": "I succeeded at similar tasks 5 times",
                "balanced_thought": "I can try and learn from this attempt",
                "linked_node": "Procrastination",
            },
        )
        assert response.status_code == 201
        assert response.json()["status"] == "created"

    def test_create_thought_record_without_linked_node(self, client: TestClient):
        """POST /thought-record works without linked_node."""
        response = client.post(
            "/thought-record",
            json={
                "situation": "I felt anxious",
                "automatic_thought": "Something bad will happen",
                "evidence_for": "I'm not sure",
                "evidence_against": "Nothing bad happened last time",
                "balanced_thought": "I can handle this",
            },
        )
        assert response.status_code == 201

    def test_create_thought_record_validation_empty_field(self, client: TestClient):
        """POST /thought-record validates required fields."""
        response = client.post(
            "/thought-record",
            json={
                "situation": "",  # Empty
                "automatic_thought": "Test",
                "evidence_for": "Test",
                "evidence_against": "Test",
                "balanced_thought": "Test",
            },
        )
        assert response.status_code == 422  # Validation error

    def test_create_thought_record_validation_too_long(self, client: TestClient):
        """POST /thought-record rejects fields over 2000 chars."""
        long_text = "A" * 2001
        response = client.post(
            "/thought-record",
            json={
                "situation": long_text,
                "automatic_thought": "Test",
                "evidence_for": "Test",
                "evidence_against": "Test",
                "balanced_thought": "Test",
            },
        )
        assert response.status_code == 422

    def test_get_thought_records_endpoint(self, client: TestClient):
        """GET /thought-records returns list of records."""
        # Create a record first
        client.post(
            "/thought-record",
            json={
                "situation": "Test situation",
                "automatic_thought": "Test thought",
                "evidence_for": "Test for",
                "evidence_against": "Test against",
                "balanced_thought": "Test balanced",
            },
        )

        response = client.get("/thought-records")
        assert response.status_code == 200
        records = response.json()
        assert isinstance(records, list)
        assert len(records) > 0
        assert records[0]["situation"] == "Test situation"

    def test_get_thought_records_empty(self, client: TestClient):
        """GET /thought-records returns empty list when no records."""
        response = client.get("/thought-records")
        assert response.status_code == 200
        assert response.json() == []

    def test_get_thought_records_with_pagination(self, client: TestClient):
        """GET /thought-records respects limit and offset params."""
        # Create 3 records
        for i in range(3):
            client.post(
                "/thought-record",
                json={
                    "situation": f"Situation {i}",
                    "automatic_thought": f"Thought {i}",
                    "evidence_for": f"For {i}",
                    "evidence_against": f"Against {i}",
                    "balanced_thought": f"Balanced {i}",
                },
            )

        # Get with limit
        response = client.get("/thought-records?limit=2")
        assert response.status_code == 200
        records = response.json()
        assert len(records) == 2

        # Get with offset
        response = client.get("/thought-records?limit=2&offset=1")
        assert response.status_code == 200
        records = response.json()
        assert len(records) <= 2

    def test_thought_record_response_contract(self, client: TestClient):
        """GET /thought-records response matches ThoughtRecordResponse schema."""
        client.post(
            "/thought-record",
            json={
                "situation": "Test situation",
                "automatic_thought": "Test thought",
                "evidence_for": "Test for",
                "evidence_against": "Test against",
                "balanced_thought": "Test balanced",
                "linked_node": "Procrastination",
            },
        )

        response = client.get("/thought-records")
        assert response.status_code == 200
        records = response.json()
        record = records[0]

        # Verify all required fields are present
        assert "timestamp" in record
        assert "situation" in record
        assert "automatic_thought" in record
        assert "evidence_for" in record
        assert "evidence_against" in record
        assert "balanced_thought" in record
        assert "linked_node" in record


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
