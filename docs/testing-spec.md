# Testing Specification

Date: 2026-02-12
Scope: Backend API and logic coverage for LoopBreaker

## Objectives

- Keep tests deterministic by mocking external dependencies (Ollama, Neo4j).
- Validate Rewire-critical behavior:
  - granularity (`sublabel`),
  - chronic loop detection,
  - intervention reset-to-baseline behavior,
  - insight trend/streak contract.
- Raise backend coverage with priority on runtime/error branches.

## Test Commands

### Backend functional tests

```bash
cd backend
python -m pytest tests -q
```

### Backend coverage report

```bash
cd backend
python -m pytest --cov=app --cov-report=term-missing tests -q
```

## Current Coverage Baseline

Latest run (2026-02-12):

- Total: **44%**
- Tests passing: **8 passed**

Per-file coverage:

- `app/main.py`: 71%
- `app/ai.py`: 26%
- `app/db.py`: 29%
- `app/models.py`: 100%
- `app/interventions.py`: 100%

## Required Behavioral Tests (Backend)

### Analyze Contract

- `POST /analyze` returns:
  - `detected_node`
  - `sublabel`
  - `emotion_sublabel`
  - `risk_level`
  - `loop_detected`
- High-risk sublabels trigger `risk_level == "High"`.

### Chronic Loop Detection

- Three consecutive entries of the same node should produce:
  - `loop_detected == true`
  - `risk_level == "High"`

### Intervention Rebound / Reset

- After loop is high, `POST /feedback {"success": true}` should reset loop memory.
- Next analyze call should return:
  - `loop_detected == false`
  - `risk_level == "Low"`

### Insight Contract

- `GET /insight` returns:
  - `message`, `success_rate`, `top_loop`, `trend`, `streak`
- Trend test must validate at least one explicit value (e.g., `improving`).

### Degraded DB Behavior

- If DB is unavailable:
  - app still imports/starts,
  - `/history` returns safe fallback,
  - `/insight` returns safe fallback,
  - `/reset` returns `503`.

## Coverage Improvement Plan

### Priority 1: `app/ai.py` (Target: 70%+)

Add tests for:

- `clean_ai_response` with:
  - invalid node fallback,
  - low confidence sublabel reset,
  - confidence clamping,
  - malformed confidence types.
- `query_local_ai`:
  - success parse path,
  - missing `response` key fallback,
  - request exception fallback.

### Priority 2: `app/db.py` (Target: 60%+)

Add tests with DB session monkeypatch fakes for:

- `log_and_analyze` normal + exception path,
- `resolve_intervention` exception path,
- `get_history` exception path,
- `get_ai_insight` no-record + exception path,
- `reset_all_data` success/failure bool behavior.

### Priority 3: `app/main.py` (Target: 80%+)

Add API tests for:

- startup model-check edge paths,
- `/reset` 503 path,
- `/insight` default payload path,
- `/analyze` fallback when AI returns minimal data.

## Acceptance Criteria

- All backend tests pass (`pytest tests -q`).
- Coverage thresholds:
  - overall backend: **>= 65%**,
  - `app/ai.py`: **>= 70%**,
  - `app/db.py`: **>= 60%**,
  - `app/main.py`: **>= 80%**.
- No test requires live Ollama or live Neo4j.

## Notes

- Keep tests fast and isolated.
- Prefer fixture-based monkeypatching over global state mutations.
- Expand frontend tests separately to validate HALT modal flow and insight state indicator rendering.
