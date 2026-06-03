# Intervention Guidance & Alternatives — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Show full guidance" step-by-step toggle and a "This isn't helping" alternative-cycling button to the intervention dialog, backed by two new Shame catalog entries grounded in the Rewire (Nicole Vignola) framework.

**Architecture:** Two independent parallel streams — BACKEND adds `alternatives` field to the `/analyze` response and two new Shame catalog entries; FRONTEND adds `StatefulBuilder`-based step toggle and alternatives-driven card swap to `_showStandardInterventionDialog`. The two streams share only the JSON contract (`msc_steps` already in model; `alternatives` is new). Both streams use mocks so they can run in parallel worktrees without a live backend.

**Tech Stack:** Python/FastAPI/Pydantic (backend), Flutter/Dart/flutter_test/MockClient (frontend).

**Spec:** `/Users/adriancorsini/Development/loop-breaker/docs/superpowers/specs/2026-06-02-intervention-guidance-and-alternatives-design.md`

---

## File Map

### Backend (working dir: `/Users/adriancorsini/Development/loop-breaker/backend`)

| File | Action | Responsibility |
|------|--------|----------------|
| `app/interventions.py` | Modify | Add `alternatives` list to Shame entry; add 2 new alternative dicts |
| `app/models.py` | Modify | Add `AlternativeIntervention` Pydantic model; add `alternatives` field to `AnalysisResponse` |
| `app/main.py` | Modify | Add `get_alternatives()` helper; remove `FEATURE_SHAME_PROTOCOL` gate from `msc_steps`; populate `alternatives` in response |
| `tests/test_intervention_guidance.py` | Create | Unit tests for `get_alternatives()`; integration tests for new response fields |

### Frontend (working dir: `/Users/adriancorsini/Development/loop-breaker/frontend`)

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/screens/journal_screen.dart` | Modify | Add `_alternativeIndex` state field; refactor `_showStandardInterventionDialog` to use `StatefulBuilder` for step toggle; drive "This isn't helping" from `data['alternatives']` |
| `test/screens/journal_screen_guidance_test.dart` | Create | Widget tests for step toggle and alternative cycling |

---

## BACKEND STREAM

### Task B1: Add Shame alternatives to catalog

**Files:**
- Modify: `app/interventions.py`

- [ ] **Step B1.1: Add `alternatives` key to the Shame entry in INTERVENTIONS**

Open `app/interventions.py`. Find the `"Shame"` dict (currently at the top level of `INTERVENTIONS`, after `"Overwhelm"`). Add an `"alternatives"` key containing two dicts:

```python
    "Shame": {
        "title": "Mindful Self-Compassion",
        "task": "Take a breath. Notice what you're feeling without judgment.",
        "education": {
            "introduce": "Shame thrives in secrecy and isolation. Shame says 'I am bad.' It's the most painful emotion because it attacks your identity, not just your behavior.",
            "reinforce": "The Mindful Self-Compassion protocol—Mindfulness, Common Humanity, Self-Kindness—interrupts the shame spiral. Each component targets a different neural pathway of self-criticism.",
            "deepen": "Shame activates your dorsomedial prefrontal cortex (self-referential processing) and suppresses your insula (interoceptive awareness). MSC re-engages your insula (feeling), reconnecting you to your body as evidence that you're still human, still worthy."
        },
        "type": "cognitive",
        "msc_steps": [
            # ... existing steps unchanged ...
        ],
        "alternatives": [
            {
                "title": "Cognitive Reframe",
                "task": "Notice the thought that's running ('I am bad', 'I'm broken', 'I'm not enough'). Write it down. Now rewrite it: 'I made a mistake. My brain can adapt and I can learn from this.'",
                "education": "Shame activates your negativity bias — your brain amplifies self-critical signals by default. Cognitive reframing reprograms the loop: each time you catch the thought and replace it, you weaken the shame circuit and strengthen the growth circuit (Rewire — Vignola).",
                "type": "cognitive"
            },
            {
                "title": "Zone 2 Walk",
                "task": "Walk at a comfortable pace for 5–10 minutes — slow enough that you could hold a conversation. No phone, no destination. Let your body lead.",
                "education": "Shame creates a freeze response. Zone 2 activity sends direct muscle-to-brain signals that shift your nervous system out of threat mode without overwhelming it. Your muscles communicate directly with your brain (Rewire — Vignola, muscle-brain chapter).",
                "type": "movement"
            },
        ],
    },
```

The complete replacement for the `"Shame"` entry (replacing everything from `"Shame": {` to its closing `},`) is:

```python
    "Shame": {
        "title": "Mindful Self-Compassion",
        "task": "Take a breath. Notice what you're feeling without judgment.",
        "education": {
            "introduce": "Shame thrives in secrecy and isolation. Shame says 'I am bad.' It's the most painful emotion because it attacks your identity, not just your behavior.",
            "reinforce": "The Mindful Self-Compassion protocol—Mindfulness, Common Humanity, Self-Kindness—interrupts the shame spiral. Each component targets a different neural pathway of self-criticism.",
            "deepen": "Shame activates your dorsomedial prefrontal cortex (self-referential processing) and suppresses your insula (interoceptive awareness). MSC re-engages your insula (feeling), reconnecting you to your body as evidence that you're still human, still worthy."
        },
        "type": "cognitive",
        "msc_steps": [
            {
                "step": 1,
                "name": "Mindfulness",
                "task": "Place a hand on your heart. Say: 'This is a moment of suffering. I notice this feeling without judgment.'",
                "education": {
                    "introduce": "Mindfulness means noticing what you feel without immediately judging or rejecting it.",
                    "reinforce": "Shame often involves self-rejection. Acknowledgment ('I notice I feel ashamed') breaks the rejection loop and creates psychological distance.",
                    "deepen": "Mindfulness engages your default mode network in observation mode, not rumination. The physical anchor (hand on heart) activates your somatosensory cortex, grounding awareness in the body rather than abstract self-judgment."
                }
            },
            {
                "step": 2,
                "name": "Common Humanity",
                "task": "Think of someone else who has felt exactly this way. Say: 'Suffering is part of being human. I am not alone in this.'",
                "education": {
                    "introduce": "Shame says 'only I feel this; I'm uniquely broken.' Common humanity is proof that suffering is universal—you're not alone.",
                    "reinforce": "Isolation amplifies shame; connection dissolves it. Recognizing shared human experience weakens the 'I'm uniquely bad' narrative.",
                    "deepen": "Common humanity activates your mentalizing network (understanding others' minds), which automatically extends compassion back to yourself. Your brain's mirror neurons sync with the person's suffering, creating empathic resonance instead of self-isolation."
                }
            },
            {
                "step": 3,
                "name": "Self-Kindness",
                "task": "Ask: 'What would I say to a dear friend who felt this way right now?' Say those exact words to yourself.",
                "education": {
                    "introduce": "Self-kindness replaces harsh self-judgment with warmth. Most people are kinder to strangers than to themselves.",
                    "reinforce": "Shame uses your inner critic as a weapon. Self-kindness disarms it by redirecting the same energy toward healing instead of punishment.",
                    "deepen": "Self-kindness activates your ventromedial prefrontal cortex and nucleus accumbens (reward/soothing), releasing oxytocin. This literally shifts your nervous system from threat-detection to social safety, the only state where growth is possible."
                }
            },
        ],
        "alternatives": [
            {
                "title": "Cognitive Reframe",
                "task": "Notice the thought that's running ('I am bad', 'I'm broken', 'I'm not enough'). Write it down. Now rewrite it: 'I made a mistake. My brain can adapt and I can learn from this.'",
                "education": "Shame activates your negativity bias — your brain amplifies self-critical signals by default. Cognitive reframing reprograms the loop: each time you catch the thought and replace it, you weaken the shame circuit and strengthen the growth circuit (Rewire — Vignola).",
                "type": "cognitive"
            },
            {
                "title": "Zone 2 Walk",
                "task": "Walk at a comfortable pace for 5–10 minutes — slow enough that you could hold a conversation. No phone, no destination. Let your body lead.",
                "education": "Shame creates a freeze response. Zone 2 activity sends direct muscle-to-brain signals that shift your nervous system out of threat mode without overwhelming it. Your muscles communicate directly with your brain (Rewire — Vignola, muscle-brain chapter).",
                "type": "movement"
            },
        ],
    },
```

- [ ] **Step B1.2: Verify file syntax**

```bash
cd /Users/adriancorsini/Development/loop-breaker/backend
python -c "from app.interventions import INTERVENTIONS; shame = INTERVENTIONS['Shame']; print(len(shame['alternatives']), 'alternatives'); print(len(shame['msc_steps']), 'msc_steps')"
```

Expected output:
```
2 alternatives
3 msc_steps
```

- [ ] **Step B1.3: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add backend/app/interventions.py
git commit -m "feat: add Cognitive Reframe and Zone 2 Walk alternatives to Shame catalog"
```

---

### Task B2: Add `AlternativeIntervention` model and `alternatives` field to response

**Files:**
- Modify: `app/models.py`

- [ ] **Step B2.1: Write the failing test (model validation)**

Create `tests/test_intervention_guidance.py`:

```python
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
```

- [ ] **Step B2.2: Run test — expect ImportError**

```bash
cd /Users/adriancorsini/Development/loop-breaker/backend
python -m pytest tests/test_intervention_guidance.py::TestAlternativeInterventionModel -v
```

Expected: FAIL with `ImportError: cannot import name 'AlternativeIntervention'`

- [ ] **Step B2.3: Add `AlternativeIntervention` model and `alternatives` field**

In `app/models.py`, add after the `MscStep` class (around line 28):

```python
class AlternativeIntervention(BaseModel):
    """A fallback intervention offered when the primary isn't helping."""
    title: str
    task: str
    education: str
    type: str
```

Then in `AnalysisResponse`, add after `msc_steps`:

```python
    alternatives: Optional[List[AlternativeIntervention]] = None
```

Also add `AlternativeIntervention` to the imports block at the top of `app/main.py` (you will do this in Task B3 — just note it here).

- [ ] **Step B2.4: Run tests — expect PASS**

```bash
cd /Users/adriancorsini/Development/loop-breaker/backend
python -m pytest tests/test_intervention_guidance.py::TestAlternativeInterventionModel -v
```

Expected: 3 PASSED

- [ ] **Step B2.5: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add backend/app/models.py backend/tests/test_intervention_guidance.py
git commit -m "feat: add AlternativeIntervention model and alternatives field to AnalysisResponse"
```

---

### Task B3: Add `get_alternatives()` and wire into `/analyze`

**Files:**
- Modify: `app/main.py`

- [ ] **Step B3.1: Write failing integration tests**

Append to `tests/test_intervention_guidance.py`:

```python
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient
from app import main as app_main


def _make_fake_db():
    """Returns a minimal fake BehavioralStateManager for /analyze tests."""
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
        app_main.app.state.db = _make_fake_db()
        app_main.app.state.crisis_service = MagicMock()
        app_main.app.state.crisis_service.detect_crisis.return_value = (False, [])
        self.client = TestClient(app_main.app)

    @patch("app.main.query_local_ai")
    def test_shame_response_includes_alternatives(self, mock_ai):
        mock_ai.return_value = {
            "node": "Shame",
            "emotion_sublabel": None,
            "confidence": 0.85,
            "reasoning": "User expressed shame",
            "risk_level": "medium",
            "loop_detected": False,
        }
        response = self.client.post("/analyze", json={"user_text": "I feel so ashamed of myself"})
        assert response.status_code == 200
        data = response.json()
        assert "alternatives" in data
        assert data["alternatives"] is not None
        assert len(data["alternatives"]) == 2
        assert data["alternatives"][0]["title"] == "Cognitive Reframe"
        assert data["alternatives"][1]["title"] == "Zone 2 Walk"

    @patch("app.main.query_local_ai")
    def test_shame_response_includes_msc_steps(self, mock_ai):
        mock_ai.return_value = {
            "node": "Shame",
            "emotion_sublabel": None,
            "confidence": 0.85,
            "reasoning": "User expressed shame",
            "risk_level": "medium",
            "loop_detected": False,
        }
        response = self.client.post("/analyze", json={"user_text": "I feel so ashamed of myself"})
        assert response.status_code == 200
        data = response.json()
        assert "msc_steps" in data
        assert data["msc_steps"] is not None
        assert len(data["msc_steps"]) == 3
        assert data["msc_steps"][0]["name"] == "Mindfulness"

    @patch("app.main.query_local_ai")
    def test_non_shame_response_has_null_alternatives(self, mock_ai):
        mock_ai.return_value = {
            "node": "Numbness",
            "emotion_sublabel": None,
            "confidence": 0.75,
            "reasoning": "User feels numb",
            "risk_level": "medium",
            "loop_detected": False,
        }
        response = self.client.post("/analyze", json={"user_text": "I feel completely numb"})
        assert response.status_code == 200
        data = response.json()
        # Numbness has no alternatives in catalog
        assert data.get("alternatives") is None or data.get("alternatives") == []

    @patch("app.main.query_local_ai")
    def test_non_shame_response_has_null_msc_steps(self, mock_ai):
        mock_ai.return_value = {
            "node": "Stress",
            "emotion_sublabel": None,
            "confidence": 0.8,
            "reasoning": "User is stressed",
            "risk_level": "low",
            "loop_detected": False,
        }
        response = self.client.post("/analyze", json={"user_text": "I am so stressed"})
        assert response.status_code == 200
        data = response.json()
        assert data.get("msc_steps") is None
```

- [ ] **Step B3.2: Run tests — expect ImportError on `get_alternatives`**

```bash
cd /Users/adriancorsini/Development/loop-breaker/backend
python -m pytest tests/test_intervention_guidance.py::TestGetAlternatives -v
```

Expected: FAIL with `ImportError: cannot import name 'get_alternatives' from 'app.main'`

- [ ] **Step B3.3: Add `get_alternatives()` helper to `main.py`**

In `app/main.py`, add the import at the top with other model imports:

```python
from .models import (
    AlternativeIntervention,   # <-- add this
    AnalysisRequest,
    ...
)
```

Add this function just before the `/analyze` endpoint definition (search for `@app.post("/analyze"`):

```python
def get_alternatives(state: str, sublabel: str | None) -> list[dict]:
    """Return up to 2 fallback interventions for the given state from the catalog."""
    state_entry = INTERVENTIONS.get(state)
    if not state_entry:
        return []
    # States with a flat dict (Shame, Numbness, etc.) may carry an 'alternatives' key
    if isinstance(state_entry, dict) and "alternatives" in state_entry:
        return list(state_entry["alternatives"])[:2]
    return []
```

- [ ] **Step B3.4: Run `get_alternatives` unit tests — expect PASS**

```bash
cd /Users/adriancorsini/Development/loop-breaker/backend
python -m pytest tests/test_intervention_guidance.py::TestGetAlternatives -v
```

Expected: 5 PASSED

- [ ] **Step B3.5: Wire `get_alternatives()` and unconditional `msc_steps` into `/analyze` response**

In `app/main.py`, find the block that currently reads (around step 6):

```python
    # 6. Populate MSC steps for Shame interventions
    msc_steps = None
    shame_safety_alert = None
    if FEATURE_SHAME_PROTOCOL and node == "Shame":
        raw_steps = INTERVENTIONS.get("Shame", {}).get("msc_steps")
        if raw_steps:
            # Convert education dicts to strings (use "introduce" depth for MSC display)
            msc_steps = []
            for step in raw_steps:
                step_copy = dict(step)
                if isinstance(step_copy.get("education"), dict):
                    step_copy["education"] = step_copy["education"].get("introduce", "")
                msc_steps.append(step_copy)

        # Shame safety alert: check if 3+ times in 24h
        try:
            shame_count = db.get_shame_count_24h()
            shame_safety_alert = shame_count >= 3
        except Exception:
            logger.error("Shame count check failed", exc_info=True, extra={"request_id": request_id})
            shame_safety_alert = False
```

Replace with:

```python
    # 6. Populate MSC steps for Shame interventions (always-on; no feature flag)
    msc_steps = None
    shame_safety_alert = None
    if node == "Shame":
        raw_steps = INTERVENTIONS.get("Shame", {}).get("msc_steps")
        if raw_steps:
            msc_steps = []
            for step in raw_steps:
                step_copy = dict(step)
                if isinstance(step_copy.get("education"), dict):
                    step_copy["education"] = step_copy["education"].get("introduce", "")
                msc_steps.append(step_copy)

        # Shame safety alert: check if 3+ times in 24h
        try:
            shame_count = db.get_shame_count_24h()
            shame_safety_alert = shame_count >= 3
        except Exception:
            logger.error("Shame count check failed", exc_info=True, extra={"request_id": request_id})
            shame_safety_alert = False

    # 6a. Populate alternatives for "This isn't helping" cycling
    raw_alternatives = get_alternatives(node, sublabel)
    alternatives = [AlternativeIntervention(**alt) for alt in raw_alternatives] if raw_alternatives else None
```

Then find the `response_data` dict (around line 464) and add `"alternatives": alternatives` inside it:

```python
    response_data = {
        ...
        "msc_steps": msc_steps,
        "shame_safety_alert": shame_safety_alert,
        "alternatives": alternatives,   # <-- add this line
        ...
    }
```

- [ ] **Step B3.6: Run all intervention guidance tests**

```bash
cd /Users/adriancorsini/Development/loop-breaker/backend
python -m pytest tests/test_intervention_guidance.py -v
```

Expected: All tests PASS

- [ ] **Step B3.7: Run full backend test suite**

```bash
cd /Users/adriancorsini/Development/loop-breaker/backend
python -m pytest --tb=short
```

Expected: All existing tests still PASS; no regressions.

- [ ] **Step B3.8: Check coverage on changed files**

```bash
cd /Users/adriancorsini/Development/loop-breaker/backend
python -m pytest --cov=app/main --cov=app/models --cov=app/interventions --cov-report=term-missing tests/test_intervention_guidance.py tests/test_shame_protocol.py tests/test_api.py
```

Expected: Coverage on `app/main.py` and `app/interventions.py` ≥ 70%

- [ ] **Step B3.9: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add backend/app/main.py backend/tests/test_intervention_guidance.py
git commit -m "feat: add get_alternatives() and wire steps+alternatives into /analyze response"
```

---

## FRONTEND STREAM

### Task F1: Add "Show full guidance" step toggle to intervention dialog

**Files:**
- Modify: `lib/screens/journal_screen.dart`
- Create: `test/screens/journal_screen_guidance_test.dart`

**Context:** The dialog is built inside `_showStandardInterventionDialog()` using `showDialog` with an `AlertDialog`. The `builder:` callback currently has no local state. To add `_showSteps` toggle without closing/reopening the dialog, wrap the `AlertDialog` in a `StatefulBuilder`.

- [ ] **Step F1.1: Write the failing tests**

Create `test/screens/journal_screen_guidance_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/screens/journal_screen.dart';
import 'package:frontend/services/api_client.dart';

/// Builds a complete mock API response for the given state.
/// [includeSteps] adds msc_steps (3-step MSC protocol).
/// [includeAlternatives] adds 2 alternatives.
Map<String, dynamic> _analyzeResponse({
  String node = 'Shame',
  bool includeSteps = false,
  bool includeAlternatives = false,
}) {
  return {
    'detected_node': node,
    'sublabel': null,
    'emotion_sublabel': null,
    'confidence': 0.85,
    'reasoning': 'Test reasoning',
    'risk_level': 'medium',
    'loop_detected': false,
    'intervention_title': 'Mindful Self-Compassion',
    'intervention_task': 'Take a breath. Notice what you\'re feeling without judgment.',
    'education_info': 'Shame thrives in secrecy.',
    'intervention_type': 'cognitive',
    'msc_steps': includeSteps
        ? [
            {'step': 1, 'name': 'Mindfulness', 'task': 'Place a hand on your heart.', 'education': 'Mindfulness means noticing.'},
            {'step': 2, 'name': 'Common Humanity', 'task': 'Think of someone else.', 'education': 'Suffering is universal.'},
            {'step': 3, 'name': 'Self-Kindness', 'task': 'What would you say to a friend?', 'education': 'Self-kindness replaces judgment.'},
          ]
        : null,
    'alternatives': includeAlternatives
        ? [
            {'title': 'Cognitive Reframe', 'task': 'Notice and rewrite the thought.', 'education': 'Reframing reprograms the loop.', 'type': 'cognitive'},
            {'title': 'Zone 2 Walk', 'task': 'Walk for 5–10 minutes.', 'education': 'Zone 2 shifts your nervous system.', 'type': 'movement'},
          ]
        : null,
  };
}

void _setupMocks({
  required Map<String, dynamic> analyzeData,
  int analyzeStatus = 200,
}) {
  ApiClient.clientOverride = MockClient((request) async {
    if (request.url.path.endsWith('/insight')) {
      return http.Response(
        jsonEncode({'message': 'Welcome', 'weekly_activity': [], 'streak': 0}),
        200,
      );
    }
    if (request.url.path.endsWith('/history')) {
      return http.Response(jsonEncode([]), 200);
    }
    if (request.url.path.endsWith('/analyze')) {
      return http.Response(jsonEncode(analyzeData), analyzeStatus);
    }
    if (request.url.path.endsWith('/feedback')) {
      return http.Response(jsonEncode({'status': 'ok'}), 200);
    }
    return http.Response('Not Found', 404);
  });
}

void main() {
  tearDown(() {
    ApiClient.clientOverride = null;
  });

  Future<void> submitJournal(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: JournalScreen()));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    await tester.enterText(field, 'I feel so ashamed of myself right now');
    await tester.pump();

    final submitButton = find.widgetWithText(ElevatedButton, 'Analyse');
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  group('Show full guidance button', () {
    testWidgets('is absent when msc_steps is null', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: false));
      await submitJournal(tester);

      expect(find.text('Show full guidance'), findsNothing);
    });

    testWidgets('is present when msc_steps is provided', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true));
      await submitJournal(tester);

      expect(find.text('Show full guidance'), findsOneWidget);
    });

    testWidgets('tapping it reveals step 1 name and task', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true));
      await submitJournal(tester);

      await tester.tap(find.text('Show full guidance'));
      await tester.pumpAndSettle();

      expect(find.text('Mindfulness'), findsOneWidget);
      expect(find.text('Place a hand on your heart.'), findsOneWidget);
    });

    testWidgets('tapping it again hides the steps', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true));
      await submitJournal(tester);

      await tester.tap(find.text('Show full guidance'));
      await tester.pumpAndSettle();
      expect(find.text('Mindfulness'), findsOneWidget);

      await tester.tap(find.text('Hide guidance'));
      await tester.pumpAndSettle();

      expect(find.text('Mindfulness'), findsNothing);
    });

    testWidgets('all 3 step names are visible when expanded', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true));
      await submitJournal(tester);

      await tester.tap(find.text('Show full guidance'));
      await tester.pumpAndSettle();

      expect(find.text('Mindfulness'), findsOneWidget);
      expect(find.text('Common Humanity'), findsOneWidget);
      expect(find.text('Self-Kindness'), findsOneWidget);
    });
  });

  group('This isn\'t helping button', () {
    testWidgets('is always present on the dialog', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: false));
      await submitJournal(tester);

      expect(find.text("This isn't helping"), findsOneWidget);
    });

    testWidgets('shows first alternative when tapped once', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: true));
      await submitJournal(tester);

      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(find.text('Cognitive Reframe'), findsOneWidget);
      expect(find.text('Notice and rewrite the thought.'), findsOneWidget);
    });

    testWidgets('shows second alternative when tapped twice', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: true));
      await submitJournal(tester);

      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(find.text('Zone 2 Walk'), findsOneWidget);
      expect(find.text('Walk for 5–10 minutes.'), findsOneWidget);
    });

    testWidgets('shows fallback message when all alternatives exhausted', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: true));
      await submitJournal(tester);

      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(
        find.text("You've tried all the suggestions. Consider reaching out to someone you trust."),
        findsOneWidget,
      );
    });

    testWidgets('shows fallback immediately when no alternatives provided', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeAlternatives: false));
      await submitJournal(tester);

      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(
        find.text("You've tried all the suggestions. Consider reaching out to someone you trust."),
        findsOneWidget,
      );
    });

    testWidgets('resets show-steps state when cycling to next alternative', (tester) async {
      _setupMocks(analyzeData: _analyzeResponse(includeSteps: true, includeAlternatives: true));
      await submitJournal(tester);

      // Expand steps
      await tester.tap(find.text('Show full guidance'));
      await tester.pumpAndSettle();
      expect(find.text('Mindfulness'), findsOneWidget);

      // Cycle to next alternative — steps should collapse
      await tester.tap(find.text("This isn't helping"));
      await tester.pumpAndSettle();

      expect(find.text('Mindfulness'), findsNothing);
    });
  });
}
```

- [ ] **Step F1.2: Run tests — expect failures**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/journal_screen_guidance_test.dart --no-pub
```

Expected: Multiple test failures — buttons and step display don't exist yet.

- [ ] **Step F1.3: Add `_alternativeIndex` state field to `_JournalScreenState`**

In `lib/screens/journal_screen.dart`, find the existing `_currentInterventionIndex` field declaration (in `_JournalScreenState`). Add `_alternativeIndex` directly below it:

```dart
  int _currentInterventionIndex = 0;
  int _alternativeIndex = -1; // -1 = primary; 0,1 = alternatives[index]
```

- [ ] **Step F1.4: Refactor `_showStandardInterventionDialog` to use `StatefulBuilder` and alternatives-driven swap**

Replace the entire `_showStandardInterventionDialog` method with the following. This preserves all existing behaviour (BreathingCircle, education ExpansionTile, personalization cards, "I feel better" / "Didn't help" actions) while adding the two new buttons.

```dart
  void _showStandardInterventionDialog(Map<String, dynamic> data) {
    _alternativeIndex = -1; // Reset on every fresh open

    final String nodeDetected = data['detected_node'] ?? 'Unknown';
    final List<dynamic>? rawAlternatives = data['alternatives'] as List<dynamic>?;
    final List<Map<String, dynamic>> alternatives = rawAlternatives
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final List<dynamic>? rawSteps = data['msc_steps'] as List<dynamic>?;

    // Resolve current content (primary or alternative)
    Map<String, dynamic> _currentContent() {
      if (_alternativeIndex < 0 || _alternativeIndex >= alternatives.length) {
        return {
          'title': data['intervention_title'] ?? 'Pattern Break',
          'task': data['intervention_task'] ?? 'Take a moment to breathe.',
          'education': data['education_info'] ?? '',
          'type': data['intervention_type'] ?? 'other',
        };
      }
      return alternatives[_alternativeIndex];
    }

    bool _isExhausted() => alternatives.isEmpty
        ? _alternativeIndex >= 0
        : _alternativeIndex >= alternatives.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool showSteps = false;

            return StatefulBuilder(
              builder: (context, setStepsState) {
                final content = _currentContent();
                final String title = content['title'] as String? ?? 'Pattern Break';
                final String task = content['task'] as String? ?? '';
                final String education = content['education'] as String? ?? '';
                final String interventionType = content['type'] as String? ?? 'other';
                final bool isExhausted = _isExhausted();

                final bool isBreathing = title.contains('Sigh') || title.contains('Breathing');
                final bool isWater = title.contains('Bio-Sync') || title.contains('Needs');
                final bool isMovement = interventionType == 'movement';

                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        isBreathing
                            ? Icons.air
                            : (isMovement
                                ? Icons.directions_run
                                : (isWater ? Icons.water_drop : Icons.psychology)),
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isExhausted ? 'All suggestions tried' : title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isExhausted) ...[
                          const Text(
                            "You've tried all the suggestions. Consider reaching out to someone you trust.",
                            style: TextStyle(fontSize: 15),
                          ),
                        ] else ...[
                          Text(
                            task,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 25),
                          if (isBreathing) const BreathingCircle(),
                          if (education.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Why this works (neuroscience)'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    education,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blueGrey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Show full guidance toggle (only when msc_steps present and on primary)
                          if (rawSteps != null && rawSteps.isNotEmpty && _alternativeIndex < 0) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setStepsState(() {
                                  showSteps = !showSteps;
                                });
                              },
                              child: Text(
                                showSteps ? 'Hide guidance' : 'Show full guidance',
                                style: const TextStyle(color: Colors.blueAccent),
                              ),
                            ),
                            if (showSteps) ...[
                              const SizedBox(height: 8),
                              ...rawSteps.map((s) {
                                final step = Map<String, dynamic>.from(s as Map);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step['name'] as String? ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        step['task'] as String? ?? '',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                          // Personalization cards
                          if (data['personal_loop'] != null) ...[
                            const SizedBox(height: 16),
                            LoopPatternCard(personalLoop: data['personal_loop']),
                          ],
                          if (data['intervention_effectiveness'] != null) ...[
                            const SizedBox(height: 16),
                            EffectivenessCard(
                              interventionEffectiveness: data['intervention_effectiveness'],
                              interventionTitle: title,
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setStepsState(() {
                          showSteps = false;
                          setState(() {
                            _alternativeIndex++;
                          });
                        });
                      },
                      child: const Text(
                        "This isn't helping",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    if (!isExhausted) ...[
                      TextButton(
                        onPressed: () {
                          _sendFeedback(false);
                          Navigator.pop(context);
                          _alternativeIndex = -1;
                        },
                        child: const Text(
                          "Didn't help",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _sendFeedback(true);
                          Navigator.pop(context);
                          _alternativeIndex = -1;
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Loop Broken! Proud of you.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('I feel better'),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
```

**Note:** Two nested `StatefulBuilder`s are used — the outer one owns `showSteps` and inner provides the rebuild surface. Actually, since both `showSteps` and `_alternativeIndex` need to trigger rebuilds, simplify by using a single `StatefulBuilder` and tracking `showSteps` in the closure:

Replace the two-nested-StatefulBuilder approach above with a single one. Here is the corrected final version of the method — use this instead:

```dart
  void _showStandardInterventionDialog(Map<String, dynamic> data) {
    _alternativeIndex = -1;

    final List<dynamic>? rawAlternatives = data['alternatives'] as List<dynamic>?;
    final List<Map<String, dynamic>> alternatives = rawAlternatives
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final List<dynamic>? rawSteps = data['msc_steps'] as List<dynamic>?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool showSteps = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isExhausted = alternatives.isEmpty
                ? _alternativeIndex >= 0
                : _alternativeIndex >= alternatives.length;

            final Map<String, dynamic> content;
            if (!isExhausted && _alternativeIndex >= 0) {
              content = alternatives[_alternativeIndex];
            } else if (isExhausted) {
              content = {};
            } else {
              content = {
                'title': data['intervention_title'] ?? 'Pattern Break',
                'task': data['intervention_task'] ?? 'Take a moment to breathe.',
                'education': data['education_info'] ?? '',
                'type': data['intervention_type'] ?? 'other',
              };
            }

            final String title = content['title'] as String? ?? 'Pattern Break';
            final String task = content['task'] as String? ?? '';
            final String education = content['education'] as String? ?? '';
            final String interventionType = content['type'] as String? ?? 'other';

            final bool isBreathing = title.contains('Sigh') || title.contains('Breathing');
            final bool isWater = title.contains('Bio-Sync') || title.contains('Needs');
            final bool isMovement = interventionType == 'movement';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    isBreathing
                        ? Icons.air
                        : (isMovement
                            ? Icons.directions_run
                            : (isWater ? Icons.water_drop : Icons.psychology)),
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isExhausted ? 'All suggestions tried' : title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isExhausted) ...[
                      const Text(
                        "You've tried all the suggestions. Consider reaching out to someone you trust.",
                        style: TextStyle(fontSize: 15),
                      ),
                    ] else ...[
                      Text(
                        task,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 25),
                      if (isBreathing) const BreathingCircle(),
                      if (education.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Why this works (neuroscience)'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                education,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueGrey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (rawSteps != null && rawSteps.isNotEmpty && _alternativeIndex < 0) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setDialogState(() => showSteps = !showSteps),
                          child: Text(
                            showSteps ? 'Hide guidance' : 'Show full guidance',
                            style: const TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                        if (showSteps)
                          ...rawSteps.map((s) {
                            final step = Map<String, dynamic>.from(s as Map);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step['name'] as String? ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    step['task'] as String? ?? '',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                      if (data['personal_loop'] != null) ...[
                        const SizedBox(height: 16),
                        LoopPatternCard(personalLoop: data['personal_loop']),
                      ],
                      if (data['intervention_effectiveness'] != null) ...[
                        const SizedBox(height: 16),
                        EffectivenessCard(
                          interventionEffectiveness: data['intervention_effectiveness'],
                          interventionTitle: title,
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => setDialogState(() {
                    showSteps = false;
                    setState(() => _alternativeIndex++);
                  }),
                  child: const Text(
                    "This isn't helping",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                if (!isExhausted) ...[
                  TextButton(
                    onPressed: () {
                      _sendFeedback(false);
                      Navigator.pop(context);
                      _alternativeIndex = -1;
                    },
                    child: const Text(
                      "Didn't help",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _sendFeedback(true);
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      _alternativeIndex = -1;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Loop Broken! Proud of you.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('I feel better'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
```

Also remove the now-unused `_cycleToNextVariant` inner function and `INTERVENTION_VARIANTS` constant if they are no longer referenced. Check with:

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
grep -n "INTERVENTION_VARIANTS\|_cycleToNextVariant\|_currentInterventionIndex" lib/screens/journal_screen.dart
```

Remove any declarations and usages that are now dead code.

- [ ] **Step F1.5: Run guidance tests**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test test/screens/journal_screen_guidance_test.dart --no-pub
```

Expected: All 11 tests PASS

- [ ] **Step F1.6: Run full frontend test suite**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test --no-pub
```

Expected: All existing tests PASS; no regressions. If `journal_screen_variants_test.dart` fails because `INTERVENTION_VARIANTS` was removed, update or delete that file — the variants logic is now API-driven.

- [ ] **Step F1.7: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/screens/journal_screen.dart frontend/test/screens/journal_screen_guidance_test.dart
git commit -m "feat: add Show full guidance toggle and This isn't helping alternative cycling to intervention dialog"
```

---

## FINAL VERIFICATION (run after both streams merged)

- [ ] **Step V1: Run full backend suite with coverage**

```bash
cd /Users/adriancorsini/Development/loop-breaker/backend
python -m pytest --cov=app --cov-report=term-missing
```

Expected: Overall coverage ≥ 65%; `app/main.py` ≥ 70%

- [ ] **Step V2: Run full frontend suite**

```bash
cd /Users/adriancorsini/Development/loop-breaker/frontend
flutter test --no-pub
```

Expected: All tests PASS; count ≥ 230 (219 existing + 11 new)

- [ ] **Step V3: Spec coverage check**

Verify spec requirements against implementation:
- ✅ `steps` (as `msc_steps`) in response for Shame — Task B3
- ✅ `alternatives` in response for Shame (2 entries) — Tasks B1, B3
- ✅ "Show full guidance" button present only when `msc_steps != null` — Task F1
- ✅ Tapping it expands step-by-step section — Task F1
- ✅ Tapping again collapses it — Task F1
- ✅ "This isn't helping" always present — Task F1
- ✅ Tapping it cycles through alternatives — Task F1
- ✅ Exhausted alternatives shows fallback message — Task F1
- ✅ Step state resets on alternative swap — Task F1
- ✅ 2 Shame alternatives: Cognitive Reframe (Rewire) + Zone 2 Walk (Rewire) — Task B1
