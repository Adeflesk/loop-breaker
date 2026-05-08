from typing import Any, Dict, List, Optional

import pytest
from fastapi.testclient import TestClient

from app import main as app_main


class _FakeDBManager:
    """Mock database for journal endpoint testing."""

    def __init__(self) -> None:
        self.is_available = True
        self.saved_entries: List[Dict[str, Any]] = []
        self.outcomes: Dict[str, Dict[str, Any]] = {}

    def save_journal_entry(
        self,
        entry_id: str,
        raw_text: str,
        detected_state: str,
        sublabel: str,
        confidence: float,
        reasoning: str,
        risk_level: str,
        intervention_title: str,
        intervention_type: str,
    ) -> bool:
        """Mock: saves entry to in-memory list."""
        self.saved_entries.append({
            "id": entry_id,
            "timestamp": "2025-01-15T10:00:00",
            "raw_text": raw_text,
            "detected_state": detected_state,
            "sublabel": sublabel,
            "confidence": confidence,
            "reasoning": reasoning,
            "risk_level": risk_level,
            "intervention_title": intervention_title,
            "intervention_type": intervention_type,
            "user_outcome": None,
            "user_notes": None,
        })
        return True

    def get_journal_entries(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Mock: returns saved entries in reverse chronological order."""
        if not self.is_available:
            return []
        # Return in reverse order (most recent first)
        return self.saved_entries[:limit]

    def record_journal_outcome(
        self,
        entry_id: str,
        outcome: str,
        notes: Optional[str] = None,
    ) -> bool:
        """Mock: records outcome on an entry."""
        if not self.is_available:
            return False
        # Find entry and update it
        for entry in self.saved_entries:
            if entry["id"] == entry_id:
                entry["user_outcome"] = outcome
                entry["user_notes"] = notes or ""
                return True
        return False

    # Stub methods required by dependency injection
    def log_and_analyze(self, node_name, confidence, title="", task="", sublabel=None):
        return "Low", False

    def get_history(self):
        return []


@pytest.fixture(autouse=True)
def _patch_dependencies(monkeypatch):
    """Override DB dependency with fake implementation for all journal tests."""
    fake_db = _FakeDBManager()
    app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db

    yield fake_db

    app_main.app.dependency_overrides.clear()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app_main.app)


class TestGetJournalEntries:
    """Tests for GET /journal-entries endpoint."""

    def test_get_journal_entries_empty(self, client: TestClient, _patch_dependencies: _FakeDBManager):
        """Should return empty list when no entries exist."""
        response = client.get("/journal-entries")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 0

    def test_get_journal_entries_returns_saved(
        self, client: TestClient, _patch_dependencies: _FakeDBManager
    ):
        """Should return saved entries."""
        # Add an entry to the fake DB
        _patch_dependencies.save_journal_entry(
            entry_id="test-id-1",
            raw_text="I feel stressed",
            detected_state="Stress",
            sublabel="Overload",
            confidence=0.92,
            reasoning="time pressure detected",
            risk_level="High",
            intervention_title="Physiological Sigh",
            intervention_type="breathing",
        )

        response = client.get("/journal-entries")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["id"] == "test-id-1"
        assert data[0]["raw_text"] == "I feel stressed"
        assert data[0]["detected_state"] == "Stress"

    def test_get_journal_entries_respects_limit(
        self, client: TestClient, _patch_dependencies: _FakeDBManager
    ):
        """Should respect the limit query parameter."""
        # Add 5 entries
        for i in range(5):
            _patch_dependencies.save_journal_entry(
                entry_id=f"test-id-{i}",
                raw_text=f"Entry {i}",
                detected_state="Stress",
                sublabel="Overload",
                confidence=0.9,
                reasoning="test",
                risk_level="Low",
                intervention_title="Test",
                intervention_type="breathing",
            )

        # Request with limit=2
        response = client.get("/journal-entries?limit=2")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2

    def test_get_journal_entries_limit_validation(self, client: TestClient):
        """Should reject invalid limit values."""
        # limit=0 should be rejected (minimum is 1)
        response = client.get("/journal-entries?limit=0")
        assert response.status_code == 422

        # limit=1000 should be rejected (maximum is 500)
        response = client.get("/journal-entries?limit=1000")
        assert response.status_code == 422

    def test_get_journal_entries_db_unavailable(
        self, client: TestClient, _patch_dependencies: _FakeDBManager
    ):
        """Should return empty list when DB is unavailable."""
        _patch_dependencies.is_available = False
        response = client.get("/journal-entries")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 0


class TestRecordJournalOutcome:
    """Tests for PATCH /journal-entries/{entry_id}/outcome endpoint."""

    def test_record_journal_outcome_success(
        self, client: TestClient, _patch_dependencies: _FakeDBManager
    ):
        """Should record a 'helped' outcome."""
        # Add an entry first
        _patch_dependencies.save_journal_entry(
            entry_id="test-id-1",
            raw_text="I feel stressed",
            detected_state="Stress",
            sublabel="Overload",
            confidence=0.92,
            reasoning="test",
            risk_level="Low",
            intervention_title="Physiological Sigh",
            intervention_type="breathing",
        )

        response = client.patch(
            "/journal-entries/test-id-1/outcome",
            json={"outcome": "helped", "notes": "Felt better after breathing"},
        )
        assert response.status_code == 200
        assert response.json() == {"status": "recorded"}

        # Verify the outcome was recorded
        entry = _patch_dependencies.saved_entries[0]
        assert entry["user_outcome"] == "helped"
        assert entry["user_notes"] == "Felt better after breathing"

    def test_record_journal_outcome_didnt_help(
        self, client: TestClient, _patch_dependencies: _FakeDBManager
    ):
        """Should record a 'didn't help' outcome."""
        _patch_dependencies.save_journal_entry(
            entry_id="test-id-1",
            raw_text="I feel anxious",
            detected_state="Anxiety",
            sublabel="Worry",
            confidence=0.85,
            reasoning="test",
            risk_level="Low",
            intervention_title="Grounding",
            intervention_type="grounding",
        )

        response = client.patch(
            "/journal-entries/test-id-1/outcome",
            json={"outcome": "didn't help"},
        )
        assert response.status_code == 200
        entry = _patch_dependencies.saved_entries[0]
        assert entry["user_outcome"] == "didn't help"

    def test_record_journal_outcome_neutral(
        self, client: TestClient, _patch_dependencies: _FakeDBManager
    ):
        """Should record a 'neutral' outcome."""
        _patch_dependencies.save_journal_entry(
            entry_id="test-id-1",
            raw_text="I feel stuck",
            detected_state="Procrastination",
            sublabel="Avoidance",
            confidence=0.88,
            reasoning="test",
            risk_level="Low",
            intervention_title="5-Minute Sprint",
            intervention_type="cognitive",
        )

        response = client.patch(
            "/journal-entries/test-id-1/outcome",
            json={"outcome": "neutral", "notes": "No change"},
        )
        assert response.status_code == 200
        entry = _patch_dependencies.saved_entries[0]
        assert entry["user_outcome"] == "neutral"
        assert entry["user_notes"] == "No change"

    def test_record_journal_outcome_invalid_value(self, client: TestClient):
        """Should reject invalid outcome values."""
        response = client.patch(
            "/journal-entries/test-id-1/outcome",
            json={"outcome": "maybe"},  # Invalid outcome
        )
        assert response.status_code == 422
        error = response.json()
        assert "outcome must be" in error["detail"]

    def test_record_journal_outcome_optional_notes(
        self, client: TestClient, _patch_dependencies: _FakeDBManager
    ):
        """Should allow recording outcome without notes."""
        _patch_dependencies.save_journal_entry(
            entry_id="test-id-1",
            raw_text="test",
            detected_state="Stress",
            sublabel="Overload",
            confidence=0.9,
            reasoning="test",
            risk_level="Low",
            intervention_title="Test",
            intervention_type="breathing",
        )

        response = client.patch(
            "/journal-entries/test-id-1/outcome",
            json={"outcome": "helped"},  # No notes field
        )
        assert response.status_code == 200
        entry = _patch_dependencies.saved_entries[0]
        assert entry["user_outcome"] == "helped"
        assert entry["user_notes"] == ""

    def test_record_journal_outcome_db_unavailable(
        self, client: TestClient, _patch_dependencies: _FakeDBManager
    ):
        """Should handle DB unavailability gracefully."""
        _patch_dependencies.is_available = False
        response = client.patch(
            "/journal-entries/test-id-1/outcome",
            json={"outcome": "helped"},
        )
        # Should return error (DB unavailable)
        assert response.status_code == 503
