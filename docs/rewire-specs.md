# Rewire Feature Specs

Date: 2026-02-12
Related plan: `docs/rewire-implementation-plan.md`

## 1) Functional Specs

### 1.1 Analyze Endpoint Enhancements

Endpoint: `POST /analyze`

#### Request

```json
{
  "user_text": "I keep avoiding my work and doom scrolling"
}
```

#### Response (new fields)

```json
{
  "detected_node": "Procrastination",
  "emotion_sublabel": "avoidance",
  "confidence": 0.87,
  "reasoning": "Mentions avoidance and delay loops.",
  "risk_level": "High",
  "loop_detected": true,
  "intervention_title": "The 5-Minute Sprint",
  "intervention_task": "Pick the smallest sub-task and do it for 5 minutes.",
  "education_info": "..."
}
```

#### Rules

- `emotion_sublabel` is optional in v1, default: `"unspecified"`.
- If parsing fails, preserve existing fallback behavior and return safe defaults.

### 1.2 Insight Endpoint Enhancements

Endpoint: `GET /insight`

#### Response

```json
{
  "message": "You've disrupted 3 patterns in your top loop. Keep going!",
  "success_rate": 66.67,
  "top_loop": "Stress",
  "recovery_trend": "improving",
  "streak_days": 4
}
```

#### Rules

- `recovery_trend` enum: `improving | stable | declining | unknown`.
- If fewer than 5 scored events exist, use `unknown`.
- `streak_days` counts consecutive calendar days with at least one successful intervention.

### 1.3 Feedback Endpoint Enhancements

Endpoint: `POST /feedback`

#### Request (backward compatible)

```json
{
  "success": true,
  "needs_check": {
    "water": true,
    "food": false,
    "movement": true,
    "rest": false
  },
  "intervention_type": "movement"
}
```

#### Rules

- Existing clients can still send only `{ "success": true|false }`.
- `intervention_type` enum: `breathing | grounding | movement | cognitive | other`.

## 2) Data Model Specs (Neo4j)

### 2.1 Existing Nodes (unchanged)

- `Entry`
- `Node`
- `Intervention`
- `Outcome`

### 2.2 Property Additions

- `Entry.emotion_sublabel: string?`
- `Intervention.type: string?`
- `Outcome.needs_water: bool?`
- `Outcome.needs_food: bool?`
- `Outcome.needs_movement: bool?`
- `Outcome.needs_rest: bool?`

### 2.3 Write Semantics

- On `/analyze`:
  - persist `emotion_sublabel` on latest `Entry`.
- On `/feedback`:
  - attach needs-check properties to the newly created `Outcome`.
  - if absent, store nulls (do not coerce to false).

## 3) Frontend UX Specs

### 3.1 Journal Screen

File: `frontend/lib/screens/journal_screen.dart`

#### AI Insight Card

- Add two optional rows:
  - `Recovery Trend: Improving/Stable/Declining`
  - `Streak: N days`

#### High-Risk Basic Needs Check

- Trigger condition: analyze response `risk_level == "High"`.
- Show inline modal step before current intervention content.
- Checklist items (max 4 taps): water, food, movement, rest.
- CTA: `Continue to Intervention`.

### 3.2 History Screen

File: `frontend/lib/screens/history_screen.dart`

- No major redesign required.
- Optional future enhancement: add intervention-type segmentation chart.

## 4) AI Prompt/Parser Specs

File: `backend/app/ai.py`

### 4.1 Output Contract

Required JSON keys:

- `detected_node` (string)
- `emotion_sublabel` (string)
- `confidence` (float)
- `reasoning` (string)

### 4.2 Allowed Sublabels (v1)

- For Anxiety: `apprehension | fear | hypervigilance`
- For Procrastination: `avoidance | paralysis | distraction`
- For Stress: `overload | tension | urgency`
- For others: free text allowed, fallback to `unspecified`

### 4.3 Validation

- Clamp `confidence` to `[0.0, 1.0]`.
- If `detected_node` invalid, fallback to `Stress`.
- If `emotion_sublabel` missing, set `unspecified`.

## 5) Acceptance Criteria

### API

- `POST /analyze` returns `emotion_sublabel` for valid model responses.
- `GET /insight` returns `recovery_trend` and `streak_days` with safe defaults.
- `POST /feedback` accepts both legacy and extended payloads.

### Frontend

- High-risk analysis always shows needs-check step before intervention.
- Insight card renders new fields when present and hides gracefully when absent.

### Quality

- Backend tests updated and passing.
- Flutter tests updated and passing.
- No breaking changes for existing clients.

## 6) Open Decisions

1. Should needs-check be skippable after timeout (default proposed: yes, after 20s)?
2. Should `emotion_sublabel` be shown on UI now or stored for analytics only?
3. Should `streak_days` count only successful interventions or any journal activity?
