# Claude Integration Guide

Date: 2026-04-29
Status: Created

## Purpose

This document describes how the LoopBreaker project should approach Claude-style prompt engineering, integration, and code style. It is intended as a root-level reference for any Claude or LLM-related work.

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

## Claude / LLM integration

### Prompt contract
- The AI prompt should request strict JSON output.
- Include valid state names and sublabels.
- Fall back to safe defaults when parsing fails:
  - `node`: `Stress`
  - `emotion_sublabel`: `General`
  - `confidence`: `0.5`
  - `reasoning`: descriptive fallback text

### Response shaping
- Map AI state names to the `INTERVENTIONS` catalog in `backend/app/interventions.py`.
- Ensure both compatibility and explicit fields in `/analyze`:
  - `sublabel`
  - `emotion_sublabel`
  - `confidence`
  - `reasoning`
  - `risk_level`
  - `loop_detected`
  - `intervention_title`
  - `intervention_task`
  - `education_info`
  - `intervention_type`

### Error handling
- If Claude/Ollama is unavailable, return a safe fallback payload, not a crash.
- Use logging to capture raw AI responses and parse failures.
- Do not expose raw model errors to the frontend.

## Recommended workflow

1. Update prompts in `backend/app/ai.py`.
2. Validate model output with `clean_ai_response()`.
3. Add or update tests for new prompt behavior.
4. Verify `/analyze` returns the full API contract.
5. Confirm frontend handles both the nominal and degraded paths.

## Notes

- This file was added to support Claude-style integration in the LoopBreaker codebase.
- If the project later uses a formal agent or prompt library, this file should be updated to reference that implementation.
