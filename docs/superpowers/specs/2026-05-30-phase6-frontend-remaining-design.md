# Phase 6 Frontend — Remaining Items Design

**Date:** 2026-05-30
**Status:** Approved
**Scope:** 4 remaining Phase 6 frontend items not implemented in the original TDD pass

---

## Summary

Four items from the Phase 6 spec were not implemented during the initial backend-focused pass. This design covers all four, extending the existing Flutter frontend without changing any backend code.

---

## 1. API Client Additions (`api_client.dart`)

Three new static methods added to `ApiClient`, following the existing `_withRetry` pattern used by `getLoopPath()`.

| Method | Endpoint | Return | Fallback |
|--------|----------|--------|---------|
| `getWeeklySummary(String weekStart)` | GET `/weekly-summary?week_start=...` | `Map<String,dynamic>` | `{}` |
| `getHistoryDateRange(String start, String end)` | GET `/history?start_date=...&end_date=...&limit=500` | `List<dynamic>` | `[]` |
| `createDailyCheck(Map<String,dynamic> data)` | POST `/daily-check` | `void` | throws |

**Notes:**
- `getWeeklySummary` and `getHistoryDateRange` swallow errors and return empty (same pattern as `getLoopPath`)
- `createDailyCheck` throws on non-201 so the calling dialog can surface a snackbar error
- No cache layer for any of these — weekly summary and date-range history are time-bounded; daily check is a write

---

## 2. Weekly Scorecard Widget (`weekly_scorecard.dart`)

**File:** `frontend/lib/widgets/weekly_scorecard.dart`

A stateless widget that takes `currentWeek` and `previousWeek` as `Map<String,dynamic>`, both sourced from `/weekly-summary`. Displays 3 stat tiles side-by-side with trend arrows.

**Stats shown:**
- **Entries** — `total_entries`
- **Success Rate** — `intervention_success_rate` (shown as `%`)
- **Active Days** — `days_with_entries`

**Trend arrows:** ↑ green / ↓ red / → grey, comparing current value to previous.

**Integration in `history_screen.dart`:**
- Two `FutureBuilder` calls: one for current week (Monday of this week), one for previous week (Monday of last week)
- Drops in below the existing `_buildWeeklyScorecard` dot-tracker
- Separated by a small `"Weekly Comparison"` label
- The existing `_buildWeeklyScorecard` is not modified

**Helper methods on `_HistoryScreenState`:**
```dart
Future<Map<String, dynamic>> _fetchCurrentWeekSummary()   // current Monday
Future<Map<String, dynamic>> _fetchPreviousWeekSummary()  // last Monday
```

---

## 3. Rewire Library Screen (`library_screen.dart`)

**File:** `frontend/lib/screens/library_screen.dart`

A full-screen stateless widget listing all 7 emotional states with expandable 3-level education cards.

**Layout:** `ExpansionTile` per state inside a `ListView`. Multiple states can be open simultaneously (default `ExpansionTile` behaviour — no custom state management needed). Collapsed tile shows the state name and "3 depth levels". Expanded tile shows all three education sections.

**Education section labels and colours:**
- Getting Started — teal (`#5B9B96`)
- Going Deeper — muted indigo (`#7B8BC4`)
- Advanced Understanding — muted purple (`#9B6B96`)

**Education content:** Hardcoded from `interventions.py` — the Flutter client has no `/interventions` endpoint, so content is duplicated in the Dart file. This is intentional: the library is a reference view, not a dynamic feed.

**Navigation:**
- Added as the 5th tab in `home_shell.dart` (`NavigationDestination`)
- Icon: `Icons.menu_book_outlined` / `Icons.menu_book` (selected)
- Label: `'Learn'`
- Inserted between `'My Journal'` and nothing (appended at end)

**All 7 states covered:** Stress, Anxiety, Procrastination, Shame, Overwhelm, Restlessness, Numbness.

---

## 4. Daily Check-In Dialog (`journal_screen.dart`)

**Method added:** `_showDailyCheckIn()` on `_JournalScreenState`

**Trigger:** `FloatingActionButton` (💗 icon, teal) positioned above the existing submit area. Tooltip: `'Daily Check-In'`.

**Dialog inputs:**
| Field | Widget | Range |
|-------|--------|-------|
| Sleep hours | `Slider` (continuous) | 0–12h, 0.5h divisions |
| Hydration | 1–5 tap buttons | 1–5, teal highlight |
| Food quality | 1–5 tap buttons | 1–5, teal highlight |
| Movement minutes | `Slider` (continuous) | 0–180m, 10m divisions |
| Stress level | 1–5 tap buttons | 1–5, **red** highlight (negative scale) |

**Actions:**
- **Skip** — dismisses dialog, no API call
- **Save Check-In** — calls `ApiClient.createDailyCheck(...)`, shows success snackbar on 201, shows error snackbar on exception

**State management:** `StatefulBuilder` inside `showDialog` manages local slider/button state without touching the parent widget's `setState`.

**API method added to `api_client.dart`:** `createDailyCheck` as described in Section 1.

---

## Files Changed

| File | Change |
|------|--------|
| `frontend/lib/services/api_client.dart` | +3 methods |
| `frontend/lib/widgets/weekly_scorecard.dart` | NEW |
| `frontend/lib/screens/library_screen.dart` | NEW |
| `frontend/lib/screens/history_screen.dart` | Add scorecard section + helper methods |
| `frontend/lib/screens/journal_screen.dart` | Add FAB + `_showDailyCheckIn()` |
| `frontend/lib/screens/home_shell.dart` | Add 5th nav tab |

---

## Out of Scope

- Backend changes (all endpoints already implemented)
- Tests (backend tests already cover all new endpoints; Flutter widget tests are a stretch goal)
- `getHistoryDateRange` integration beyond being available for future use (the History screen's existing list uses `fetchHistory`, not date-range; adding a date picker UI is deferred)
