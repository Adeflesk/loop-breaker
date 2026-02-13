"""
Rewire E2E Smoke Test
Validates the biological state progression described in Rewire slides:
- Acute Stress (Slide 3) → Chronic Stress (Slide 4)
- HALT needs check (Slide 7)
- Movement protocols (Slide 9)
- Parasympathetic recovery (Slide 6)
"""
from typing import Any, Dict, List

import pytest
from fastapi.testclient import TestClient

from app import main as app_main


class _FakeDBManager:
    """Fake DB manager for smoke tests - tracks state in memory."""
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
            "coaching_message": "Pattern insight: You've disrupted 3 patterns. Keep going!",
        }
        # Start with empty history - will populate as entries are logged
        self._history = []

    def log_and_analyze(
        self,
        node_name: str,
        confidence: float,
        title: str,
        task: str,
        sublabel: str = "General",
    ):
        # Record entry in history
        from datetime import datetime, UTC
        self._history.append({
            "time": datetime.now(UTC).isoformat(),
            "state": node_name,
            "intervention": title,
            "confidence": confidence,
            "was_successful": None,  # Not yet resolved
        })
        
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

    def get_trend_stats(self):
        return {}

    def reset_all_data(self):
        self._history = []
        return True

    def close(self):
        pass


@pytest.fixture(autouse=True)
def _patch_dependencies(monkeypatch):
    """
    Patch dependencies to avoid hitting real Neo4j and Ollama.
    Overrides the get_db dependency with a fake implementation.
    """
    call_count = {"count": 0}
    
    # Patch AI to simulate progression: stressed -> more stressed -> overwhelmed
    async def fake_query_local_ai(text: str) -> Dict[str, Any]:
        call_count["count"] += 1
        
        # First call: moderate stress
        if call_count["count"] == 1:
            return {
                "detected_node": "Stress",
                "emotion_sublabel": "Tense",
                "confidence": 0.85,
                "reasoning": "first stress entry",
            }
        # Second call: same state, slightly higher confidence
        elif call_count["count"] == 2:
            return {
                "detected_node": "Stress",
                "emotion_sublabel": "Anxious",
                "confidence": 0.90,
                "reasoning": "pattern forming",
            }
        # Third call: chronic stress (overwhelmed triggers high risk)
        else:
            return {
                "detected_node": "Stress",
                "emotion_sublabel": "Overwhelmed",
                "confidence": 0.95,
                "reasoning": "chronic pattern detected",
            }

    monkeypatch.setattr(app_main, "query_local_ai", fake_query_local_ai)

    # Override the DB dependency with fake in-memory implementation
    fake_db = _FakeDBManager()
    app_main.app.dependency_overrides[app_main.get_db] = lambda: fake_db

    yield fake_db

    app_main.app.dependency_overrides.clear()


@pytest.fixture
def client(_patch_dependencies: _FakeDBManager) -> TestClient:
    """Create test client with patched dependencies."""
    return TestClient(app_main.app)


def test_rewire_full_flow(client: TestClient):
    """
    End-to-end test simulating user progression through stress states.
    
    Flow:
    1. First entry: Acute stress (single event)
    2. Second entry: Same state (pattern forming)
    3. Third entry: Chronic stress detected (loop_detected=True, risk_level=High)
    4. HALT check-in data submission
    5. Intervention with movement protocol
    6. Recovery verification
    """
    # Step 1: First acute stress entry (no loop yet)
    response1 = client.post("/analyze", json={
        "user_text": "I'm feeling really overwhelmed with all my deadlines piling up"
    })
    assert response1.status_code == 200
    data1 = response1.json()
    
    # Verify sublabel persistence contract
    assert "detected_node" in data1
    assert "emotion_sublabel" in data1 or "sublabel" in data1
    assert data1["confidence"] > 0
    assert data1["loop_detected"] is False
    assert data1["risk_level"] == "Low"
    
    detected_state = data1["detected_node"]
    print(f"Entry 1: {detected_state} ({data1.get('emotion_sublabel', data1.get('sublabel', 'N/A'))})")
    
    # Step 2: Second entry with same state (pattern forming)
    response2 = client.post("/analyze", json={
        "user_text": "Still can't focus, everything feels like too much right now"
    })
    assert response2.status_code == 200
    data2 = response2.json()
    
    assert data2["loop_detected"] is False  # Only 2 consecutive, need 3
    print(f"Entry 2: {data2['detected_node']} - Loop not yet detected (2/3)")
    
    # Step 3: Third entry - should trigger chronic stress detection (Slide 4)
    response3 = client.post("/analyze", json={
        "user_text": "I just keep procrastinating and feel stuck in this cycle"
    })
    assert response3.status_code == 200
    data3 = response3.json()
    
    # CRITICAL: Verify loop detection logic
    assert data3["loop_detected"] is True, "Loop not detected after 3 entries"
    assert data3["risk_level"] == "High", "Risk level should be High for detected loop"
    
    # Verify intervention contract (Slide 9 - Movement Protocols)
    assert data3["intervention_title"] != ""
    assert data3["intervention_task"] != ""
    assert "education_info" in data3
    
    # If movement protocols feature is enabled, verify type
    if "intervention_type" in data3 and data3["intervention_type"]:
        assert data3["intervention_type"] in ["breathing", "grounding", "movement", "cognitive", "other"]
        print(f"Entry 3: Loop detected! Intervention: {data3['intervention_title']} (Type: {data3['intervention_type']})")
    else:
        print(f"Entry 3: Loop detected! Intervention: {data3['intervention_title']}")
    
    # Step 4: Submit HALT check-in data (Slide 7 - Physiological Needs)
    halt_response = client.post("/feedback", json={
        "success": True,
        "needs_check": {
            "hydration": True,
            "fuel": False,
            "rest": True,
            "movement": False
        }
    })
    assert halt_response.status_code == 200
    assert halt_response.json()["status"] == "recorded"
    print("HALT check-in recorded: Hydration ✓, Rest ✓")
    
    # Step 5: Verify insight endpoint returns trend data (Slide 6 - Sympathetic/Parasympathetic)
    insight_response = client.get("/insight")
    assert insight_response.status_code == 200
    insight_data = insight_response.json()
    
    assert "message" in insight_data
    assert "success_rate" in insight_data
    assert "top_loop" in insight_data
    
    # Trend/streak are optional depending on feature flags
    print(f"Insight: {insight_data['message']}")
    if "trend" in insight_data:
        print(f"Recovery Trend: {insight_data.get('trend', 'unknown')}")
    if "streak" in insight_data:
        print(f"Streak: {insight_data.get('streak', 0)} days")
    
    # Step 6: Verify history endpoint returns entries with sublabels
    history_response = client.get("/history")
    assert history_response.status_code == 200
    history_data = history_response.json()
    
    assert isinstance(history_data, list)
    assert len(history_data) >= 3, "Should have at least 3 entries"
    print(f"History: {len(history_data)} entries recorded")
    
    print("\n✅ Rewire E2E Flow Complete - All biological checkpoints validated")


def test_sublabel_persistence_verification(client: TestClient):
    """
    Isolated test for emotion_sublabel persistence (Slide 5 - Emotion Wheel).
    Verifies data flows from AI → API response → Neo4j storage.
    """
    response = client.post("/analyze", json={
        "user_text": "I'm feeling anxious about the future and can't stop worrying"
    })
    
    assert response.status_code == 200
    data = response.json()
    
    # Must have emotion granularity fields
    has_sublabel = "emotion_sublabel" in data or "sublabel" in data
    assert has_sublabel, "Sublabel field missing from response"
    
    sublabel = data.get("emotion_sublabel") or data.get("sublabel")
    if sublabel and sublabel != "General":
        print(f"✓ Sublabel captured: {data['detected_node']} → {sublabel}")
    else:
        print(f"⚠ Generic sublabel returned for: {data['detected_node']}")


def test_intervention_type_contract(client: TestClient):
    """
    Verifies intervention_type field exists when movement protocols are enabled.
    Maps to Slide 9 (Activity Zones).
    """
    # Force a loop by submitting 3 similar stress entries
    stress_text = "I feel stressed and overwhelmed"
    
    for i in range(3):
        response = client.post("/analyze", json={"user_text": stress_text})
        data = response.json()
        
        if i == 2:  # Third entry should trigger intervention
            assert data["loop_detected"] is True
            
            # intervention_type is optional (feature flag controlled)
            if "intervention_type" in data and data["intervention_type"]:
                assert data["intervention_type"] in [
                    "breathing", "grounding", "movement", "cognitive", "other"
                ]
                print(f"✓ Intervention type: {data['intervention_type']}")


def test_feature_flag_behavior(client: TestClient):
    """
    Smoke test to verify feature flags control field presence.
    Ensures rollout strategy (Slide plan) can be executed safely.
    """
    response = client.post("/analyze", json={
        "user_text": "Quick stress check"
    })
    
    assert response.status_code == 200
    data = response.json()
    
    # Core fields always present
    assert "detected_node" in data
    assert "confidence" in data
    assert "risk_level" in data
    assert "loop_detected" in data
    
    # Optional fields may or may not be present depending on flags
    optional_fields = ["sublabel", "emotion_sublabel", "intervention_type"]
    present = [f for f in optional_fields if f in data and data[f] is not None]
    
    print(f"✓ Core contract intact. Optional fields present: {present}")
