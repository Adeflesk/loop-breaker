# LoopBreaker Improvement Plan

Date: 2026-04-29
Status: Active
Owner: Development Team

---

## Executive Summary

LoopBreaker is a behavioral engineering platform with a working MVP featuring:
- ✅ Core loop detection and intervention logic
- ✅ Emotion granularity (sublabels) 
- ✅ Physiological needs checks (HALT)
- ✅ Frontend UI with history dashboard
- ✅ Backend tests passing (23/23)

**Recent fixes (2026-04-29):**
- ✅ Added `intervention_type` to `/analyze` response
- ✅ Fixed loop-reset behavior in DB to match tests
- ✅ Hardened frontend history parsing with null-safety checks

**Remaining work prioritized across three streams:**
1. **Quality & Reliability** – testing, logging, error handling
2. **User Experience** – frontend polish, state management
3. **Feature Expansion** – advanced insights, movement protocols, recovery scoring

---

## Phase 1: Quality & Reliability (Weeks 1-2)

### 1.1 Test Coverage Enhancement

**Current state:**
- 23 tests passing ✅
- Backend coverage: 44% baseline (outdated; needs rerun)
- Gap: `app/ai.py` (26%), `app/db.py` (29%)

**Goals:**
- Overall backend coverage: ≥ 65%
- `app/ai.py`: ≥ 70%
- `app/db.py`: ≥ 60%
- All critical paths covered

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| Q1.1.1 | Add `clean_ai_response` edge case tests | `backend/tests/test_ai.py` | 3h | P0 |
| Q1.1.2 | Test `query_local_ai` exception paths | `backend/tests/test_ai.py` | 2h | P0 |
| Q1.1.3 | Expand `db.py` DB exception handling tests | `backend/tests/test_db_cleanup.py` | 4h | P0 |
| Q1.1.4 | Add degraded DB behavior tests | `backend/tests/test_api.py` | 2h | P0 |
| Q1.1.5 | Generate coverage report + CI gating | `.github/workflows/ci.yml` | 2h | P1 |

**Acceptance Criteria:**
- `pytest --cov=app --cov-report=term-missing` shows ≥ 65% overall
- All three modules at target thresholds
- No new regressions

---

### 1.2 Error Handling & Logging

**Current gaps:**
- Silent error swallowing in `/analyze` and `/history`
- No structured logging for debugging
- HTTP status codes not used for client errors

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| Q1.2.1 | Add structured logging to `backend/app/ai.py` | `backend/app/ai.py` | 2h | P0 |
| Q1.2.2 | Replace error swallows with HTTP 500/503 | `backend/app/main.py` | 2h | P0 |
| Q1.2.3 | Implement request/response logging middleware | `backend/app/main.py` | 3h | P1 |
| Q1.2.4 | Add error tracking placeholders (Sentry/CloudWatch) | `backend/app/main.py` | 1h | P1 |

**Acceptance Criteria:**
- All errors logged with context (timestamp, request_id, user_text length)
- HTTP responses include proper status codes (400 for validation, 500 for server errors, 503 for DB unavailable)
- Test coverage for error paths ≥ 80%

---

### 1.3 Frontend Resource Management

**Current gaps:**
- `TextEditingController` not disposed (potential memory leak)
- History refresh uses `reassemble()` (anti-pattern)
- No systematic state refresh pattern

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| Q1.3.1 | Add controller disposal in `StatefulWidget` | `frontend/lib/screens/journal_screen.dart` | 1.5h | P1 |
| Q1.3.2 | Implement `StateNotifier` for history refresh | `frontend/lib/services/` | 3h | P1 |
| Q1.3.3 | Replace `reassemble()` with `Navigator.pop()` | `frontend/lib/screens/history_screen.dart` | 1.5h | P1 |
| Q1.3.4 | Add disposal for all `StreamController` uses | `frontend/lib/services/` | 1h | P1 |

**Acceptance Criteria:**
- No controller memory leaks in profile run
- History refresh uses clean state pattern
- Flutter analyzer shows no resource warnings

---

## Phase 2: User Experience (Weeks 2-3)

### 2.1 Frontend Usability Enhancements

**Current state:**
- Single-screen UI (journal → intervention → history)
- Risk indicators present but minimal context
- No visualization of recovery trends

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| X2.1.1 | Add risk level explanation tooltips | `frontend/lib/widgets/` | 2h | P1 |
| X2.1.2 | Enhance insight card with recovery visualizations | `frontend/lib/screens/journal_screen.dart` | 3h | P1 |
| X2.1.3 | Add entry preview/editing on history swipe | `frontend/lib/screens/history_screen.dart` | 4h | P2 |
| X2.1.4 | Implement onboarding/tutorial modal | `frontend/lib/screens/` | 3h | P2 |

**Acceptance Criteria:**
- All risk levels explained on tap
- Insight card shows trend arrow + streak flame
- No "Unknown" states visible to user

---

### 2.2 API Client Improvements

**Current state:**
- Basic HTTP client with minimal error details
- No request retry logic
- No offline fallback

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| X2.2.1 | Add retry-with-backoff for transient failures | `frontend/lib/services/api_client.dart` | 2h | P1 |
| X2.2.2 | Implement local cache for `/history` | `frontend/lib/services/api_client.dart` | 2.5h | P1 |
| X2.2.3 | Add timeout configuration per endpoint | `frontend/lib/services/api_client.dart` | 1h | P1 |

**Acceptance Criteria:**
- 3 retries with exponential backoff for 5xx errors
- `/history` works offline with cached data
- All endpoints timeout after 30s

---

## Phase 3: Feature Expansion (Weeks 3-4)

### 3.1 Movement Protocols

**Current state:**
- Feature flag `FEATURE_MOVEMENT_PROTOCOLS=false`
- Skeleton in interventions but not wired

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| F3.1.1 | Extend interventions with movement variants | `backend/app/interventions.py` | 2h | P1 |
| F3.1.2 | Add movement protocol selection UI | `frontend/lib/screens/journal_screen.dart` | 3h | P1 |
| F3.1.3 | Track movement vs. breathing vs. grounding outcomes | `backend/app/db.py` | 2h | P1 |
| F3.1.4 | Wire feature flag to conditionally show protocols | `backend/app/main.py` | 1.5h | P1 |

**Acceptance Criteria:**
- 3+ movement protocol options available
- Outcome tracking distinguishes by intervention type
- Feature flag gates visibility

---

### 3.2 Advanced Recovery Insights

**Current state:**
- Basic trend (improving/stable/declining)
- Missing-need hints (hydration/rest)
- No recovery goal tracking

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| F3.2.1 | Add recovery goal setting UI | `frontend/lib/screens/` | 3h | P2 |
| F3.2.2 | Implement recovery milestone celebration | `frontend/lib/widgets/` | 2h | P2 |
| F3.2.3 | Add weekly recovery scorecard | `frontend/lib/screens/history_screen.dart` | 3h | P2 |
| F3.2.4 | Wire recovery metrics to `/insight` endpoint | `backend/app/db.py` | 3h | P2 |

**Acceptance Criteria:**
- User can set a recovery goal (e.g., "break stress loop in 7 days")
- Dashboard shows progress toward goal
- Milestones trigger celebratory UI

---

### 3.3 Emotion Wheel Visualization

**Current state:**
- Emotion sublabels stored in DB
- Not visualized or tracked over time

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| F3.3.1 | Create emotion frequency heatmap | `frontend/lib/screens/history_screen.dart` | 4h | P2 |
| F3.3.2 | Add emotion trends to `/stats` endpoint | `backend/app/db.py` | 2h | P2 |
| F3.3.3 | Implement emotion transition graph (e.g., Stress→Procrastination) | `backend/app/db.py` | 3h | P3 |

**Acceptance Criteria:**
- Pie/bar chart shows emotion distribution
- Heatmap shows time-of-day patterns
- Transition graph visible in dashboard

---

## Phase 4: Documentation & DX (Week 4)

### 4.1 Developer Documentation

**Current gaps:**
- No contribution guide
- Missing API endpoint examples for frontend devs
- No local setup troubleshooting

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| D4.1.1 | Write `CONTRIBUTING.md` | Root | 1.5h | P1 |
| D4.1.2 | Expand `docs/api.md` with request/response examples | `docs/api.md` | 2h | P1 |
| D4.1.3 | Create local dev setup guide | `docs/setup.md` | 2h | P1 |
| D4.1.4 | Update runbook with debugging tips | `docs/runbook.md` | 1.5h | P1 |

**Acceptance Criteria:**
- New contributor can run `./run_app.sh` without errors within 15 min
- All API endpoints documented with curl examples

---

### 4.2 CI/CD & Automation

**Current state:**
- GitHub workflows reference in README but not configured
- No automated deployment

**Tasks:**

| ID | Title | Files | Est. | Priority |
|----|-------|-------|------|----------|
| D4.2.1 | Create/update `.github/workflows/ci.yml` | `.github/workflows/` | 2h | P1 |
| D4.2.2 | Add test coverage badge to README | README.md | 0.5h | P1 |
| D4.2.3 | Implement pre-commit hooks (lint, format) | `.pre-commit-config.yaml` | 1h | P2 |

**Acceptance Criteria:**
- PR checks run on: backend tests, coverage, frontend lint
- Coverage badge auto-updates on merge

---

## Timeline & Resource Allocation

```
Week 1 (April 29–May 5):
  Mon–Tue: Phase 1.1 (Test Coverage)                [Q1.1.1–Q1.1.4]
  Wed–Thu: Phase 1.2 (Error Handling)               [Q1.2.1–Q1.2.2]
  Fri:     Phase 1.3 (Frontend Resources)           [Q1.3.1–Q1.3.2]

Week 2 (May 6–12):
  Mon–Tue: Phase 1.3 (cont'd)                       [Q1.3.3–Q1.3.4]
  Wed–Thu: Phase 2.1 (Usability)                    [X2.1.1–X2.1.2]
  Fri:     Phase 2.2 (API Client)                   [X2.2.1–X2.2.3]

Week 3 (May 13–19):
  Mon–Tue: Phase 3.1 (Movement Protocols)           [F3.1.1–F3.1.4]
  Wed–Thu: Phase 3.2 (Recovery Insights)            [F3.2.1–F3.2.2]
  Fri:     Phase 3.3 (Emotion Visualization)        [F3.3.1]

Week 4 (May 20–26):
  Mon–Tue: Phase 3.3 (cont'd)                       [F3.3.2–F3.3.3]
  Wed–Thu: Phase 4.1 (Dev Documentation)            [D4.1.1–D4.1.4]
  Fri:     Phase 4.2 (CI/CD)                        [D4.2.1–D4.2.3]
```

---

## Success Metrics

### Quality
- Test coverage: ≥ 65% (currently 44%)
- Backend tests: 30+ passing (currently 23)
- Zero critical bugs post-release
- Error/exception logs structured

### User Experience
- Time-to-loop-detection: < 3 taps
- Intervention completion rate: > 60%
- DAU retention after 7 days: > 40%

### Features
- Movement protocols available and tracked
- Recovery goal tracking functional
- Emotion heatmap visible in dashboard

### Developer Experience
- New contributor setup time: < 15 min
- CI/CD pass rate: 95%+
- PR review turnaround: < 24 hours

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| DB schema changes break migrations | High | Test migration script on staging; add rollback plan |
| Feature flags not propagating | Medium | Add integration test for flag behavior |
| Frontend memory issues on old devices | Medium | Profile on Android 8+; set heap limits in tests |
| Ollama service timeouts | High | Increase timeout to 60s; add circuit breaker |
| Coverage tools give false negatives | Low | Run coverage locally + CI; cross-validate reports |

---

## Dependencies & Blockers

- None at start (all gaps fixed as of 2026-04-29)
- Review: Feature flags need env var propagation if not already done

---

## Appendix: Completed Items (2026-04-29)

✅ **Gap Fixes Applied:**
- `intervention_type` returned from `/analyze`
- Loop-reset behavior aligned with test expectations
- Frontend history parsing hardened with null-safety
- All 23 backend tests passing

✅ **Prior Work (2026-02-12 → 2026-04-29):**
- Sublabel persistence (emotion granularity)
- HALT physiological needs check
- Neo4j driver lifecycle managed
- CORS security tightened
- Insight card with trend/streak indicators

---

## Next Steps

1. **This week (Apr 29):** Review plan with team; assign owners to Phase 1 tasks
2. **Week 1 (Apr 29–May 5):** Execute Phase 1 (Quality & Reliability)
3. **Weekly sync:** Track progress against timeline; adjust scope as needed

---

## Sign-Off

- **Plan Created:** 2026-04-29
- **Version:** 1.0
- **Status:** Ready for execution
- **Owner:** Development Team
