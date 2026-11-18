# LoopBreaker Development History

This document tells the story of **LoopBreaker** (`loop-breaker`)—how it evolved from a local Mac/Ollama/Neo4j prototype into a cloud-hosted, passcode-protected behavioral loop-breaking app, as recorded across **144 commits**, **8 pull requests**, and **5 feature/worktree branches** between **February 8, 2026** and **November 14, 2026**.

> Every milestone, bug, pivot, and crisis below is traced directly to verified git commits and pull requests on `master` and its branches.

---

## Timeline at a Glance

| Period | Milestone | Key Branches / PRs |
| :--- | :--- | :--- |
| **Feb 8 – Feb 13, 2026** | Genesis: local Flutter + FastAPI + Ollama + Neo4j prototype | `master` (`fea3a35`..`42b981d`) |
| **Apr 29 – May 10, 2026** | Reliability, CI coverage gates, 3-depth education, Loop Path, personalization | `master` (`4816323`..`73bf402`) |
| **May 10 – May 24, 2026** | Crisis Safety Layer, Movement Protocols, UI/mock crises, Recovery Insights | `phase4-code-quality-refactor` (PR #1 closed, merged via `a011754`), `worktree-phase-3-2-recovery-insights` (PR #2) |
| **May 27 – Jun 4, 2026** | Phase 6 Longitudinal Intelligence, Learn tab, Daily Check-In, CI rebuild fixes | `feat/phase6-frontend-remaining` (PR #3, PR #4) |
| **Nov 2, 2026** | Post-summer audit: data reset fix, daily-check correlation, Restlessness zones | `feat/phase6-frontend-remaining` (PR #5) |
| **Nov 6 – Nov 12, 2026** | Phase 7 Daily Practice & Values; Phase 8 Environment Audit & Narrative Export | `feat/phase7-daily-practice` (PR #6), `feat/phase8-advanced-intelligence` (PR #7) |
| **Nov 11 – Nov 14, 2026** | Low-RAM Pi 3 pivot, Gemini API + SQLite, Cloud Run + AuraDB production fixes | `feat/phase8-advanced-intelligence` (PR #8), `master` (`e652e55`..`2a80697`) |

---

## Act I: Genesis & The Local-First Prototype (Feb 8 – Feb 13, 2026)

LoopBreaker began on **February 8, 2026** with two foundational commits: `fea3a35` (*"Setting up of app"*) and `1aaaaee` (*"more functionality"*). Five days later, a concentrated **February 13** sprint shaped the core architecture—Flutter frontend, FastAPI backend, local Ollama (`llama3.2:1b`) classification, and Neo4j graph persistence:

- **Rewire P0 foundations (`ce0b1a7`)**: Added sublabel persistence, `intervention_type`, trend/streak UI, and feature flags.
- **Emotion Wheel classification (`5e76c4a`)**: Improved AI emotion classification against the wheel model.
- **Resilience from day one**: Added exponential backoff retry for Neo4j connections (`545d8a3`) and graceful degradation across all database operations (`806dd3a`), alongside E2E smoke tests (`8592559`), explicit console/file logging (`6957d30`), local port stabilization (`843af9a`), an architecture documentation page (`ae01eea`), and a Chrome launch script fix (`42b981d`).

---

## Act II: Engineering Discipline & Personalization (Apr 29 – May 10, 2026)

After a ten-week pause, development resumed on **April 29** with a shift toward testability, observability, and clinical depth:

1. **Phase 1 — Reliability & CI Gating (Apr 29 – May 1)**:
   - Added backend reliability, structured logging with `request_id` threading (`4816323`, `098a0e8`), comprehensive test coverage (`bc88a89`), and CI coverage gates (`a6fd51f`) enforcing `app/ai.py` ≥ 70% and `app/db.py` ≥ 60%.
2. **Shame Protocol, Neuroscience Depth & Loop Path (May 3 – May 4)**:
   - Enhanced the Shame Protocol with Mindful Self-Compassion (MSC) and frequency monitoring (`c8577e6`).
   - Restructured interventions into 3-depth education dictionaries (`1978d68`, `5cbbd2d`, `3cab712`) with an expandable neuroscience explanation in the UI (`65a2013`).
   - Built `get_loop_path()` / `analyze_loop_path()` in the backend (`b43c13e`) and integrated `LoopPathChart` into the History screen (`f4a2cbe`, `fc854ab`).
3. **Phase 2.1 UX Polish (May 8)**:
   - Added interactive risk-level tooltips, enhanced insight cards (`5bce4dc`, `f0c563e`), per-endpoint timeouts (`8cb4d8c`), and error-handling polish (`a8b51c4`).
4. **Personalized Education (May 9 – May 10)**:
   - Introduced `PersonalLoopContext` and `InterventionStats` (`b65f16a`), `get_intervention_effectiveness()` (`b8d9f0e`), and personalized `education_info` text (`a549bd6`) backed by integration and widget tests (`fa09dc9`..`73bf402`).

---

## Act III: Clinical Crisis Safety & The First Wave of Dev Crises (May 10 – May 24, 2026)

"Crisis" in LoopBreaker's history has a dual meaning: the clinical **Crisis Safety Layer** built to protect users in distress, and the **engineering crises** that surfaced as the app grew more complex.

### 1. Building the Crisis Safety Layer (May 10 – May 23)
- **Design & Backend (`6743324`..`8ab8260`)**: Designed a Priority 3 Crisis Safety Layer and implemented `CrisisSafetyService` with keyword detection (`aaef637`), `None`/non-string input validation (`3127fa6`), Neo4j audit logging (`ec26131`), and `/analyze` integration (`03d471d`).
- **Frontend Wiring (`c06af48`, `aa27b0d`, `e97d1db`, `9145ee3`)**: Built `CrisisSafetyDialog` and fixed hotline field names and emergency message sourcing when integrating it into the live analysis flow.

### 2. Phase 4 Movement Protocols & Code Quality Refactor (May 17 – May 22)
- Added movement intervention variants for Stress, Anxiety, Procrastination, Overwhelm, and Numbness (`11b1f40`..`fe62894`), plus a *"Try a different approach"* cycling UI (`b53c207`).
- Branch `phase4-code-quality-refactor` extracted the intervention catalog into a class-level constant, added catalog validation, and reset intervention indices on dialog open (`37fa022`..`e51ad3b`), landing on `master` via merge `a011754` (PR #1 was closed accordingly).

### 3. The May 22–24 Engineering Crises
- **Test Mock Drift (`f185703`, `87650b6`, `4c19793`, `e0dc397`)**: Rapid backend additions broke the test suite because test DB mocks lacked new methods and fixtures didn't initialize `crisis_service`.
- **The Dialog Layout Overflow Crisis (`ffc936c`, `fb72af3`, `f23b512`, `c2ba035`, `7a2be2a`)**: Adding personalization cards inside Flutter's `AlertDialog` triggered `Row` overflows and tight width constraints. Resolving it required adding text ellipsis, removing `maxWidth`, replacing `AlertDialog` with `Dialog`, and hoisting `SingleChildScrollView` to the top level.
- **Schema Ordering & Memory Leak (`7f47021`, `c5c41e7`)**: `AnalysisResponse` referenced `PersonalLoopContext` and `InterventionStats` before they were defined, and `JournalScreen` leaked a `TextEditingController` by missing `.dispose()`.

### 4. Phase 3.2 Recovery Insights (May 24, PR #2)
- From `worktree-phase-3-2-recovery-insights` (PR #2, `0e75bd9`), LoopBreaker gained `GoalService` (`067ac0f`), `StreakBar` (`b9604ba`, `c1d0fdd`), `weekly_activity` in `/insight` (`dbe178c`, `e94bc13`), and the weekly scorecard on `HistoryScreen` (`de6a97f`).

---

## Act IV: Longitudinal Intelligence, CI Breakages & Autumn Reset (May 27 – Nov 2, 2026)

### Phase 6 Backend & Coverage Rescue (May 27)
- `a2836af` implemented Phase 6 depth and longitudinal intelligence via TDD, immediately followed by `d620af2` to fix a missing `datetime` import and restore `db.py` CI coverage.

### Phase 6 Frontend & The CI Infinite-Rebuild Crisis (May 30 – Jun 4)
On branch `feat/phase6-frontend-remaining`, LoopBreaker expanded into a 5-tab app (`HomeShell` adding `Learn` / `LibraryScreen`, `c1f457a`), `WeeklyScorecard` (`2533bc4`), Daily Check-In FAB (`c3b6f76`), and Intervention Guidance with MSC steps and *"This isn't helping"* alternative cycling (PR #3 `a0eecdd`, PR #4 `a4cead3`).

During this push, CI hit two sharp breakages:
- **Infinite Widget Rebuild Loop (`ce70020`, `db8fa88`)**: Creating `Future` objects inside `build()` caused `HistoryScreen` and weekly comparison widgets to loop infinitely during widget tests until those futures were cached in `State` and animations were wrapped in `AnimatedBuilder`.
- **Flutter 3.44 `Material` Assertion (`3a3e281`)**: A Flutter 3.44 upgrade triggered a `ListTile` ancestor assertion in `ExpandableHistoryEntry`, fixed by wrapping the tile in `Material`.

### The 5-Month Pause & Nov 2 Audit (PR #5, `f8e4c8b`)
After `2ede43e` on **June 4**, the repository sat quiet until **November 2, 2026**, when `feat/phase6-frontend-remaining` returned for PR #5 (`f8e4c8b`) with a thorough cleanup and review pass:
- Removed duplicate files and untracked leaked coverage artifacts (`193e425`).
- Fixed incomplete data resets (requiring `X-Confirm-Reset` on the frontend), added `daily-check-correlation`, and enabled Phase 6 feature flags (`c919d0f`, `d6e6477`).
- Persisted onboarding state, surfaced physiological correlates, and added Restlessness zones (`678f124`).

---

## Act V: Daily Practice & Advanced Intelligence (Nov 6 – Nov 12, 2026)

- **Phase 7 — Daily Practice & Identity (`feat/phase7-daily-practice`, PR #6 `b1558a6`, Nov 6–7)**:
  - Added the 3-step Daily Practice ritual, practice streak, and reminder picker (`2a0e961`).
  - Added the Identity & Values layer, values nudge, and 8-node Rewire cycle explainer (`b910812`).
- **Phase 8 — Advanced Intelligence (`feat/phase8-advanced-intelligence`, PR #7 `5e6099d`, Nov 8–12)**:
  - Added Environment Audit, Peak Time Window & Pre-Loop Signal detection, Weekly Narrative generation, and Journey Export (`b2842af`, `f590ffd`).

---

## Act VI: The Hardware Pivot, Cloud Run & Production Crises (Nov 11 – Nov 14, 2026)

The final chapter in the commit log marks LoopBreaker's transition from a local developer setup to a real, phone-installable production web app—and the operational crises that followed.

### 1. The 1 GB RAM Pivot: Gemini API + SQLite + Cloud Run (PR #8, `c835f75`)
Evaluating deployment on a **Raspberry Pi 3 B (1 GB RAM)** made running Ollama (`llama3.2:1b`) and Dockerized Neo4j locally unviable. In response, the backend gained a lightweight dual-mode architecture:
- **AI Pivot (`1267308`, `5752c20`)**: Added `GEMINI_API_KEY` support via the Gemini Interactions API, tuned to `gemini-3.5-flash-lite` with low `thinking_level` for fast interactive classification.
- **Database & Hosting Pivot (PR #8 `c835f75`)**: Added `DB_BACKEND=sqlite` alongside Neo4j, containerized the app for **Google Cloud Run** (`Dockerfile`), fixed `.gcloudignore` so `.gitignore` wouldn't exclude build artifacts from Cloud Build, and added an `APP_PASSCODE` lock screen so the hosted app could remain private.

### 2. Three Production Crises in 48 Hours (Nov 13 – Nov 14)
Once deployed and added to a phone home screen, real usage immediately exposed three subtle production bugs:

1. **The Startup 401 Race Condition (`e652e55`, Nov 13)**:
   - *Symptom*: Protected API calls fired on launch before `PasscodeGate` finished loading or submitting the passcode, producing startup `401` errors.
   - *Fix*: Updated `HomeShell` to reload its data once passcode authentication initializes.
2. **Neo4j AuraDB Free Hibernation (`5fa3c8a`, Nov 13)**:
   - *Symptom*: AuraDB Free instances pause after inactivity, risking cold failures or lost connections in production.
   - *Fix*: Added a `/health?db=true` keep-alive endpoint (paired with Cloud Scheduler), a Cloud Run auto-deploy GitHub Actions workflow, and passcode widget tests.
3. **The "Loops Broken = 0" Mystery (`2a80697`, Nov 14)**:
   - *Symptom*: The History dashboard reported `Loops Broken = 0` even after a user confirmed an intervention had worked.
   - *Root Cause & Fix*: Two bugs combined—`resolve_intervention()` failed to persist feedback outcomes on non-loop entries, and `ApiClient` continued serving stale cached responses after feedback submission. Commit `2a80697` added non-loop outcome persistence and `ApiClient.clearCache()` invalidation.

---

## Repository Snapshot (as of `2a80697`)

- **Total commits on `master`**: 144 (`fea3a35` → `2a80697`)
- **Pull requests**: #1 (closed/superseded by merge `a011754`), #2–#8 (merged)
- **Active branches**: `master` (clean at `2a80697`), plus unpruned feature branches `origin/feat/phase7-daily-practice` (`b910812`) and `feat/phase8-advanced-intelligence`
