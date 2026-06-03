# Intervention Guidance & Alternatives — Design Spec

**Date:** 2026-06-02
**Status:** Approved
**Branch:** feat/intervention-guidance-alternatives

---

## Problem

The intervention card surfaces a brief task description (e.g. *"Take a breath. Notice what you're feeling without judgment."* for Shame) but no practical how-to. Users who are new to an intervention need step-by-step guidance; users who have seen the same state multiple times don't. Additionally, when an intervention isn't landing there is no escape hatch — users are stuck with the same card.

---

## Solution

Option A — inline card expansion with progressive disclosure:

- **"Show full guidance"** button toggles a step-by-step walkthrough inline on the card (no new screen/modal)
- **"This isn't helping"** button cycles through alternative interventions for the same state; exhausting all alternatives shows a static fallback message

---

## Architecture

### Backend — `/analyze` response additions

Two new fields added to the response payload:

```json
{
  "steps": [
    { "step": 1, "name": "Mindfulness", "task": "Place a hand on your heart..." },
    { "step": 2, "name": "Common Humanity", "task": "Think of someone else..." },
    { "step": 3, "name": "Self-Kindness", "task": "Ask: what would I say to a friend..." }
  ],
  "alternatives": [
    {
      "title": "Cognitive Reframe",
      "task": "Notice the thought ('I am bad/broken'). Replace it: 'I made a mistake. My brain can adapt and I can learn from this.'",
      "education": "Shame hijacks your negativity bias — your brain amplifies self-critical signals by default. Cognitive reframing literally rewires the neural pathway by substituting the self-attack loop with a growth signal. Repeated practice weakens the shame circuit and strengthens the learning circuit.",
      "type": "cognitive"
    },
    {
      "title": "Zone 2 Walk",
      "task": "Walk at a comfortable pace for 5–10 minutes — slow enough that you could hold a conversation. No destination needed.",
      "education": "Shame creates a freeze response. Zone 2 activity sends direct muscle-to-brain signals (via your myokines and vagus nerve) that shift your nervous system out of threat mode without overwhelming an already activated system. Your muscles communicate directly with your brain.",
      "type": "movement"
    }
  ]
}
```

**Rules:**
- `steps` is populated from `msc_steps` in the catalog for Shame; `null` for all other states currently. Field is additive — other states can gain steps later without a schema change.
- `alternatives` is pre-selected at response time from existing catalog entries for that state. For states with sublabel variants (Anxiety, Stress, Procrastination, Overwhelm), unused sublabel interventions become the alternatives pool, with the movement variant always last. For Shame (single intervention), two new catalog entries are added (see Catalog Additions below).
- Both fields are optional in the response contract — frontend must handle `null` gracefully.

### Frontend — Intervention card widget

The existing intervention card layout is unchanged. Two elements are added below the task text:

**"Show full guidance" button**
- Rendered only when `steps != null`
- Taps toggle `bool _showSteps` on the card's `State`
- Expanding reveals an animated `Column` of numbered step cards, each showing: step name, task instruction, education blurb (collapsed by default, tappable to expand)
- Collapsing hides the steps section with the same animation

**"This isn't helping" button**
- Always rendered (subtle text button, not a primary action — visually subordinate to the main card)
- Tracks position with `int _alternativeIndex` (starts at -1 = primary)
- On tap: increments index, swaps card content to `alternatives[_alternativeIndex]`, resets `_showSteps` to false
- When `_alternativeIndex >= alternatives.length`: replaces card content with static message — *"You've tried all the suggestions. Consider reaching out to someone you trust."*
- No navigation, no modal — all state is local to the card widget

---

## Catalog Additions (Shame)

Two new entries added to `INTERVENTIONS["Shame"]` in `backend/app/interventions.py`:

### Cognitive Reframe (Alt 1 — Rewire neurohack)
```python
{
    "title": "Cognitive Reframe",
    "task": "Notice the thought that's running ('I am bad', 'I'm broken', 'I'm not enough'). Write it down. Now rewrite it: 'I made a mistake. My brain can adapt and I can learn from this.'",
    "education": {
        "introduce": "Shame activates your negativity bias — your brain is wired to amplify self-critical signals. The story 'I am bad' feels like truth because your neural pathway for it is well-worn.",
        "reinforce": "Cognitive reframing reprograms the loop. Each time you catch the thought and replace it, you weaken the shame circuit and strengthen the growth circuit. Repetition is the mechanism.",
        "deepen": "Your default mode network runs the 'I am bad' narrative on autopilot. Reframing activates your central executive network (DLPFC), which competes with the DMN for cortical dominance. Over time, the reframe becomes the default — the old loop loses its grip."
    },
    "type": "cognitive"
}
```

### Zone 2 Walk (Alt 2 — Rewire muscle-brain chapter)
```python
{
    "title": "Zone 2 Walk",
    "task": "Walk at a comfortable pace for 5–10 minutes — slow enough that you could hold a conversation. No phone, no destination. Let your body lead.",
    "education": {
        "introduce": "Shame creates a freeze response — your nervous system locks up. Zone 2 movement is light enough not to trigger more stress, but active enough to shift your physiology.",
        "reinforce": "Your muscles communicate directly with your brain via myokines (muscle-released proteins) and vagal afferents. Zone 2 activity tells your brain the threat has passed, even when your thoughts haven't caught up yet.",
        "deepen": "Shame suppresses your parasympathetic nervous system. Rhythmic Zone 2 movement restores vagal tone, lowers cortisol, and reactivates your prefrontal cortex. The body leads; the mind follows. Repeated practice builds a somatic escape route from the freeze state."
    },
    "type": "movement"
}
```

---

## Alternative Selection Logic (Backend)

```python
def get_alternatives(state: str, sublabel: str | None) -> list[dict]:
    state_map = INTERVENTIONS.get(state, {})
    primary_key = sublabel if sublabel in state_map else None
    alternatives = []
    for key, entry in state_map.items():
        if key == primary_key or key == "movement":
            continue  # skip primary and movement (movement added last)
        if isinstance(entry, dict) and "title" in entry:
            alternatives.append(entry)
    # Movement variant always offered last
    if "movement" in state_map:
        alternatives.append(state_map["movement"])
    return alternatives[:2]  # cap at 2 alternatives
```

---

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| State has only one intervention (Shame, Numbness, Restlessness, Isolation) | After exhausting alternatives, show static fallback message |
| `steps` is null (all states except Shame) | "Show full guidance" button not rendered |
| `alternatives` is empty | "This isn't helping" immediately shows fallback message |
| User taps "This isn't helping" then "Show full guidance" | Steps for new alternative shown (only if new alt has steps) |
| Movement variant present | Always offered as final alternative — most reliable biological reset |

---

## Testing

### Backend (pytest)
- `/analyze` for Shame returns `steps` (3 items) and `alternatives` (2 items)
- `/analyze` for Anxiety with sublabel "Panic" returns correct primary + alternatives pool
- `/analyze` for Numbness returns `steps: null` and `alternatives` with at most 2 items
- `get_alternatives()` unit tests for each state category

### Frontend (flutter_test)
- "Show full guidance" button absent when `steps == null`
- "Show full guidance" button present and toggles steps section when `steps != null`
- "This isn't helping" swaps card content to `alternatives[0]`
- Second tap swaps to `alternatives[1]`
- Third tap shows fallback message
- `_showSteps` resets to false on each alternative swap
- Fallback message text renders correctly

### Integration
- Shame entry → primary MSC card shown → "not helping" → cognitive reframe card → "not helping" → Zone 2 walk card → "not helping" → fallback message

---

## Files Changed

| File | Change |
|------|--------|
| `backend/app/interventions.py` | Add 2 Shame alternatives to catalog |
| `backend/app/main.py` | Populate `steps` and `alternatives` in `/analyze` response |
| `backend/app/models.py` | Add `steps` and `alternatives` to response model |
| `frontend/lib/services/api_client.dart` | Parse new `steps` and `alternatives` fields |
| `frontend/lib/screens/journal_screen.dart` | Extend `_showStandardInterventionDialog` — add "Show full guidance" toggle and replace `_cycleToNextVariant` with `alternatives`-driven swap |
| `backend/tests/test_api.py` | Backend integration tests for new response fields |
| `backend/tests/test_interventions.py` | Unit tests for `get_alternatives()` logic |
| `frontend/test/screens/journal_screen_guidance_test.dart` | Widget tests for toggle + swap behaviour |

---

## Out of Scope

- Persisting which alternatives a user has seen across sessions (no local storage in this pass)
- Auto-switching to brief mode based on history (future feature)
- Adding `steps` to non-Shame intervention types (additive, future pass)
- User rating/feedback on whether an intervention helped (separate feature)
