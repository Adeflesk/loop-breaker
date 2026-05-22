# LoopBreaker: Rewire Gap Analysis & Phase 5–8 Roadmap

**Date:** 2026-05-02  
**Status:** Approved  
**Source:** *Rewire* — Nicole Vignola (2024) + full codebase audit  
**Phases 1–4 reference:** `docs/improvement-plan.md` (active through May 2026)

---

## Executive Summary

| # | Book Pillar | App Coverage | Gap Tier | Phase Target |
|---|-------------|-------------|----------|--------------|
| 1 | Neuroscience of habit formation | Partial — static education blurbs only | Tier 2 | Phase 6 |
| 2 | The cycle — mapping YOUR specific loop | Partial — 8-node model vs. 7-node live system | Tier 1 | Phase 5 |
| 3 | Pattern interruption (catch it early, Nodes 1–2) | Partial — only triggers on 3x repetition | Tier 1 | Phase 5 |
| 4 | Cognitive restructuring / Thought Records | **Missing** — no structured record workflow | Tier 1 | Phase 5 |
| 5 | Body-brain connection (sleep/movement/nutrition) | Partial — HALT check is reactive + binary only | Tier 2 | Phase 6 |
| 6 | Emotional regulation toolkit | Partial — one intervention per state, no selection | Tier 2 | Phase 5 |
| 7 | Identity-based change ("I am someone who…") | **Missing** — no values or identity work | Tier 1 | Phase 7 |
| 8 | Environmental design (reduce friction) | **Missing** | Tier 3 | Phase 8 |
| 9 | Self-compassion as exit ramp (Shame node) | Partial — single prompt, no guided sequence | Tier 1 | Phase 5 |
| 10 | Long-term tracking & accountability | Partial — 20-entry cap, no weekly/monthly views | Tier 2 | Phase 6 |
| 11 | Proactive capacity building (daily practice) | **Missing** — app is entirely reactive | Tier 1 | Phase 7 |
| 12 | Social accountability | **Missing** | Tier 3 | Phase 8 |

**Coverage: 3 of 12 pillars adequately covered, 5 partial, 4 missing entirely.**

---

## Current State (Audit Findings)

### What's working
- 8-node loop detection + circuit-breaker pattern (3x repetition trigger)
- AI classification via Ollama (llama3.2) with emotion sublabels stored but not used for routing
- 7 states → interventions: breathing, grounding, cognitive, other (**no movement yet**)
- HALT physiological gate (fires only on High risk + loop_detected)
- Recovery trend, streak, success_rate via `/insight`
- Neo4j graph: `Entry → Node → Intervention → Outcome` (hydration/fuel/rest/movement flags on Outcome)
- Flutter UI: Journal → HALT gate → Intervention dialog → History (pie chart, line chart, entry list)

### Critical inconsistencies found
1. **Model split:** `BehavioralAgent.Modelfile` defines 8 nodes (Stress, Coping Struggle, Procrastination, Neglect Needs, Hypervigilance, Negative Beliefs, Low Self-Esteem, Shame). Live system has 7 different states (Anxiety and Isolation replace 4 of the original nodes). This is a brand integrity issue.
2. **DEFAULT_SUBLABEL mismatch:** `ai.py` returns `"General"`, `rewire-specs.md` specifies `"unspecified"` — breaking inconsistency.
3. **No typed Dart models:** All API responses consumed as raw `Map<String, dynamic>`, zero compile-time safety.
4. **History cap:** `LIMIT 20` hardcoded in `db.py get_history()` — blocks longitudinal analysis.
5. **Movement protocols:** Feature-flagged (`FEATURE_MOVEMENT_PROTOCOLS=false`), skeleton only, zero content.

---

## Tier Classifications

### Tier 1 — Core Gaps (book concepts missing or critically under-implemented)

| ID | Gap | Impact | Complexity |
|----|-----|--------|-----------|
| T1-A | 8-node model reconciliation | High — brand/book fidelity | Low |
| T1-B | Cognitive restructuring / Thought Records | High — book's signature clinical tool | High |
| T1-C | Early-signal pattern interruption (Nodes 1–2) | High — core book thesis | Medium |
| T1-D | Proactive capacity building (daily practices) | High — reactive-only is insufficient per book | High |
| T1-E | Identity-based change / values work | Medium-High — deepest change lever | Medium |
| T1-F | Self-compassion depth for Shame node | Medium-High — most dangerous node, single prompt insufficient | Low |

### Tier 2 — Depth Gaps (present but shallow relative to book treatment)

| ID | Gap | Impact | Complexity |
|----|-----|--------|-----------|
| T2-A | Neuroscience education (progressive, not static) | Medium — engagement + retention | Medium |
| T2-B | Loop path visualization (personal cycle map) | Medium — core book framing | Medium |
| T2-C | Multi-intervention selection per state (sublabel-driven) | Medium — toolkit depth | Low-Medium |
| T2-D | Body-brain proactive tracking (not just reactive HALT) | Medium — neuroplasticity enabler | Medium |
| T2-E | Long-term tracking (weekly/monthly views, export) | Medium — accountability layer | Medium |

### Tier 3 — Advanced/Differentiating

| ID | Gap | Impact | Complexity |
|----|-----|--------|-----------|
| T3-A | Environmental design checklists | Low-Medium | Low |
| T3-B | Social accountability / accountability partner | Low-Medium | Very High |
| T3-C | Biometric/screen-time integration | Medium | Very High |

---

## Phase 5–8 Roadmap

### Phase 5 — Book Fidelity Sprint (Weeks 1–3)

**Goal:** Close highest-impact Tier 1 gaps. App becomes a recognizable implementation of the Rewire framework.

#### 5.1 — 8-Node Model Reconciliation (T1-A)

**Decision required:** Choose between:
- **Option A (Full reconciliation):** Migrate to exact 8-node book model, add Coping Struggle / Hypervigilance / Negative Beliefs / Low Self-Esteem. Requires data migration.
- **Option B (Pragmatic hybrid, recommended):** Keep 7 user-facing states, add a hidden mapping layer positioning each on the 8-node arc for coaching messages and loop position display. No migration.

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-501 | Document model decision and node-arc mapping | `docs/data-model.md` | 2h |
| LB-502 | Update AI system prompt for chosen model | `backend/app/ai.py` | 2h |
| LB-503 | Add `arc_position` to INTERVENTIONS catalog | `backend/app/interventions.py` | 2h |
| LB-504 | Fix DEFAULT_SUBLABEL: `"General"` → `"unspecified"` | `backend/app/ai.py` | 0.5h |
| LB-505 | Surface node position in insight card ("Node 3 of 8") | `frontend/lib/screens/journal_screen.dart` | 2h |

#### 5.2 — Sublabel-Driven Intervention Selection (T2-C)

Sublabels are stored but not used for routing. "Avoidance" and "Perfectionism" (both Procrastination) warrant different techniques.

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-511 | Expand INTERVENTIONS to support sublabel-specific options (2–3 options for 3+ states) | `backend/app/interventions.py` | 3h |
| LB-512 | Update `/analyze` routing: sublabel as secondary key | `backend/app/main.py` | 2h |
| LB-513 | Build "Choose Your Approach" UX (show 2–3 options) | `frontend/lib/screens/journal_screen.dart` | 4h |
| LB-514 | Track chosen variant in Outcome node | `backend/app/db.py`, `backend/app/models.py` | 2h |

#### 5.3 — Cognitive Restructuring / Thought Records (T1-B)

Most significant missing feature. 4-step guided exercise: Situation → Automatic Thought → Evidence For/Against → Balanced Alternative.

**New data model:**
```
(:ThoughtRecord {
  timestamp, situation, automatic_thought,
  evidence_for, evidence_against, balanced_thought, linked_node
})-[:REFRAMES]->(:Entry)
```

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-521 | Add ThoughtRecord Neo4j node + persistence functions | `backend/app/db.py`, `backend/app/models.py` | 3h |
| LB-522 | Add `POST /thought-record` endpoint | `backend/app/main.py` | 2h |
| LB-523 | Add `GET /thought-records` with pagination | `backend/app/main.py`, `backend/app/db.py` | 2h |
| LB-524 | Build 4-step guided flow screen | `frontend/lib/screens/thought_record_screen.dart` (new) | 6h |
| LB-525 | Wire thought record as intervention option for cognitive types | `frontend/lib/screens/journal_screen.dart` | 2h |
| LB-526 | Show thought records in history dashboard | `frontend/lib/screens/history_screen.dart` | 3h |
| LB-527 | Add API client methods | `frontend/lib/services/api_client.dart` | 1h |

#### 5.4 — Enhanced Self-Compassion Protocol for Shame (T1-F)

Replace single-sentence "Compassionate Friend" with a 3-step MSC-informed sequence: Mindfulness → Common Humanity → Self-Kindness.

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-531 | Design 3-step sequence content | `backend/app/interventions.py` | 2h |
| LB-532 | Build multi-step intervention dialog widget | `frontend/lib/screens/journal_screen.dart` or new widget | 4h |
| LB-533 | Add Shame safety flag: if Shame 3+ times in 24h, surface wellbeing resource | `backend/app/db.py`, `backend/app/main.py` | 3h |

**Phase 5 total:** ~45h backend, ~20h frontend ≈ **65h**

---

### Phase 6 — Depth & Longitudinal Intelligence (Weeks 4–6)

**Goal:** Close Tier 2 depth gaps. App moves from session-level support to week-level pattern intelligence.

#### 6.1 — Progressive Neuroscience Education (T2-A)

Static education text shown identically every time. Add depth levels (3 per state) and a standalone library screen.

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-601 | Track `seen_count` on Intervention nodes | `backend/app/db.py` | 1h |
| LB-602 | Expand education content: 3 depth levels per state | `backend/app/interventions.py` | 4h |
| LB-603 | Route education level based on `seen_count` | `backend/app/main.py` | 1h |
| LB-604 | Add "Learn More" expandable section in dialog | `frontend/lib/screens/journal_screen.dart` | 3h |
| LB-605 | Build "Rewire Library" screen (book pillar summaries) | `frontend/lib/screens/library_screen.dart` (new) | 6h |

#### 6.2 — Personal Loop Path Visualization (T2-B)

Neo4j already stores `Entry → Node` with timestamps. Query transition pairs and visualize the user's personal cycle.

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-611 | Add `GET /loop-path` (node transition sequences, last 30 days) | `backend/app/main.py`, `backend/app/db.py` | 3h |
| LB-612 | Build loop path flow visualization widget | `frontend/lib/widgets/loop_path_chart.dart` (new) | 6h |
| LB-613 | Add loop path view to history dashboard | `frontend/lib/screens/history_screen.dart` | 2h |
| LB-614 | Surface "Your most common entry point" on insight card | `frontend/lib/screens/journal_screen.dart` | 2h |

#### 6.3 — Weekly/Monthly Tracking (T2-E)

Remove the 20-entry cap and add date-range queries and week-over-week comparisons.

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-621 | Remove `LIMIT 20`; add date-range params to `/history` | `backend/app/db.py`, `backend/app/main.py` | 2h |
| LB-622 | Add `GET /weekly-summary` (7-day aggregation) | `backend/app/main.py`, `backend/app/db.py` | 3h |
| LB-623 | Build weekly scorecard widget | `frontend/lib/widgets/weekly_scorecard.dart` (new) | 4h |
| LB-624 | Add "this week vs last week" comparison | `frontend/lib/screens/history_screen.dart` | 3h |
| LB-625 | Add data export (CSV/JSON via share sheet) | `frontend/lib/screens/history_screen.dart` | 3h |

#### 6.4 — Proactive Body-Brain Tracking (T2-D)

Add optional daily physiological check-in (5-tap: sleep hours, hydration, food, movement, stress 1–5). Surface longitudinal correlations ("low sleep days → 2x more High-risk loops").

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-631 | Build daily optional check-in screen/dialog | `frontend/lib/screens/` | 4h |
| LB-632 | Add `DailyCheck` Neo4j node + `POST /daily-check` | `backend/app/db.py`, `backend/app/models.py`, `backend/app/main.py` | 3h |
| LB-633 | Correlate DailyCheck state with subsequent loop risk | `backend/app/db.py` | 4h |
| LB-634 | Surface top physiological correlate in insight card | `backend/app/db.py` (insight update) | 3h |
| LB-635 | Complete movement protocol content (Zone 1–3 by node, remove feature flag) | `backend/app/interventions.py` | 2h |

**Phase 6 total:** ~25h backend, ~25h frontend ≈ **50h**

---

### Phase 7 — Identity & Proactive Layer (Weeks 7–9)

**Goal:** Close the two deepest Tier 1 gaps. App transforms from crisis tool to daily resilience platform.

#### 7.1 — Daily Practice Mode / Proactive Capacity Building (T1-D)

The book's entire first section is about building regulatory capacity BEFORE crisis. Zero proactive touchpoints exist.

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-701 | Build Daily Practice screen: 3-min routine (breathing + intention + gratitude) | `frontend/lib/screens/daily_practice_screen.dart` (new) | 6h |
| LB-702 | Add `PracticeSession` Neo4j node + `POST /practice` | `backend/app/db.py`, `backend/app/models.py`, `backend/app/main.py` | 3h |
| LB-703 | Track practice streak separately from intervention streak | `backend/app/db.py`, `frontend/lib/screens/journal_screen.dart` | 3h |
| LB-704 | Add local notification support (`flutter_local_notifications`) | `frontend/pubspec.yaml`, `frontend/lib/` | 4h |
| LB-705 | Allow user to set practice reminder time | `frontend/lib/screens/` | 2h |
| LB-706 | Surface "Days practiced this week" on history dashboard | `frontend/lib/screens/history_screen.dart` | 2h |

#### 7.2 — Identity & Values Layer (T1-E)

Values clarification and "I am someone who…" reframing described as the deepest change lever in the book.

**New data model:** `(:UserProfile {user_id, values: [string], identity_statement: string})`

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-711 | Build values selection onboarding (pick 3–5 from curated list) | `frontend/lib/screens/onboarding_screen.dart` (new) | 5h |
| LB-712 | Add `UserProfile` Neo4j node + persistence | `backend/app/db.py`, `backend/app/models.py` | 3h |
| LB-713 | Add `POST /profile` and `GET /profile` endpoints | `backend/app/main.py` | 2h |
| LB-714 | Surface "I am someone who…" prompt after successful loop break | `frontend/lib/screens/journal_screen.dart` | 3h |
| LB-715 | Show values nudge in insight card ("This loop pulls you away from [value]") | `backend/app/db.py`, `frontend/lib/screens/journal_screen.dart` | 4h |
| LB-716 | Add identity statement to daily practice routine | `frontend/lib/screens/daily_practice_screen.dart` | 2h |

#### 7.3 — Onboarding & Rewire Primer

No onboarding exists. Users land directly on the journal screen with no context about the 8-node framework.

| ID | Task | File | Effort |
|----|------|------|--------|
| LB-721 | Build 4-screen onboarding: What is a loop / Your 8 nodes / How to break it / Values check | `frontend/lib/screens/onboarding_screen.dart` | 5h |
| LB-722 | Gate onboarding with first-run flag (local storage) | `frontend/lib/` | 1h |
| LB-723 | Add "Rewire Your Loop" explainer accessible from app bar | `frontend/lib/screens/library_screen.dart` | 2h |

**Phase 7 total:** ~20h backend, ~40h frontend ≈ **60h**

---

### Phase 8 — Advanced Differentiation (Weeks 10–14)

**Goal:** Tier 3 features, AI-powered pattern intelligence, and optional social features.

#### 8.1 — Environmental Design Toolkit (T3-A)
Build an "Environment Audit" checklist screen. Surface audit prompt when same loop triggers 5+ times.
Files: `frontend/lib/screens/environment_screen.dart` (new), `backend/app/db.py` | ~8h

#### 8.2 — Advanced Pattern Intelligence

| Task | File | Effort |
|------|------|--------|
| Time-of-day pattern analysis in `/insight` | `backend/app/db.py` | 4h |
| Pre-loop signal detection (what state precedes high-risk) | `backend/app/db.py` | 4h |
| Personalized early warning surface | `backend/app/main.py` | 3h |
| AI-generated weekly narrative summary (Ollama) | `backend/app/ai.py` | 5h |

#### 8.3 — Social Accountability (T3-B, opt-in)
Shareable progress card (no full social graph). Full multi-user auth is a separate product track.
Files: `backend/app/main.py`, `frontend/lib/` | ~14h

**Phase 8 total:** ~25h backend, ~15h frontend ≈ **40h**

---

## Effort Summary

| Phase | Duration | Total Estimate |
|-------|----------|---------------|
| Phase 5 (Book Fidelity) | Weeks 1–3 | ~65h |
| Phase 6 (Longitudinal Intelligence) | Weeks 4–6 | ~50h |
| Phase 7 (Identity + Proactive) | Weeks 7–9 | ~60h |
| Phase 8 (Advanced Differentiation) | Weeks 10–14 | ~40h |
| **Total** | **14 weeks** | **~215h** |

At ~15h/week solo developer: 14–15 weeks of effort.

---

## Dependency Graph

```
5.1 (model reconciliation)
  └─► 5.2 (sublabel routing needs updated model)
      └─► 6.1 (progressive education needs state mapping)
      └─► 6.2 (loop path needs consistent node set)

5.3 (thought records) ─► 6.2 (history must show thought records)
5.4 (shame protocol) ─► 7.2 (identity layer adds values connection)

6.3 (weekly tracking) ─► 7.1 (practice streak uses weekly view)
6.4 (physiological tracking) ─► 7.1 (daily practice integrates check-in)

7.1 (daily practice) ─► 7.2 (identity statement in practice routine)
7.3 (onboarding) — deliver at START of Phase 7, gates identity/practice screens

8.3 (social) — requires 7.2 complete; multi-user auth is a blocker
```

**Can run in parallel:** 5.3 alongside 5.1/5.2; 6.1 alongside 6.2; 7.1 alongside 7.2

---

## Key Decisions Required Before Phase 5

1. **Model reconciliation approach** (Option A: full migration vs Option B: pragmatic hybrid mapping — recommend B)
2. **Thought record storage location** (Neo4j backend vs device-local — affects Phase 5.3 entirely)
3. **User identity strategy for Phase 7** (device-generated UUID vs full auth — recommend UUID first)
4. **History data retention** (validate Neo4j performance before removing LIMIT 20)
5. **Book licensing/co-branding** (affects onboarding content in Phase 7.3)

---

## Open Product Questions

1. Should thought records be stored server-side (Neo4j) or device-local (more private)?
2. Should multi-step interventions (Phase 5.4) have a minimum timer before "Done" appears?
3. Is there a plan for official co-branding with Nicole Vignola / the book?
4. Does "streak" count only successful intervention days or any journal activity? (Currently ambiguous in spec)

---

## Critical Files

- `backend/app/interventions.py` — Central to Phases 5.1, 5.2, 5.4, 6.1, 6.4; all routing and content
- `backend/app/db.py` — New node types (ThoughtRecord, DailyCheck, UserProfile, PracticeSession) + all graph queries
- `backend/app/ai.py` — Model reconciliation (5.1), weekly narrative (8.2), DEFAULT_SUBLABEL fix
- `frontend/lib/screens/journal_screen.dart` — Central UX for Phases 5 and 7; sublabel routing, multi-step dialogs, identity prompts
- `docs/data-model.md` — Must be updated before Phase 5 coding to document all new node types
