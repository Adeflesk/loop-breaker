# Claude Integration Guide

**Date:** 2026-04-29  
**Status:** Active  
**Owner:** Development Team

## Purpose

This document describes how to work with Claude on LoopBreaker tasks, including coding style, AI integration patterns, and recommended development workflows. It's the reference for Claude-assisted development and LLM integration work.

---

## Working with Claude: Best Practices

### Task Approach
- **Start with planning:** Complex tasks (3+ steps, architectural decisions, refactoring) should use `/plan` or `EnterPlanMode` to align on approach before coding. All plans are stored in `docs/` (e.g., `docs/rewire-gap-analysis.md`).
- **Use skills where applicable:** Claude Code has specialized skills for debugging, TDD, code review, and architecture. If a task involves these, Claude will invoke the relevant skill.
- **Verify before completion:** Use `/verify` or the verification skill before claiming work is done—run tests, check coverage, test the UI.
- **Minimal scope:** Bug fixes should fix the bug, not clean up surrounding code. Features should deliver the feature, not add hypothetical helpers.

### Code Review & Feedback
- **Technical rigor first:** If code review feedback seems unclear or questionable, ask for clarification and verify the technical reasoning.
- **No silent acceptance:** Don't blindly implement suggestions—understand the "why" and challenge if needed.
- **Explicit about trade-offs:** When suggesting approaches, Claude should name the trade-off (e.g., "simpler but less extensible").

### Debugging & Problem-Solving
- **Root cause first:** Don't reach for destructive fixes (--no-verify, git reset --hard) as shortcuts. Diagnose the underlying issue.
- **Evidence before assertions:** Test output, logs, and diffs—not assumptions about what should work.

### Communication
- **Short and direct:** Responses should be concise—one sentence updates at key moments, no narration of internal deliberation.
- **Actionable feedback:** Point to specific files/lines when referencing code: `[filename.ts:42](src/filename.ts#L42)`.
- **Show don't tell:** When explaining a pattern or fix, show the diff or code, not a description.

### Scope & Reversibility
- **Check before risky actions:** Force pushes, deletes, destructive operations always get explicit confirmation first.
- **Local-first for exploration:** Use read-only tools (grep, find, Read) before making changes.
- **Preserve work:** Investigate unfamiliar state (branches, files) before deleting—it might be in-progress work.

---

## Quick Start

### Environment Setup
```bash
# Backend
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Frontend
cd frontend
flutter pub get

# Run dev server (backend on :8000, frontend on :4200)
./run_app.sh
```

### Common Commands
```bash
# Tests
cd backend && pytest                    # Run backend tests
cd backend && pytest --cov=app          # With coverage report
cd frontend && flutter test             # Run Flutter tests

# Code quality
cd backend && black . && isort .        # Format Python
cd frontend && dart format lib/         # Format Dart

# Dev server
./run_app.sh                            # Start both backend and frontend

# Coverage check
cd backend && pytest --cov=app --cov-report=term-missing
```

### Architecture Overview
```
loop-breaker/
├── backend/
│   ├── app/
│   │   ├── main.py           # FastAPI entry point, routes
│   │   ├── models.py         # Pydantic request/response schemas
│   │   ├── db.py             # Neo4j operations, loop detection
│   │   ├── ai.py             # Claude/Ollama prompts, response parsing
│   │   ├── interventions.py  # Intervention catalog and mapping
│   │   └── tests/            # pytest suite (23+ tests)
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   │   ├── main.dart         # App entry, routing
│   │   ├── screens/          # Journal, History, Intervention
│   │   ├── widgets/          # Reusable UI components
│   │   ├── services/
│   │   │   └── api_client.dart  # HTTP client to /analyze, /history
│   │   └── models/           # Dart data classes
│   └── pubspec.yaml
├── docs/
│   ├── improvement-plan.md   # 4-week roadmap
│   ├── architecture.md       # Design decisions
│   └── api.md                # API contract (endpoints, examples)
└── claude.md                 # This file
```

**Data Flow:**
1. User enters journal entry in Flutter app
2. Frontend calls `POST /analyze` with `user_text`
3. Backend: `ai.py` → Claude/Ollama → `clean_ai_response()` → `INTERVENTIONS` mapping
4. Backend: `db.py` → Neo4j loop detection and storage (graceful degradation if unavailable)
5. Response includes intervention, risk level, emotion sublabel, education info
6. Frontend displays intervention card with history persistence

---

## Project Coding Style

### General principles
- Keep code small, readable, and explicit.
- Prefer defensive defaults and safe fallbacks.
- Use clear naming: `detected_node`, `emotion_sublabel`, `risk_level`, `loop_detected`.
- Avoid hidden side effects during import time.
- Use feature flags for rollout-sensitive behavior.
- Keep docs and code aligned: API contract examples should match implementation.

### Backend Python style
- Use `FastAPI` with explicit request/response models in `backend/app/models.py`.
- Keep business logic in `backend/app/db.py`, `backend/app/ai.py`, and `backend/app/interventions.py`.
- Use `async` for I/O-bound AI calls and `httpx` for remote requests.
- Handle Neo4j connectivity as a graceful degraded mode.
- Log errors with context and avoid silent failure.
- Use `pydantic` models for request validation and contract safety.

### Frontend Dart style
- Use Flutter idioms with `StatefulWidget` for screens that hold local state.
- Keep service calls in `frontend/lib/services/api_client.dart`.
- Use `FutureBuilder` for async data and safe null handling.
- Avoid string slicing without guardrails on parsed date/time values.
- Keep UI code declarative and use small helper widgets where appropriate.

## Prompt & Response Contract

### Safe Defaults (Fallback Values)
When AI response is malformed, unavailable, or parse fails, return these:
```python
SAFE_DEFAULTS = {
    "node": "Stress",
    "emotion_sublabel": "General",
    "confidence": 0.5,
    "reasoning": "Unable to process input. Please try again.",
    "risk_level": "medium",
    "loop_detected": False,
}
```

### Prompt Guidelines
- Request **strict JSON output** with explicit schema
- Include all valid state names and sublabels as examples
- Validate parsed output against known states before returning
- Log raw model output for debugging (with user PII redacted)

### Response Contract (`/analyze`)
The endpoint **always** returns these fields:
```json
{
  "sublabel": "string",
  "emotion_sublabel": "string",
  "confidence": float (0.0-1.0),
  "reasoning": "string",
  "risk_level": "low|medium|high",
  "loop_detected": boolean,
  "intervention_title": "string",
  "intervention_task": "string",
  "education_info": "string",
  "intervention_type": "breathing|grounding|movement|reflection"
}
```

**Note:** If AI is unavailable, return safe defaults with `intervention_type: "breathing"` (default intervention).

### Intervention Mapping
State names from Claude/Ollama → intervention selection in `backend/app/interventions.py`:
- Map AI output to one of 4 intervention types
- Ensure every possible state has a defined intervention
- If state is unknown, default to "breathing"

## Feature Flags

Feature-driven features use `FEATURE_*` env vars. Check `backend/app/main.py` for current flags:

```python
FEATURE_MOVEMENT_PROTOCOLS = os.getenv("FEATURE_MOVEMENT_PROTOCOLS", "false").lower() == "true"
```

**Usage in code:**
```python
if FEATURE_MOVEMENT_PROTOCOLS:
    # movement-specific logic
```

**To enable locally:**
```bash
export FEATURE_MOVEMENT_PROTOCOLS=true
./run_app.sh
```

**When adding a flag:**
1. Define in `backend/app/main.py`
2. Wire in the endpoint handler (return conditional response)
3. Add integration test in `backend/tests/test_api.py`
4. Document in this file and improvement-plan.md

---

## AI/LLM Integration Workflow

When adding or updating AI prompt behavior:

1. **Update prompt** in `backend/app/ai.py` (system message, examples, validation rules)
2. **Test fallbacks:** Run `clean_ai_response()` with edge cases (malformed JSON, missing fields, null values)
3. **Add unit tests** in `backend/tests/test_ai.py` covering:
   - Valid output → correct parsing
   - Missing fields → safe defaults
   - Invalid JSON → fallback state
4. **Integration test** — call `/analyze` with real model, verify full contract in response
5. **Frontend validation** — confirm `frontend/lib/services/api_client.dart` handles both nominal and degraded payloads
6. **Verify coverage:** `pytest --cov=app/ai.py --cov-report=term-missing` target ≥70%

---

## Testing & Coverage

**Target coverage:** ≥65% overall, ≥70% for `app/ai.py`, ≥60% for `app/db.py`

```bash
# Run with coverage report
cd backend && pytest --cov=app --cov-report=term-missing

# Check specific module
cd backend && pytest --cov=app/ai.py --cov-report=term-missing app/tests/test_ai.py
```

**Critical paths to test:**
- AI response parsing and fallback (ai.py)
- Database operations with and without Neo4j (db.py)
- HTTP error handling (main.py)
- Intervention mapping (interventions.py)

---

## Error Handling Pattern

**Backend:**
```python
try:
    result = query_ai(user_text)
    parsed = clean_ai_response(result)  # Returns safe defaults on parse failure
    return {"status": "ok", "data": parsed}
except Exception as e:
    logger.error("AI call failed", extra={"error": str(e), "user_text_len": len(user_text)})
    return {"status": "unavailable", "data": safe_fallback}  # Never crash
```

**Key rule:** If Claude/Ollama/Neo4j is unavailable, return safe defaults (Stress state, General sublabel), not HTTP 500.

**Logging:** Always include context (timestamp, request_id, lengths, state names). Do not expose raw model errors to frontend.

## Notes & Maintenance

- **Last updated:** 2026-04-29
- **Next review:** After Phase 1 completion (week 2, ~May 5)
- This file documents how Claude works with the LoopBreaker team—update it as workflows evolve
- When committing major architectural changes or new patterns, update the relevant section here
- Phase 4.1 (Developer Documentation) includes expanding `docs/api.md` and `docs/setup.md` with more endpoint examples and runbook details
- If the project adopts a formal agent framework or prompt library, update the "AI/LLM Integration Workflow" section to reference it

---

## Quick Links
- **Improvement Plan:** [docs/improvement-plan.md](docs/improvement-plan.md)
- **Architecture:** [docs/architecture.md](docs/architecture.md)
- **API Contract:** [docs/api.md](docs/api.md)
- **Contribution Guide:** [CONTRIBUTING.md](CONTRIBUTING.md) (coming in Phase 4)
