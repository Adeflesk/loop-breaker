# Rewire Backlog (Execution-Ready)

Date: 2026-02-12
Source docs:
- `docs/rewire-implementation-plan.md`
- `docs/rewire-specs.md`

## Priority Scale

- P0: critical path for release
- P1: high value, can follow P0
- P2: optional/polish

## Sprint 1 (API + Data Foundation)

### LB-101 (P0) — Add emotion sublabel to analyze output

- Type: Backend
- Files:
  - `backend/app/ai.py`
  - `backend/app/models.py`
  - `backend/app/main.py`
- Description:
  - Extend AI JSON contract to include `emotion_sublabel`.
  - Return fallback `"unspecified"` when missing.
- Acceptance:
  - `POST /analyze` includes `emotion_sublabel` in success and fallback paths.
  - No breaking changes for existing clients.
- DoD:
  - Unit/API tests updated and passing.

### LB-102 (P0) — Persist emotion_sublabel in Neo4j

- Type: Backend/Data
- Files:
  - `backend/app/db.py`
- Description:
  - Add optional property `Entry.emotion_sublabel` on write.
- Acceptance:
  - New entries include `emotion_sublabel` when provided.
  - Existing data remains valid.
- DoD:
  - Migration-safe behavior verified with empty/legacy records.

### LB-103 (P0) — Extend insight with trend + streak

- Type: Backend
- Files:
  - `backend/app/db.py`
  - `backend/app/models.py`
  - `backend/app/main.py`
- Description:
  - Add `recovery_trend` and `streak_days` to `GET /insight`.
- Acceptance:
  - Trend enum returned: `improving|stable|declining|unknown`.
  - Streak defaults to `0` when insufficient data.
- DoD:
  - API tests cover sparse and populated histories.

### LB-104 (P0) — Update API docs for new fields

- Type: Docs
- Files:
  - `docs/api.md`
- Description:
  - Document `emotion_sublabel`, `recovery_trend`, `streak_days`.
- Acceptance:
  - Example payloads match implementation.
- DoD:
  - Docs reviewed and linkable.

## Sprint 2 (High-Risk Needs Check)

### LB-201 (P0) — Add extended feedback payload

- Type: Backend
- Files:
  - `backend/app/models.py`
  - `backend/app/main.py`
  - `backend/app/db.py`
- Description:
  - Support optional `needs_check` + `intervention_type` in `POST /feedback`.
- Acceptance:
  - Legacy payload `{ "success": true|false }` still works.
  - Extended payload persists optional fields.
- DoD:
  - Backward compatibility tests passing.

### LB-202 (P0) — Implement high-risk needs-check UX gate

- Type: Frontend
- Files:
  - `frontend/lib/screens/journal_screen.dart`
- Description:
  - For `risk_level == "High"`, show 4-item needs-check step before intervention dialog.
- Acceptance:
  - Checklist appears only for high risk.
  - User can continue to intervention after completion.
- DoD:
  - Widget tests for high-risk vs low-risk behavior.

### LB-203 (P1) — Send checklist feedback from frontend

- Type: Frontend
- Files:
  - `frontend/lib/screens/journal_screen.dart`
  - `frontend/lib/services/api_client.dart`
- Description:
  - Include checklist outcomes and `intervention_type` in feedback POST.
- Acceptance:
  - Backend receives extended payload for high-risk flows.
- DoD:
  - API client tests updated.

## Sprint 3 (Insight Card Improvements)

### LB-301 (P1) — Render trend/streak in AI Insight card

- Type: Frontend
- Files:
  - `frontend/lib/screens/journal_screen.dart`
- Description:
  - Show `Recovery Trend` and `Streak` in existing card without layout bloat.
- Acceptance:
  - Fields render when present; hide gracefully when absent.
- DoD:
  - Snapshot/widget test for both states.

### LB-302 (P1) — Harden null-safe parsing on insight fields

- Type: Frontend
- Files:
  - `frontend/lib/screens/journal_screen.dart`
  - `frontend/lib/services/api_client.dart`
- Description:
  - Defensive parsing for optional numeric/string fields.
- Acceptance:
  - No runtime exceptions on partial payloads.
- DoD:
  - Error-path tests passing.

## Sprint 4 (Movement Protocols)

### LB-401 (P1) — Add movement interventions by node

- Type: Backend content logic
- Files:
  - `backend/app/interventions.py`
- Description:
  - Introduce node-specific movement options (Zone 1–3) with short safe tasks.
- Acceptance:
  - Stress/Anxiety/Procrastination/Overwhelm/Numbness have movement-capable options.
- DoD:
  - Manual API verification for each target node mapping.

### LB-402 (P1) — Tag intervention type in responses

- Type: Backend
- Files:
  - `backend/app/main.py`
  - `backend/app/models.py`
- Description:
  - Include `intervention_type` in analyze response for analytics.
- Acceptance:
  - Response contains one of: `breathing|grounding|movement|cognitive|other`.
- DoD:
  - API tests validate enum values.

## Cross-Cutting Tasks

### LB-501 (P0) — Feature flags

- Type: Backend/Config
- Files:
  - `backend/app/main.py`
  - `.env`
- Description:
  - Add env flags:
    - `FEATURE_SUBLABELS`
    - `FEATURE_NEEDS_CHECK`
    - `FEATURE_RECOVERY_TREND`
    - `FEATURE_MOVEMENT_PROTOCOLS`
- Acceptance:
  - Features can be toggled without code changes.

### LB-502 (P0) — Regression test sweep

- Type: QA
- Scope:
  - Backend `pytest backend/tests/test_api.py`
  - Frontend `flutter test`
- Acceptance:
  - Existing core endpoints and UI flows unchanged when feature flags disabled.

### LB-503 (P1) — Rollout + observability notes

- Type: Docs/Ops
- Files:
  - `docs/runbook.md`
- Description:
  - Add rollout order, smoke-test checklist, and rollback toggles.
- Acceptance:
  - Runbook includes operational commands and expected API outputs.

## Dependency Graph (Execution Order)

1. LB-101 → LB-102 → LB-103 → LB-104
2. LB-201 → LB-202 → LB-203
3. LB-301 + LB-302 (after LB-103)
4. LB-401 → LB-402
5. LB-501 can begin immediately and should wrap all feature work
6. LB-502 + LB-503 after each sprint

## Release Readiness Checklist

- [ ] All P0 tasks complete
- [ ] Feature flags verified on/off
- [ ] API docs updated
- [ ] Backend tests passing
- [ ] Flutter tests passing
- [ ] Manual smoke test:
  - [ ] analyze
  - [ ] insight
  - [ ] feedback (legacy + extended)
  - [ ] history
