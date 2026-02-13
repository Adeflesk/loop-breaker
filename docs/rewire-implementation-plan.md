# Rewire-Informed Implementation Plan

Date: 2026-02-12
Owner: LoopBreaker Team
Status: Proposed

## Goal

Improve LoopBreaker using practical ideas from Rewire: break behavioral cycles faster, increase emotional granularity, and strengthen recovery behaviors without adding heavy UX complexity.

## Non-Goals

- No clinician-facing diagnosis features.
- No cloud ML migration.
- No major UI redesign.

## Success Metrics

- `/insight` adoption: at least 60% of active users view at least one insight card per session.
- Intervention completion rate: +20% relative increase.
- Successful intervention feedback rate: +10% relative increase.
- High-risk repeated-loop frequency: -15% after 4 weeks.

## Scope Summary

1. Emotion granularity layer (primary node + sublabel).
2. Basic-needs check-in before high-risk interventions.
3. Recovery trend scoring and richer insight card messaging.
4. Movement protocol interventions (Zone 1–3 first).

## Phase Plan

### Phase 1 — Data and API Foundation (Week 1)

#### Deliverables

- Extend `/analyze` response with `emotion_sublabel`.
- Extend stored entry metadata with optional `needs_check` object.
- Extend `/insight` response with `recovery_trend` and `streak_days`.

#### Tasks

- Backend:
  - Update `backend/app/ai.py` prompt and parsing to produce sublabel.
  - Update `backend/app/models.py` response schemas.
  - Update `backend/app/db.py` with aggregation methods for trend/streak.
  - Update `backend/app/main.py` endpoint payloads.
- Tests:
  - Add/expand API tests for new fields in `backend/tests/test_api.py`.

#### Exit Criteria

- API tests pass with new fields and fallback defaults.
- Existing frontend does not break when fields are absent.

### Phase 2 — High-Risk Basic Needs Breaker (Week 2)

#### Deliverables

- If `risk_level == "High"`, frontend displays a 60-second check-in for:
  - water,
  - food,
  - movement,
  - rest.
- Completion of the check-in is included in intervention feedback payload.

#### Tasks

- Frontend:
  - Add a lightweight pre-intervention card in `frontend/lib/screens/journal_screen.dart`.
  - Keep current intervention dialog flow unchanged after checklist completion.
- Backend:
  - Extend `POST /feedback` payload to include optional checklist outcomes.
  - Persist checklist summary on latest unresolved intervention.

#### Exit Criteria

- High-risk flow requires checklist before intervention action button.
- No additional screens/routes introduced.

### Phase 3 — Insight and Recovery Trend (Week 3)

#### Deliverables

- Insight card includes:
  - message,
  - success rate,
  - top loop,
  - trend direction (`improving|stable|declining`),
  - current streak days.

#### Tasks

- Backend:
  - Compute trend from rolling 7-entry windows.
- Frontend:
  - Update AI insight card in `frontend/lib/screens/journal_screen.dart` to render trend and streak.

#### Exit Criteria

- Insight card remains compact and readable on mobile widths.
- Trend math returns safe defaults with sparse data.

### Phase 4 — Movement Interventions (Week 4)

#### Deliverables

- Add movement options tied to detected node:
  - Stress/Anxiety: Zone 1–2 protocol,
  - Procrastination/Overwhelm: Zone 2 activation protocol,
  - Numbness: brief sensory + light movement protocol.

#### Tasks

- Update `backend/app/interventions.py` intervention catalog.
- Add completion feedback tags to distinguish breathing vs movement outcomes.

#### Exit Criteria

- At least one movement option appears for each target node.
- Feedback analytics can segment outcomes by intervention type.

## Risks and Mitigations

- Risk: AI output format drift.
  - Mitigation: strict JSON schema prompt + defensive parsing + fallback sublabel (`"unspecified"`).
- Risk: Sparse data creates noisy trends.
  - Mitigation: minimum sample thresholds before trend labels.
- Risk: Added friction lowers completion.
  - Mitigation: keep checklist to 4 taps max and optional skip after timeout.

## Rollout Strategy

- Feature flags (env-based):
  - `FEATURE_SUBLABELS=true`
  - `FEATURE_NEEDS_CHECK=true`
  - `FEATURE_RECOVERY_TREND=true`
  - `FEATURE_MOVEMENT_PROTOCOLS=true`
- Enable in staging first, then production in this order:
  1. Sublabels,
  2. Trend,
  3. Needs check,
  4. Movement protocols.

## Definition of Done

- API docs and frontend/backend docs updated.
- Backend tests passing.
- Flutter tests passing for affected screens.
- Manual smoke test confirms:
  - `/analyze`, `/feedback`, `/insight`, `/history` remain functional.
