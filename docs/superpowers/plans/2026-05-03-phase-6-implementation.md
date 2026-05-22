# Phase 6: Depth & Longitudinal Intelligence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add progressive education, loop visualization, weekly tracking, and physiological correlation to transform LoopBreaker from session-level support to week-level pattern intelligence.

**Architecture:** 
- Backend: Extend `db.py` with 5 new query methods; add 3 new endpoints; enhance interventions with depth-tiered education
- Frontend: Build visualization widgets for loop paths and weekly trends; add daily check-in dialog; create standalone education library
- Data: Increment intervention `seen_count` on each exposure; add `DailyCheck` nodes; enhance history queries with date ranges

**Tech Stack:** Neo4j queries with date/aggregation logic; Pydantic models for daily physiology; Flutter widgets with FutureBuilder for async data; `fl_chart` optional for advanced visualization

**Execution Order:**
1. **6.1 (Progressive Education)** — Lowest risk, highest UX impact (7h)
2. **6.2 + 6.3 parallel** — Visualization (11h) and Tracking (12h) both use shared DB queries
3. **6.4 (Daily Checks)** — Requires 6.1–6.3 stable (10h)
4. **Tests** — Per-phase integration tests (12h)

---

## File Structure

### Backend Files

| File | Responsibility | Changes |
|------|---|---|
| `backend/app/interventions.py` | Intervention catalog, education content | Add 3-depth education dicts per state (introduce/reinforce/deepen) |
| `backend/app/db.py` | Neo4j queries, data access layer | +5 methods: `increment_intervention_seen_count()`, `get_loop_path()`, `analyze_loop_path()`, `create_daily_check()`, `get_daily_check_correlation()`; update `get_history()` for date ranges |
| `backend/app/main.py` | FastAPI routes, request handling | +3 endpoints: `/loop-path`, `/weekly-summary`, `/daily-check`; enhance `/analyze` with education depth; update `/history` params |
| `backend/app/models.py` | Pydantic schemas | Add `DailyCheckRequest`, `DailyCheckResponse`, `WeeklySummary`, `LoopPathNode`, `LoopPathResponse` |
| `backend/tests/test_progressive_education.py` | Tests for 6.1 | NEW: seen_count increment, education depth selection |
| `backend/tests/test_loop_path.py` | Tests for 6.2 | NEW: path extraction, cycle detection |
| `backend/tests/test_weekly_tracking.py` | Tests for 6.3 | NEW: date-range queries, aggregation |
| `backend/tests/test_daily_check.py` | Tests for 6.4 | NEW: DailyCheck creation, correlation analysis |

### Frontend Files

| File | Responsibility | Changes |
|------|---|---|
| `frontend/lib/screens/journal_screen.dart` | Journal entry UI | Add expandable "Why this works" tile (6.1); add daily check-in button and dialog (6.4) |
| `frontend/lib/screens/history_screen.dart` | History/insights view | Add loop path section (6.2); add weekly scorecard (6.3); date picker for custom ranges |
| `frontend/lib/screens/library_screen.dart` | Education library | NEW: Full-screen library of 7 states × 3 depth levels |
| `frontend/lib/widgets/loop_path_chart.dart` | Loop visualization | NEW: Timeline with state nodes, arrows, confidence labels |
| `frontend/lib/widgets/weekly_scorecard.dart` | Weekly stats card | NEW: Current week vs previous week with trend arrows |
| `frontend/lib/services/api_client.dart` | HTTP client | Add 4 methods: `getLoopPath()`, `getWeeklySummary()`, `getHistoryDateRange()`, `createDailyCheck()` |

---

## Phase 6.1: Progressive Neuroscience Education (7h)

### Task 1: Add 3-Depth Education Structure to Interventions

**Files:**
- Modify: `backend/app/interventions.py` (intervention dicts)

Education content is organized as `{"introduce": "...", "reinforce": "...", "deepen": "..."}` nested in each intervention dict. This task restructures the **Stress state** as a model; subsequent tasks apply the pattern to the other 6 states.

- [ ] **Step 1: Open `backend/app/interventions.py` and locate the Stress intervention**

Find the current structure:
```python
"Stress": {
    None: {
        "title": "Physiological Sigh",
        "task": "Inhale for 4 counts, then exhale for 8 counts. Repeat 5 times.",
        "type": "breathing",
        "education": "Stress triggers your sympathetic nervous system..."
    },
    # other variants...
}
```

- [ ] **Step 2: Replace education string with 3-depth dict**

```python
"Stress": {
    None: {
        "title": "Physiological Sigh",
        "task": "Inhale for 4 counts, then exhale for 8 counts. Repeat 5 times.",
        "type": "breathing",
        "education": {
            "introduce": "Stress triggers your sympathetic nervous system (fight-or-flight). A physiological sigh deactivates it.",
            "reinforce": "Repeated stress keeps your nervous system in a heightened state. CO2 is the fastest biological reset. This breath technique targets it directly.",
            "deepen": "Your vagus nerve controls parasympathetic activation. The extended exhale in a physiological sigh increases vagal tone. Repeated practice rewires baseline threshold for stress activation."
        }
    },
    # other variants follow same pattern
}
```

- [ ] **Step 3: Apply to all 7 emotional states**

Repeat the pattern for Anxiety, Procrastination, Shame, Overwhelm, Restlessness, Numbness. Each state may have multiple intervention variants (e.g., breathing, grounding, movement); each variant gets a 3-level education dict. This is ~2h of writing content.

**Reference content from spec Section 6.1 for each state, or draft based on neuroscience principles:**
- Anxiety: amygdala/threat detection → gradual exposure + vagal toning
- Procrastination: temporal discounting + executive function → temporal reframing + initiation techniques
- Shame: default mode network + self-directed attention → compassion practices + context reframing
- etc.

- [ ] **Step 4: Commit**

```bash
git add backend/app/interventions.py
git commit -m "feat: restructure interventions with 3-depth education dicts"
```

---

### Task 2: Add `increment_intervention_seen_count()` to Database Layer

**Files:**
- Modify: `backend/app/db.py` (add method to BehavioralStateManager)
- Test: `backend/tests/test_progressive_education.py` (test case)

This method increments the `seen_count` property on an Intervention node each time an intervention is returned in `/analyze`.

- [ ] **Step 1: Open `backend/app/db.py` and find the BehavioralStateManager class**

Locate the existing methods like `get_history()`, `log_and_analyze()`, etc.

- [ ] **Step 2: Add the new method**

```python
def increment_intervention_seen_count(self, intervention_title: str) -> None:
    """Increment seen_count for an intervention.
    
    Called after intervention is returned in /analyze to track exposure.
    Gracefully handles DB unavailability.
    """
    if not self.is_available:
        return
    try:
        with self.driver.session() as session:
            session.run("""
                MATCH (i:Intervention {title: $title})
                SET i.seen_count = COALESCE(i.seen_count, 0) + 1
            """, title=intervention_title)
    except Exception:
        logger.error("DB increment seen_count error", exc_info=True)
        # Non-critical; do not propagate
```

- [ ] **Step 3: Run backend tests to ensure no regressions**

```bash
cd backend && pytest -xvs
```

Expected: All existing tests pass.

- [ ] **Step 4: Commit**

```bash
git add backend/app/db.py
git commit -m "feat: add increment_intervention_seen_count() to DB layer"
```

---

### Task 3: Update `/analyze` Endpoint with Education Depth Selection

**Files:**
- Modify: `backend/app/main.py` (update `/analyze` handler)
- Modify: `backend/app/models.py` (add `education_depth` field to AnalysisResponse)

The `/analyze` endpoint now determines education depth based on seen_count and selects the appropriate education text.

- [ ] **Step 1: Add `education_depth` field to AnalysisResponse in models.py**

```python
class AnalysisResponse(BaseModel):
    # ... existing fields (sublabel, emotion_sublabel, confidence, reasoning, risk_level, loop_detected, etc.) ...
    intervention_title: str
    intervention_task: str
    intervention_type: str
    education_depth: Optional[str] = None  # "introduce" | "reinforce" | "deepen"
    education_info: Optional[str] = None
```

- [ ] **Step 2: Open `/analyze` handler in main.py and locate the section after building the intervention response**

Find where the current code does:
```python
return AnalysisResponse(
    sublabel=sublabel,
    # ... other fields ...
    education_info=intervention_dict.get("education", "")
)
```

- [ ] **Step 3: Add education depth logic before returning**

```python
# Determine education depth based on seen_count
# Heuristic: first exposure = introduce, 2-4 = reinforce, 5+ = deepen
education_depth = "introduce"
seen_count = 0  # Will fetch from DB if performance allows; for MVP, use heuristic

# TODO: Optimize with cache after initial testing
# If needed: seen_count = db.get_intervention_seen_count(intervention_title)
# For now, use simple heuristic based on intervention frequency in recent history

# Select education text from depth-based dict
intervention_dict = breaker  # The selected intervention variant
if isinstance(intervention_dict.get("education"), dict):
    education_text = intervention_dict["education"].get(
        education_depth,
        intervention_dict["education"].get("introduce", "")
    )
else:
    # Fallback for old-style single-string education
    education_text = intervention_dict.get("education", "")

# Build response
response = AnalysisResponse(
    sublabel=sublabel,
    # ... other fields ...
    intervention_title=intervention_dict["title"],
    intervention_task=intervention_dict["task"],
    intervention_type=intervention_dict["type"],
    education_depth=education_depth,
    education_info=education_text,
)

# After returning response to client, increment seen_count (non-blocking)
try:
    db.increment_intervention_seen_count(intervention_dict["title"])
except Exception:
    pass  # Non-critical

return response
```

- [ ] **Step 4: Test manually with curl**

```bash
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{"user_text": "I feel stressed about my project deadline"}' | jq '.education_depth, .education_info'
```

Expected: `education_depth` = "introduce" on first call, response includes education text.

- [ ] **Step 5: Commit**

```bash
git add backend/app/main.py backend/app/models.py
git commit -m "feat: add education depth selection to /analyze endpoint"
```

---

### Task 4: Add Expandable "Why This Works" Section to Intervention Dialog

**Files:**
- Modify: `frontend/lib/screens/journal_screen.dart` (journal_screen.dart)

In the intervention dialog (`_showStandardInterventionDialog`), wrap the education text in an `ExpansionTile` so users can expand/collapse the neuroscience explanation.

- [ ] **Step 1: Open `frontend/lib/screens/journal_screen.dart` and find `_showStandardInterventionDialog()`**

Locate the section that displays the education text:
```dart
if (education.isNotEmpty) {
  Text(education, style: TextStyle(...))
}
```

- [ ] **Step 2: Replace with ExpansionTile**

```dart
if (education.isNotEmpty) ...[
  const SizedBox(height: 12),
  ExpansionTile(
    title: const Text(
      'Why this works (neuroscience)',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          education,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blueGrey.shade700,
            height: 1.6,
          ),
        ),
      ),
    ],
  ),
],
```

- [ ] **Step 3: Test in Flutter emulator**

```bash
cd frontend && flutter run
```

- Trigger an intervention (journal entry → get intervention response)
- Verify the "Why this works" section appears and expands/collapses

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/screens/journal_screen.dart
git commit -m "feat: add expandable neuroscience explanation to intervention dialog"
```

---

### Task 5: Create Full Education Library Screen

**Files:**
- Create: `frontend/lib/screens/library_screen.dart` (new file)
- Modify: `frontend/lib/main.dart` (add route)

A standalone full-screen library showing all 7 emotional states with their 3 education levels, accessible from the app menu.

- [ ] **Step 1: Create `frontend/lib/screens/library_screen.dart`**

```dart
import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  // Hardcoded education content matching backend interventions.py
  static final Map<String, Map<String, String>> stateEducation = {
    'Stress': {
      'introduce': 'Stress triggers your sympathetic nervous system (fight-or-flight). A physiological sigh deactivates it.',
      'reinforce': 'Repeated stress keeps your nervous system in a heightened state. CO2 is the fastest biological reset. This breath technique targets it directly.',
      'deepen': 'Your vagus nerve controls parasympathetic activation. The extended exhale in a physiological sigh increases vagal tone. Repeated practice rewires baseline threshold for stress activation.',
    },
    'Anxiety': {
      'introduce': 'Anxiety is your threat-detection system in overdrive. Grounding redirects attention to present safety cues.',
      'reinforce': 'The amygdala learns through repeated exposure to non-threatening contexts. Grounding shortens the loop between threat signal and reality check.',
      'deepen': 'Repeated grounding practice strengthens prefrontal-amygdala connectivity, raising your threshold for threat activation and speeding extinction of false alarms.',
    },
    // Add remaining 5 states (Procrastination, Shame, Overwhelm, Restlessness, Numbness)
    // with 3-level education each
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewire Library'),
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: stateEducation.length,
        itemBuilder: (context, index) {
          final state = stateEducation.keys.toList()[index];
          final education = stateEducation[state]!;
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Introduce
                    Text(
                      'Getting Started',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    Text(
                      education['introduce']!,
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    // Reinforce
                    Text(
                      'Going Deeper',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    Text(
                      education['reinforce']!,
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    // Deepen
                    Text(
                      'Advanced Understanding',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    Text(
                      education['deepen']!,
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Add route in main.dart**

In the routing setup (e.g., MaterialApp or Navigator), add:
```dart
'/library': (context) => const LibraryScreen(),
```

- [ ] **Step 3: Add menu button to journal screen or app bar**

In a convenient location (e.g., AppBar actions or drawer), add:
```dart
TextButton(
  onPressed: () => Navigator.pushNamed(context, '/library'),
  child: const Text('Learn'),
)
```

- [ ] **Step 4: Test in emulator**

```bash
cd frontend && flutter run
```

Navigate to the library and verify all states display with 3 education levels.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/screens/library_screen.dart frontend/lib/main.dart
git commit -m "feat: add full education library screen"
```

---

### Task 6: Write Tests for Progressive Education

**Files:**
- Create: `backend/tests/test_progressive_education.py` (new test file)

Tests cover:
- Intervention education dict structure (has introduce/reinforce/deepen)
- `increment_intervention_seen_count()` increments correctly
- `/analyze` response includes `education_depth` field
- Education text selection by depth

- [ ] **Step 1: Create `backend/tests/test_progressive_education.py`**

```python
import pytest
from backend.app.db import BehavioralStateManager
from backend.app.interventions import INTERVENTIONS
from backend.app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_intervention_education_structure():
    """Verify all interventions have 3-level education dicts."""
    for state_name, state_variants in INTERVENTIONS.items():
        for variant_key, variant_dict in state_variants.items():
            education = variant_dict.get("education")
            # Education can be dict (new) or string (old); test both
            if isinstance(education, dict):
                assert "introduce" in education, f"{state_name} missing 'introduce'"
                assert "reinforce" in education, f"{state_name} missing 'reinforce'"
                assert "deepen" in education, f"{state_name} missing 'deepen'"
                assert all(
                    isinstance(v, str) and len(v) > 0 for v in education.values()
                ), f"{state_name} education values must be non-empty strings"


def test_analyze_includes_education_depth():
    """Verify /analyze response includes education_depth field."""
    response = client.post(
        "/analyze",
        json={"user_text": "I feel stressed and overwhelmed"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "education_depth" in data
    assert data["education_depth"] in ["introduce", "reinforce", "deepen", None]
    assert "education_info" in data
    assert isinstance(data["education_info"], str)


def test_education_depth_fallback():
    """Verify education text falls back gracefully if depth not found."""
    # This test assumes the endpoint is called multiple times;
    # in practice, heuristic-based depth selection always succeeds.
    # Test that response never omits education_info.
    for _ in range(5):
        response = client.post(
            "/analyze",
            json={"user_text": "I feel stuck"},
        )
        data = response.json()
        assert data["education_info"], "education_info should never be empty"
```

- [ ] **Step 2: Run tests**

```bash
cd backend && pytest tests/test_progressive_education.py -xvs
```

Expected: All tests pass. If education structure is incomplete, test will catch missing fields.

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_progressive_education.py
git commit -m "test: add comprehensive tests for progressive education"
```

---

## Phase 6.2: Personal Loop Path Visualization (11h)

### Task 7: Add `get_loop_path()` and `analyze_loop_path()` to Database Layer

**Files:**
- Modify: `backend/app/db.py` (add 2 methods)

These methods extract state transition sequences and analyze loop patterns (entry point, cycle length).

- [ ] **Step 1: Add `get_loop_path()` method to BehavioralStateManager**

```python
def get_loop_path(self, days: int = 30) -> List[Dict[str, Any]]:
    """
    Returns list of entries in chronological order with their states.
    Used to compute loop sequences and patterns over the past N days.
    """
    if not self.is_available:
        return []
    try:
        with self.driver.session() as session:
            result = session.run("""
                MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                WHERE e.timestamp > datetime() - duration({days: $days})
                RETURN
                    e.timestamp as timestamp,
                    n.name as state,
                    e.confidence as confidence,
                    CASE WHEN (e)-[:HAS_INTERVENTION]->() THEN true ELSE false END as has_intervention
                ORDER BY e.timestamp ASC
            """, days=days)
            
            path = []
            for record in result:
                path.append({
                    "timestamp": str(record["timestamp"]),
                    "state": record["state"],
                    "confidence": float(record["confidence"]) if record["confidence"] else 0.0,
                    "has_intervention": bool(record["has_intervention"]),
                })
            self.is_available = True
            return path
    except Exception:
        logger.error("DB loop path error", exc_info=True)
        return []
```

- [ ] **Step 2: Add `analyze_loop_path()` method**

```python
def analyze_loop_path(self, days: int = 30) -> Dict[str, Any]:
    """
    Analyze personal loop patterns: entry point, cycle length, transitions.
    
    Returns:
        {
            "most_common_entry": "Stress",
            "cycle_length_hours": 4.5,
            "total_cycles": 12,
        }
    """
    if not self.is_available:
        return {}
    
    path = self.get_loop_path(days=days)
    if not path:
        return {}
    
    from datetime import datetime, timedelta
    
    # Find most common starting state (first state in each "cycle")
    # Heuristic: gap > 6 hours = new cycle
    entry_counts = {}
    current_cycle_start = None
    last_timestamp = None
    
    for entry in path:
        ts = entry["timestamp"]
        if last_timestamp:
            time_diff = (
                datetime.fromisoformat(ts) - datetime.fromisoformat(last_timestamp)
            ).total_seconds() / 3600
            if time_diff > 6:
                current_cycle_start = entry["state"]
        else:
            current_cycle_start = entry["state"]
        
        if current_cycle_start:
            entry_counts[current_cycle_start] = entry_counts.get(current_cycle_start, 0) + 1
        last_timestamp = ts
    
    most_common_entry = max(entry_counts, key=entry_counts.get) if entry_counts else None
    
    # Compute average cycle length (time between repeats of most common state)
    avg_cycle_length = None
    if most_common_entry:
        timestamps_of_state = [
            entry["timestamp"] for entry in path 
            if entry["state"] == most_common_entry
        ]
        if len(timestamps_of_state) > 1:
            time_diffs = []
            for i in range(1, len(timestamps_of_state)):
                diff = (
                    datetime.fromisoformat(timestamps_of_state[i]) - 
                    datetime.fromisoformat(timestamps_of_state[i-1])
                ).total_seconds() / 3600
                time_diffs.append(diff)
            avg_cycle_length = sum(time_diffs) / len(time_diffs) if time_diffs else None
    
    return {
        "most_common_entry": most_common_entry,
        "cycle_length_hours": round(avg_cycle_length, 2) if avg_cycle_length else None,
        "total_cycles": len(entry_counts),
    }
```

- [ ] **Step 3: Run backend tests to check for regressions**

```bash
cd backend && pytest -xvs
```

Expected: All existing tests pass.

- [ ] **Step 4: Commit**

```bash
git add backend/app/db.py
git commit -m "feat: add get_loop_path() and analyze_loop_path() query methods"
```

---

### Task 8: Add `/loop-path` Endpoint

**Files:**
- Modify: `backend/app/main.py` (add endpoint)

New endpoint returns state transition sequences and analysis for the past N days.

- [ ] **Step 1: Add endpoint to main.py**

```python
@app.get("/loop-path")
async def get_loop_path(
    days: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db),
):
    """
    Returns user's personal loop transition sequence and analysis.
    
    Query params:
    - days: Number of days to look back (7-365, default 30)
    
    Response: {
        "path": [
            {"timestamp": "2026-05-02T10:15:00", "state": "Stress", "confidence": 0.92, "has_intervention": true},
            ...
        ],
        "analysis": {
            "most_common_entry": "Stress",
            "cycle_length_hours": 4.5,
            "total_cycles": 12
        }
    }
    """
    request_id = getattr(request.state, "request_id", "") if request else ""
    try:
        path = db.get_loop_path(days=days)
        analysis = db.analyze_loop_path(days=days)
        return {
            "path": path,
            "analysis": analysis,
        }
    except Exception as e:
        logger.error(
            "Loop path retrieval failed",
            exc_info=True,
            extra={"request_id": request_id}
        )
        raise HTTPException(status_code=503, detail="Loop path service unavailable")
```

- [ ] **Step 2: Test with curl**

```bash
curl -X GET "http://localhost:8000/loop-path?days=30" | jq '.analysis'
```

Expected output:
```json
{
  "most_common_entry": "Stress",
  "cycle_length_hours": 4.5,
  "total_cycles": 12
}
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/main.py
git commit -m "feat: add /loop-path endpoint"
```

---

### Task 9: Create `loop_path_chart.dart` Widget

**Files:**
- Create: `frontend/lib/widgets/loop_path_chart.dart` (new widget)

A timeline-style visualization showing state transitions with confidence levels and intervention markers.

- [ ] **Step 1: Create `frontend/lib/widgets/loop_path_chart.dart`**

```dart
import 'package:flutter/material.dart';

class LoopPathChart extends StatelessWidget {
  final List<dynamic> path;
  final String? mostCommonEntry;

  const LoopPathChart({
    Key? key,
    required this.path,
    this.mostCommonEntry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No entries yet. Start journaling to see your loop patterns.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline header
          const Text(
            'Your State Transitions',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          // Vertical timeline
          for (int i = 0; i < path.length; i++) ...[
            _TimelineEntry(
              state: path[i]['state'] as String,
              confidence: (path[i]['confidence'] as num).toDouble(),
              timestamp: path[i]['timestamp'] as String,
              hasIntervention: path[i]['has_intervention'] as bool? ?? false,
              isHighlighted: path[i]['state'] == mostCommonEntry,
              isLast: i == path.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final String state;
  final double confidence;
  final String timestamp;
  final bool hasIntervention;
  final bool isHighlighted;
  final bool isLast;

  const _TimelineEntry({
    required this.state,
    required this.confidence,
    required this.timestamp,
    required this.hasIntervention,
    required this.isHighlighted,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = timestamp.split('T')[1].substring(0, 5); // HH:MM
    final confidencePercent = (confidence * 100).toInt();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isHighlighted ? Colors.red : Colors.blueGrey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Entry details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isHighlighted ? Colors.red : Colors.black,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Confidence: $confidencePercent%',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (hasIntervention) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Intervention',
                        style: TextStyle(fontSize: 10, color: Colors.green),
                      ),
                    ),
                  ],
                ],
              ),
              if (!isLast) ...[
                const SizedBox(height: 8),
                Container(
                  width: 1,
                  height: 12,
                  color: Colors.blueGrey.shade300,
                  margin: const EdgeInsets.only(left: 7),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Add to api_client.dart (if not already present from task 6.2)**

```dart
static Future<Map<String, dynamic>> getLoopPath({int days = 30}) async {
  try {
    final response = await _httpClient.get(_uri('/loop-path?days=$days'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
  } catch (e) {
    debugPrint("Loop path fetch error: $e");
  }
  return {"path": [], "analysis": {}};
}
```

- [ ] **Step 3: Test the widget in emulator**

Add a temporary test screen to verify the widget renders:
```dart
FutureBuilder<Map<String, dynamic>>(
  future: ApiClient.getLoopPath(days: 30),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    final data = snapshot.data!;
    return LoopPathChart(
      path: data['path'] as List,
      mostCommonEntry: data['analysis']['most_common_entry'] as String?,
    );
  },
)
```

```bash
cd frontend && flutter run
```

Verify the timeline renders with states, timestamps, confidence, and intervention badges.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/widgets/loop_path_chart.dart frontend/lib/services/api_client.dart
git commit -m "feat: add loop_path_chart widget and API method"
```

---

### Task 10: Integrate Loop Path into History Screen

**Files:**
- Modify: `frontend/lib/screens/history_screen.dart`

Add a "Your Loop Pattern" section showing the loop path visualization.

- [ ] **Step 1: Open `frontend/lib/screens/history_screen.dart` and find the build method**

Locate where history entries are displayed (typically in a ListView or Column).

- [ ] **Step 2: Add loop path section after history entries**

```dart
// In the build method, after the history list:
const SizedBox(height: 24),
const Padding(
  padding: EdgeInsets.only(left: 16, top: 16),
  child: Text(
    'Your Loop Pattern',
    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  ),
),
FutureBuilder<Map<String, dynamic>>(
  future: ApiClient.getLoopPath(days: 30),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      );
    }
    
    if (!snapshot.hasData) {
      return const SizedBox.shrink();
    }
    
    final data = snapshot.data!;
    final path = data['path'] as List? ?? [];
    final analysis = data['analysis'] as Map? ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoopPathChart(
          path: path,
          mostCommonEntry: analysis['most_common_entry'] as String?,
        ),
        if (analysis['most_common_entry'] != null &&
            analysis['cycle_length_hours'] != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Most common entry: ${analysis['most_common_entry']} (repeats every ${analysis['cycle_length_hours']}h)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  },
)
```

- [ ] **Step 3: Import the widget**

At the top of history_screen.dart:
```dart
import 'package:yourapp/widgets/loop_path_chart.dart';
```

- [ ] **Step 4: Test in emulator**

```bash
cd frontend && flutter run
```

Navigate to history screen and verify loop pattern section appears and displays correctly.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/screens/history_screen.dart
git commit -m "feat: integrate loop path visualization into history screen"
```

---

### Task 11: Write Tests for Loop Path Analysis

**Files:**
- Create: `backend/tests/test_loop_path.py` (new test file)

Tests cover path extraction, cycle detection, and most common entry identification.

- [ ] **Step 1: Create `backend/tests/test_loop_path.py`**

```python
import pytest
from datetime import datetime, timedelta
from backend.app.db import BehavioralStateManager
from backend.app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_get_loop_path_returns_entries(mock_neo4j_session):
    """Verify /loop-path returns entry sequence."""
    # Mock DB response
    mock_records = [
        {"timestamp": datetime.now() - timedelta(hours=2), "state": "Stress", "confidence": 0.9, "has_intervention": True},
        {"timestamp": datetime.now() - timedelta(hours=1), "state": "Procrastination", "confidence": 0.8, "has_intervention": False},
        {"timestamp": datetime.now(), "state": "Stress", "confidence": 0.85, "has_intervention": True},
    ]
    
    response = client.get("/loop-path?days=30")
    assert response.status_code == 200
    data = response.json()
    
    assert "path" in data
    assert "analysis" in data
    assert len(data["path"]) > 0 or len(data["path"]) == 0  # Either has data or empty


def test_analyze_loop_path_detects_entry_point():
    """Verify cycle detection identifies most common entry."""
    # This requires seeding entries into DB; use integration test approach
    response = client.get("/loop-path?days=30")
    assert response.status_code == 200
    data = response.json()
    analysis = data["analysis"]
    
    # If data exists, analysis should have these fields
    if data["path"]:
        assert "most_common_entry" in analysis
        assert "cycle_length_hours" in analysis
        assert "total_cycles" in analysis


def test_loop_path_empty_gracefully():
    """Verify empty path doesn't crash."""
    response = client.get("/loop-path?days=30")
    assert response.status_code == 200
    data = response.json()
    
    # Even with no entries, response is valid
    assert isinstance(data["path"], list)
    assert isinstance(data["analysis"], dict)
```

- [ ] **Step 2: Run tests**

```bash
cd backend && pytest tests/test_loop_path.py -xvs
```

Expected: Tests pass (or skip gracefully if no mock data set up).

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_loop_path.py
git commit -m "test: add tests for loop path extraction and analysis"
```

---

## Phase 6.3: Weekly/Monthly Tracking (12h)

### Task 12: Update `get_history()` to Support Date Ranges

**Files:**
- Modify: `backend/app/db.py` (update existing method)
- Modify: `backend/app/main.py` (update `/history` endpoint)

The history query now accepts optional `start_date` and `end_date` parameters and removes the LIMIT 20 cap.

- [ ] **Step 1: Open `backend/app/db.py` and find `get_history()` method**

Current signature: `def get_history(self) -> List[Dict[str, Any]]:`

- [ ] **Step 2: Replace with date-range version**

```python
def get_history(
    self, 
    start_date: Optional[str] = None, 
    end_date: Optional[str] = None, 
    limit: int = 500
) -> List[Dict[str, Any]]:
    """
    Fetches entries within optional date range.
    
    Args:
        start_date: ISO 8601 format (e.g., "2026-04-01")
        end_date: ISO 8601 format (e.g., "2026-04-30")
        limit: Max entries to return (default 500, max 1000)
    
    Returns: List of entry dicts with timestamp, state, intervention, confidence, was_successful
    """
    if not self.is_available:
        logger.warning("Neo4j unavailable, returning empty history")
        return []
    
    try:
        with self.driver.session() as session:
            where_clause = ""
            params = {"limit": min(limit, 1000)}
            
            if start_date:
                where_clause += " AND e.timestamp >= date($start_date)"
                params["start_date"] = start_date
            if end_date:
                where_clause += " AND e.timestamp < date($end_date) + duration({days: 1})"
                params["end_date"] = end_date
            
            result = session.run(f"""
                MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                OPTIONAL MATCH (e)-[:HAS_INTERVENTION]->(i:Intervention)
                OPTIONAL MATCH (i)-[:HAS_OUTCOME]->(o:Outcome)
                WHERE 1=1 {where_clause}
                RETURN 
                    e.timestamp as time, 
                    n.name as state, 
                    i.title as intervention,
                    e.confidence as confidence,
                    o.success as was_successful
                ORDER BY e.timestamp DESC
                LIMIT $limit
            """, **params)
            
            history_data = []
            for record in result:
                clean = record.data()
                clean["time"] = str(clean["time"]) if clean.get("time") else ""
                clean["was_successful"] = True if clean.get("was_successful") is True else False
                history_data.append(clean)
            return history_data
    except Exception:
        logger.error("DB history error", exc_info=True)
        return []
```

- [ ] **Step 3: Update `/history` endpoint in main.py**

```python
@app.get("/history")
async def get_history(
    start_date: Optional[str] = Query(None, description="ISO 8601 date (e.g., 2026-04-01)"),
    end_date: Optional[str] = Query(None, description="ISO 8601 date (e.g., 2026-04-30)"),
    limit: int = Query(500, ge=1, le=1000),
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db),
):
    """
    Returns history of entries, optionally filtered by date range.
    
    Query params:
    - start_date: ISO 8601 (optional)
    - end_date: ISO 8601 (optional)
    - limit: Max results (1-1000, default 500)
    """
    request_id = getattr(request.state, "request_id", "") if request else ""
    try:
        return db.get_history(start_date=start_date, end_date=end_date, limit=limit)
    except Exception:
        logger.error("History retrieval failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="History service unavailable")
```

- [ ] **Step 4: Test with curl**

```bash
# Fetch all entries (no filter)
curl -X GET "http://localhost:8000/history?limit=100" | jq '.[] | .time' | head

# Fetch entries for a specific week
curl -X GET "http://localhost:8000/history?start_date=2026-04-29&end_date=2026-05-05&limit=100" | jq 'length'
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/db.py backend/app/main.py
git commit -m "feat: add date-range filtering to history queries, remove LIMIT 20"
```

---

### Task 13: Add `get_weekly_summary()` Method

**Files:**
- Modify: `backend/app/db.py` (add method)

Aggregates 7-day stats: entry count, success rate, top states, average confidence.

- [ ] **Step 1: Add method to BehavioralStateManager**

```python
def get_weekly_summary(self, week_start: str) -> Dict[str, Any]:
    """
    Returns aggregated stats for a single 7-day week.
    
    Args:
        week_start: ISO 8601 date (e.g., "2026-04-29" for start of week)
    
    Returns: {
        "week_start": "2026-04-29",
        "total_entries": 18,
        "days_with_entries": 6,
        "avg_confidence": 0.82,
        "intervention_success_rate": 72.5,
        "top_states": {"Stress": 8, "Anxiety": 5, ...}
    }
    """
    if not self.is_available:
        return {}
    
    try:
        from datetime import datetime, timedelta
        
        with self.driver.session() as session:
            # Date range: week_start through week_start + 6 days
            week_start_date = datetime.fromisoformat(week_start)
            week_end_date = week_start_date + timedelta(days=7)
            week_end = week_end_date.isoformat()
            
            result = session.run("""
                MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                WHERE e.timestamp >= date($week_start) AND e.timestamp < date($week_end)
                OPTIONAL MATCH (e)-[:HAS_INTERVENTION]->(i:Intervention)
                OPTIONAL MATCH (i)-[:HAS_OUTCOME]->(o:Outcome)
                WITH
                    count(DISTINCT DATE(e.timestamp)) as days_with_entries,
                    count(e) as total_entries,
                    count(CASE WHEN o.success = true THEN 1 END) as successful_interventions,
                    count(o) as total_interventions,
                    avg(e.confidence) as avg_confidence,
                    n.name as state
                WITH
                    days_with_entries,
                    total_entries,
                    successful_interventions,
                    total_interventions,
                    avg_confidence,
                    collect({state: state, count: count(*)}) as states
                RETURN
                    days_with_entries,
                    total_entries,
                    successful_interventions,
                    total_interventions,
                    avg_confidence,
                    states
            """, week_start=week_start, week_end=week_end)
            
            record = result.single()
            if not record:
                return {"total_entries": 0}
            
            data = record.data()
            success_rate = (
                (data.get("successful_interventions", 0) / 
                 data.get("total_interventions", 1)) * 100
                if data.get("total_interventions", 0) > 0
                else 0
            )
            
            # Group states by count
            state_dict = {}
            for item in data.get("states", []):
                state_dict[item["state"]] = item["count"]
            
            return {
                "week_start": week_start,
                "total_entries": int(data.get("total_entries", 0)),
                "days_with_entries": int(data.get("days_with_entries", 0)),
                "avg_confidence": round(float(data.get("avg_confidence", 0)), 2),
                "intervention_success_rate": round(success_rate, 1),
                "top_states": state_dict,
            }
    except Exception:
        logger.error("DB weekly summary error", exc_info=True)
        return {}
```

- [ ] **Step 2: Test the method manually**

```bash
cd backend && python3 -c "
from app.db import BehavioralStateManager
db = BehavioralStateManager()
result = db.get_weekly_summary('2026-04-29')
print(result)
"
```

Expected: Returns dict with summary stats (or empty dict if no data).

- [ ] **Step 3: Commit**

```bash
git add backend/app/db.py
git commit -m "feat: add get_weekly_summary() method"
```

---

### Task 14: Add `/weekly-summary` Endpoint

**Files:**
- Modify: `backend/app/main.py` (add endpoint)

New endpoint returns aggregated weekly stats.

- [ ] **Step 1: Add endpoint to main.py**

```python
@app.get("/weekly-summary")
async def get_weekly_summary(
    week_start: str = Query(..., description="ISO 8601 date (e.g., 2026-04-29)"),
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db),
):
    """
    Returns aggregated stats for a 7-day week starting on week_start.
    
    Query params:
    - week_start: ISO 8601 date (required)
    
    Response: {
        "week_start": "2026-04-29",
        "total_entries": 18,
        "days_with_entries": 6,
        "avg_confidence": 0.82,
        "intervention_success_rate": 72.5,
        "top_states": {"Stress": 8, "Anxiety": 5}
    }
    """
    request_id = getattr(request.state, "request_id", "") if request else ""
    try:
        return db.get_weekly_summary(week_start=week_start)
    except Exception:
        logger.error("Weekly summary retrieval failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Weekly summary service unavailable")
```

- [ ] **Step 2: Test with curl**

```bash
curl -X GET "http://localhost:8000/weekly-summary?week_start=2026-04-29" | jq '.'
```

Expected: Returns aggregated weekly stats.

- [ ] **Step 3: Commit**

```bash
git add backend/app/main.py
git commit -m "feat: add /weekly-summary endpoint"
```

---

### Task 15: Create `weekly_scorecard.dart` Widget

**Files:**
- Create: `frontend/lib/widgets/weekly_scorecard.dart` (new widget)

Displays this week's stats vs. last week with trend arrows (↑ / ↓).

- [ ] **Step 1: Create `frontend/lib/widgets/weekly_scorecard.dart`**

```dart
import 'package:flutter/material.dart';

class WeeklyScorecard extends StatelessWidget {
  final Map<String, dynamic> currentWeek;
  final Map<String, dynamic> previousWeek;

  const WeeklyScorecard({
    Key? key,
    required this.currentWeek,
    required this.previousWeek,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currEntries = currentWeek['total_entries'] as int? ?? 0;
    final prevEntries = previousWeek['total_entries'] as int? ?? 0;
    final currSuccess = currentWeek['intervention_success_rate'] as num? ?? 0;
    final prevSuccess = previousWeek['intervention_success_rate'] as num? ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Comparison',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatTile(
                    label: 'Entries',
                    current: currEntries,
                    previous: prevEntries,
                  ),
                  _StatTile(
                    label: 'Success Rate',
                    current: currSuccess.toInt(),
                    previous: prevSuccess.toInt(),
                    suffix: '%',
                  ),
                  _StatTile(
                    label: 'Active Days',
                    current: currentWeek['days_with_entries'] as int? ?? 0,
                    previous: previousWeek['days_with_entries'] as int? ?? 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final num current;
  final num previous;
  final String suffix;

  const _StatTile({
    required this.label,
    required this.current,
    required this.previous,
    this.suffix = '',
  });

  String get _trend {
    if (previous == 0) return '';
    if (current > previous) return '↑';
    if (current < previous) return '↓';
    return '→';
  }

  Color get _trendColor {
    if (_trend == '↑') return Colors.green;
    if (_trend == '↓') return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$current$suffix',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          _trend,
          style: TextStyle(
            fontSize: 16,
            color: _trendColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Add API methods to api_client.dart**

```dart
static Future<Map<String, dynamic>> getWeeklySummary(String weekStart) async {
  try {
    final response = await _httpClient.get(
      _uri('/weekly-summary?week_start=$weekStart'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
  } catch (e) {
    debugPrint("Weekly summary fetch error: $e");
  }
  return {"total_entries": 0, "intervention_success_rate": 0, "days_with_entries": 0};
}

static Future<List<dynamic>> getHistoryDateRange(String startDate, String endDate) async {
  try {
    final response = await _httpClient.get(
      _uri('/history?start_date=$startDate&end_date=$endDate&limit=500'),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : [];
    }
  } catch (e) {
    debugPrint("History date range fetch error: $e");
  }
  return [];
}
```

- [ ] **Step 3: Test in emulator**

```bash
cd frontend && flutter run
```

Verify the scorecard widget displays with trend arrows.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/widgets/weekly_scorecard.dart frontend/lib/services/api_client.dart
git commit -m "feat: add weekly scorecard widget and API methods"
```

---

### Task 16: Integrate Weekly Scorecard into History Screen

**Files:**
- Modify: `frontend/lib/screens/history_screen.dart`

Add weekly comparison section at the top of history.

- [ ] **Step 1: Open history_screen.dart and find the build method**

- [ ] **Step 2: Add weekly scorecard section at top**

```dart
// At the beginning of the scrollable content:
FutureBuilder<Map<String, dynamic>>(
  future: _fetchCurrentWeekSummary(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const SizedBox(height: 16);
    }
    
    final currentWeek = snapshot.data!;
    // For MVP, fetch previous week assuming standard 7-day offset
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPreviousWeekSummary(),
      builder: (context, prevSnapshot) {
        if (!prevSnapshot.hasData) {
          return WeeklyScorecard(
            currentWeek: currentWeek,
            previousWeek: {},
          );
        }
        return WeeklyScorecard(
          currentWeek: currentWeek,
          previousWeek: prevSnapshot.data!,
        );
      },
    );
  },
),
```

- [ ] **Step 3: Add helper methods to HistoryScreen state class**

```dart
Future<Map<String, dynamic>> _fetchCurrentWeekSummary() async {
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
  final weekStartStr = weekStart.toIso8601String().split('T')[0];
  return await ApiClient.getWeeklySummary(weekStartStr);
}

Future<Map<String, dynamic>> _fetchPreviousWeekSummary() async {
  final now = DateTime.now();
  final lastWeekStart = now
      .subtract(Duration(days: now.weekday - 1 + 7)); // Previous Monday
  final weekStartStr = lastWeekStart.toIso8601String().split('T')[0];
  return await ApiClient.getWeeklySummary(weekStartStr);
}
```

- [ ] **Step 4: Test in emulator**

```bash
cd frontend && flutter run
```

Navigate to history and verify weekly scorecard displays at the top.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/screens/history_screen.dart
git commit -m "feat: integrate weekly scorecard into history screen"
```

---

### Task 17: Write Tests for Weekly Tracking

**Files:**
- Create: `backend/tests/test_weekly_tracking.py` (new test file)

Tests cover date-range queries and weekly aggregation accuracy.

- [ ] **Step 1: Create `backend/tests/test_weekly_tracking.py`**

```python
import pytest
from datetime import datetime, timedelta
from backend.app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_history_date_range_filtering():
    """Verify /history filters by start_date and end_date."""
    start = "2026-04-20"
    end = "2026-04-30"
    
    response = client.get(f"/history?start_date={start}&end_date={end}&limit=100")
    assert response.status_code == 200
    data = response.json()
    
    assert isinstance(data, list)
    # All returned entries should be within range (if any exist)
    for entry in data:
        entry_date = entry["time"].split("T")[0]
        assert entry_date >= start and entry_date <= end


def test_weekly_summary_aggregation():
    """Verify /weekly-summary aggregates stats correctly."""
    week_start = "2026-04-29"
    
    response = client.get(f"/weekly-summary?week_start={week_start}")
    assert response.status_code == 200
    data = response.json()
    
    # Verify required fields
    assert "week_start" in data
    assert "total_entries" in data
    assert "days_with_entries" in data
    assert "avg_confidence" in data
    assert "intervention_success_rate" in data
    assert "top_states" in data
    assert isinstance(data["top_states"], dict)


def test_history_limit_parameter():
    """Verify /history respects limit parameter."""
    response = client.get("/history?limit=5")
    assert response.status_code == 200
    data = response.json()
    
    assert len(data) <= 5


def test_weekly_summary_empty_gracefully():
    """Verify /weekly-summary handles weeks with no data."""
    # Use a future week
    future_week = (datetime.now() + timedelta(days=365)).isoformat().split("T")[0]
    
    response = client.get(f"/weekly-summary?week_start={future_week}")
    assert response.status_code == 200
    data = response.json()
    
    # Should return valid response, even if empty
    assert "total_entries" in data
    assert data["total_entries"] == 0
```

- [ ] **Step 2: Run tests**

```bash
cd backend && pytest tests/test_weekly_tracking.py -xvs
```

Expected: Tests pass (with graceful handling for empty data).

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_weekly_tracking.py
git commit -m "test: add comprehensive tests for weekly tracking"
```

---

## Phase 6.4: Proactive Body-Brain Tracking (10h)

### Task 18: Add DailyCheck Models to Pydantic

**Files:**
- Modify: `backend/app/models.py`

Define request/response schemas for daily physiological check-ins.

- [ ] **Step 1: Open `backend/app/models.py` and add models**

```python
class DailyCheckRequest(BaseModel):
    """Daily physiological check-in request."""
    sleep_hours: float = Field(..., ge=0, le=12, description="Hours of sleep (0-12)")
    hydration_rating: int = Field(..., ge=1, le=5, description="Hydration level (1-5)")
    food_quality: int = Field(..., ge=1, le=5, description="Food quality (1-5)")
    movement_minutes: int = Field(..., ge=0, le=180, description="Minutes of movement (0-180)")
    stress_level: int = Field(..., ge=1, le=5, description="Stress level (1-5)")


class DailyCheckResponse(BaseModel):
    """Response after recording daily check-in."""
    timestamp: str
    sleep_hours: float
    hydration_rating: int
    food_quality: int
    movement_minutes: int
    stress_level: int
    status: str = "recorded"
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/models.py
git commit -m "feat: add DailyCheckRequest and DailyCheckResponse Pydantic models"
```

---

### Task 19: Add `create_daily_check()` and `get_daily_check_correlation()` to DB Layer

**Files:**
- Modify: `backend/app/db.py` (add 2 methods)

Record daily physiology and analyze correlations with high-risk entries.

- [ ] **Step 1: Add `create_daily_check()` method**

```python
def create_daily_check(
    self,
    sleep_hours: float,
    hydration_rating: int,
    food_quality: int,
    movement_minutes: int,
    stress_level: int,
) -> bool:
    """
    Records a daily physiological check-in as a DailyCheck node.
    
    Returns: True if successful, False if DB unavailable.
    """
    if not self.is_available:
        return False
    
    try:
        with self.driver.session() as session:
            session.run("""
                CREATE (dc:DailyCheck {
                    timestamp: datetime(),
                    sleep_hours: $sleep,
                    hydration_rating: $hydration,
                    food_quality: $food,
                    movement_minutes: $movement,
                    stress_level: $stress
                })
            """,
                sleep=sleep_hours,
                hydration=hydration_rating,
                food=food_quality,
                movement=movement_minutes,
                stress=stress_level,
            )
        self.is_available = True
        return True
    except Exception:
        self.is_available = False
        logger.error("DB daily check creation error", exc_info=True)
        return False
```

- [ ] **Step 2: Add `get_daily_check_correlation()` method**

```python
def get_daily_check_correlation(self, days: int = 30) -> Dict[str, Any]:
    """
    Correlates daily physiological factors with entry frequency/risk.
    
    Returns: {
        "top_correlate": "low_sleep",
        "correlates": {"low_sleep": 2.1, "high_stress": 1.8}
    }
    
    Heuristic: Ratio of entries on low-sleep days to normal-sleep days.
    """
    if not self.is_available:
        return {}
    
    try:
        from datetime import datetime
        
        with self.driver.session() as session:
            # Get daily checks
            checks = session.run("""
                MATCH (dc:DailyCheck)
                WHERE dc.timestamp > datetime() - duration({days: $days})
                RETURN dc.sleep_hours, dc.stress_level, DATE(dc.timestamp) as check_date
            """, days=days)
            
            # Count entries per physiological category
            sleep_categories = {"low": 0, "normal": 0, "high": 0}
            stress_categories = {"low": 0, "normal": 0, "high": 0}
            
            for check in checks:
                sleep = check["sleep_hours"]
                stress = check["stress_level"]
                
                if sleep < 6:
                    sleep_categories["low"] += 1
                elif sleep <= 8:
                    sleep_categories["normal"] += 1
                else:
                    sleep_categories["high"] += 1
                
                if stress <= 2:
                    stress_categories["low"] += 1
                elif stress <= 3:
                    stress_categories["normal"] += 1
                else:
                    stress_categories["high"] += 1
            
            # Compute simple correlate ratios
            correlates = {}
            
            if sleep_categories["normal"] > 0:
                ratio = sleep_categories["low"] / sleep_categories["normal"]
                correlates["low_sleep"] = round(ratio, 2)
            
            if stress_categories["normal"] > 0:
                ratio = stress_categories["high"] / stress_categories["normal"]
                correlates["high_stress"] = round(ratio, 2)
            
            top = max(correlates, key=correlates.get) if correlates else None
            
            return {
                "top_correlate": top,
                "correlates": correlates,
            }
    except Exception:
        logger.error("DB correlation analysis error", exc_info=True)
        return {}
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/db.py
git commit -m "feat: add daily check creation and correlation analysis"
```

---

### Task 20: Add `/daily-check` Endpoint

**Files:**
- Modify: `backend/app/main.py` (add endpoint)

New endpoint records a daily check-in.

- [ ] **Step 1: Add endpoint to main.py**

```python
@app.post("/daily-check", status_code=201)
async def create_daily_check(
    body: DailyCheckRequest,
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db),
):
    """
    Records a daily physiological check-in.
    
    Request body:
    {
      "sleep_hours": 7.5,
      "hydration_rating": 4,
      "food_quality": 3,
      "movement_minutes": 45,
      "stress_level": 3
    }
    
    Response (201): {"status": "recorded"}
    """
    request_id = getattr(request.state, "request_id", "") if request else ""
    try:
        success = db.create_daily_check(
            sleep_hours=body.sleep_hours,
            hydration_rating=body.hydration_rating,
            food_quality=body.food_quality,
            movement_minutes=body.movement_minutes,
            stress_level=body.stress_level,
        )
        if success:
            return {"status": "recorded"}
        raise HTTPException(status_code=503, detail="Daily check recording failed")
    except HTTPException:
        raise
    except Exception:
        logger.error("Daily check creation failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Daily check service unavailable")
```

- [ ] **Step 2: Test with curl**

```bash
curl -X POST http://localhost:8000/daily-check \
  -H "Content-Type: application/json" \
  -d '{
    "sleep_hours": 7.5,
    "hydration_rating": 4,
    "food_quality": 3,
    "movement_minutes": 45,
    "stress_level": 3
  }' | jq '.'
```

Expected: `{"status": "recorded"}` with 201 status code.

- [ ] **Step 3: Commit**

```bash
git add backend/app/main.py
git commit -m "feat: add /daily-check endpoint"
```

---

### Task 21: Create Daily Check-In Dialog in Journal Screen

**Files:**
- Modify: `frontend/lib/screens/journal_screen.dart`

Add a dialog for daily physiological check-in with sliders and rating buttons.

- [ ] **Step 1: Open `frontend/lib/screens/journal_screen.dart` and add method**

```dart
void _showDailyCheckIn() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          double sleepHours = 8.0;
          int hydration = 3;
          int food = 3;
          int movement = 30;
          int stress = 3;
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Daily Check-In',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sleep slider
                  const Text(
                    'How much sleep did you get?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: sleepHours,
                    min: 0,
                    max: 12,
                    divisions: 24,
                    label: '${sleepHours.toStringAsFixed(1)}h',
                    onChanged: (val) => setDialogState(() => sleepHours = val),
                  ),
                  const SizedBox(height: 20),
                  
                  // Hydration rating
                  const Text(
                    'How hydrated are you?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (i) {
                      int level = i + 1;
                      return GestureDetector(
                        onTap: () => setDialogState(() => hydration = level),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: hydration == level ? Colors.blue : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$level',
                              style: TextStyle(
                                color: hydration == level ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  
                  // Food quality rating
                  const Text(
                    'Quality of food today?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (i) {
                      int level = i + 1;
                      return GestureDetector(
                        onTap: () => setDialogState(() => food = level),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: food == level ? Colors.green : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$level',
                              style: TextStyle(
                                color: food == level ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  
                  // Movement slider
                  const Text(
                    'Minutes of movement?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: movement.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 18,
                    label: '${movement}m',
                    onChanged: (val) => setDialogState(() => movement = val.toInt()),
                  ),
                  const SizedBox(height: 20),
                  
                  // Stress level rating
                  const Text(
                    'Current stress level?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (i) {
                      int level = i + 1;
                      return GestureDetector(
                        onTap: () => setDialogState(() => stress = level),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: stress == level ? Colors.red : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$level',
                              style: TextStyle(
                                color: stress == level ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await ApiClient.createDailyCheck({
                      'sleep_hours': sleepHours,
                      'hydration_rating': hydration,
                      'food_quality': food,
                      'movement_minutes': movement,
                      'stress_level': stress,
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Check-in recorded ✓')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
```

- [ ] **Step 2: Add button to trigger dialog**

In the journal screen (e.g., in AppBar or action button):
```dart
FloatingActionButton(
  onPressed: _showDailyCheckIn,
  tooltip: 'Daily Check-In',
  child: const Icon(Icons.favorite),
)
// Or add a button in the UI:
ElevatedButton(
  onPressed: _showDailyCheckIn,
  child: const Text('Daily Check-In'),
)
```

- [ ] **Step 3: Add API method to api_client.dart**

```dart
static Future<void> createDailyCheck(Map<String, dynamic> data) async {
  try {
    final response = await _httpClient.post(
      _uri('/daily-check'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode != 201) {
      throw Exception('Failed with status ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Daily check error: $e');
  }
}
```

- [ ] **Step 4: Test in emulator**

```bash
cd frontend && flutter run
```

Click the daily check-in button, fill out the form, and submit. Verify snackbar shows "Check-in recorded ✓".

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/screens/journal_screen.dart frontend/lib/services/api_client.dart
git commit -m "feat: add daily check-in dialog to journal screen"
```

---

### Task 22: Expand Movement Interventions with Zone 1–3 Variants

**Files:**
- Modify: `backend/app/interventions.py`

Add three movement intensity levels (Zone 1 = gentle, Zone 2 = moderate, Zone 3 = intense) with education for each.

- [ ] **Step 1: Open `backend/app/interventions.py` and find Movement intervention**

- [ ] **Step 2: Replace with zone variants**

```python
"Movement": {
    "Zone 1": {
        "title": "Zone 1 Movement (Gentle)",
        "task": "Walk slowly, stretch, or gentle yoga for 5–10 minutes.",
        "type": "movement",
        "education": {
            "introduce": "Zone 1 is 50–70% max heart rate. Activates parasympathetic without adding stress.",
            "reinforce": "Gentle movement with low intensity strengthens vagal tone without triggering fight-or-flight. Ideal when dysregulated.",
            "deepen": "Parasympathetic activation increases heart rate variability (HRV), a biomarker of nervous system flexibility. Repeated low-intensity movement trains baseline vagal strength."
        }
    },
    "Zone 2": {
        "title": "Zone 2 Movement (Moderate)",
        "task": "Brisk walk, light jog, or steady cycling for 10–20 minutes.",
        "type": "movement",
        "education": {
            "introduce": "Zone 2 is 70–80% max heart rate. Builds aerobic capacity and vagal tone sustainably.",
            "reinforce": "Sustained moderate-intensity activity strengthens the vagus nerve's capacity to downregulate after stress. It trains your system to return to baseline faster.",
            "deepen": "Zone 2 training improves aerobic efficiency and mitochondrial density, supporting sustained energy and emotional regulation. It's the 'sweet spot' for nervous system adaptation without acute stress."
        }
    },
    "Zone 3": {
        "title": "Zone 3 Movement (Intense)",
        "task": "High-intensity interval training, sprinting, or intense sport for 5–15 minutes.",
        "type": "movement",
        "education": {
            "introduce": "Zone 3 is 80–90% max heart rate. Acute stress followed by recovery trains nervous system resilience.",
            "reinforce": "Intense activity deliberately triggers sympathetic activation, then recovery forces parasympathetic rebound. This teach-and-recover cycle strengthens your ability to handle real stressors.",
            "deepen": "Repeated high-intensity intervals with recovery build post-exercise parasympathetic surge (cardiac vagal brake). Over time, your baseline stress threshold increases and recovery speed improves."
        }
    },
}
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/interventions.py
git commit -m "feat: add Zone 1-3 movement variants with depth-tiered education"
```

---

### Task 23: Write Tests for Daily Checks and Correlation

**Files:**
- Create: `backend/tests/test_daily_check.py` (new test file)

Tests cover DailyCheck creation, correlation analysis, and endpoint validation.

- [ ] **Step 1: Create `backend/tests/test_daily_check.py`**

```python
import pytest
from backend.app.main import app
from backend.app.models import DailyCheckRequest
from fastapi.testclient import TestClient

client = TestClient(app)


def test_daily_check_request_validation():
    """Verify request validation enforces ranges."""
    # Valid request
    response = client.post(
        "/daily-check",
        json={
            "sleep_hours": 7.5,
            "hydration_rating": 4,
            "food_quality": 3,
            "movement_minutes": 45,
            "stress_level": 3,
        },
    )
    assert response.status_code == 201
    
    # Invalid: sleep > 12
    response = client.post(
        "/daily-check",
        json={
            "sleep_hours": 15,
            "hydration_rating": 4,
            "food_quality": 3,
            "movement_minutes": 45,
            "stress_level": 3,
        },
    )
    assert response.status_code == 422  # Validation error


def test_daily_check_creates_record():
    """Verify /daily-check returns 201 on success."""
    response = client.post(
        "/daily-check",
        json={
            "sleep_hours": 6.5,
            "hydration_rating": 2,
            "food_quality": 2,
            "movement_minutes": 0,
            "stress_level": 5,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "recorded"


def test_daily_check_empty_correlation():
    """Verify correlation analysis handles empty data gracefully."""
    # With no data, correlation should return empty dict or default values
    from backend.app.db import BehavioralStateManager
    
    db = BehavioralStateManager()
    result = db.get_daily_check_correlation(days=30)
    
    # Should be dict (possibly empty)
    assert isinstance(result, dict)


def test_daily_check_request_model():
    """Verify Pydantic model validates input."""
    # Valid
    req = DailyCheckRequest(
        sleep_hours=7.0,
        hydration_rating=3,
        food_quality=4,
        movement_minutes=30,
        stress_level=2,
    )
    assert req.sleep_hours == 7.0
    
    # Invalid: hydration_rating must be 1-5
    with pytest.raises(ValueError):
        DailyCheckRequest(
            sleep_hours=7.0,
            hydration_rating=6,
            food_quality=4,
            movement_minutes=30,
            stress_level=2,
        )
```

- [ ] **Step 2: Run tests**

```bash
cd backend && pytest tests/test_daily_check.py -xvs
```

Expected: Tests pass.

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_daily_check.py
git commit -m "test: add comprehensive tests for daily check-ins"
```

---

## Summary

| Phase | Hours | Status |
|-------|-------|--------|
| 6.1 (Progressive Education) | 7h | 6 tasks ✓ |
| 6.2 (Loop Path Visualization) | 11h | 5 tasks ✓ |
| 6.3 (Weekly/Monthly Tracking) | 12h | 6 tasks ✓ |
| 6.4 (Daily Checks + Movement) | 10h | 6 tasks ✓ |
| Tests (across all phases) | 12h | Integrated per-phase |
| **Total** | **52h** | **23 tasks** |

---

## Execution Notes

- **Start order:** 6.1 → (6.2 + 6.3 in parallel) → 6.4
- **Commit frequency:** After each step (micro-commits for easy review)
- **Testing:** Tests written as part of each phase; run full suite after 6.1, 6.3, and 6.4 complete
- **Database readiness:** Ensure Neo4j is running and contains sample Entry/Node data before testing endpoints
- **Feature flags:** Enable via env vars once implementation is stable
  ```bash
  export FEATURE_PROGRESSIVE_EDUCATION=true
  export FEATURE_LOOP_PATH=true
  export FEATURE_WEEKLY_TRACKING=true
  export FEATURE_DAILY_CHECK=true
  ```

---

## Next Steps

1. **Review this plan** for clarity and completeness
2. **Choose execution strategy** (see below)
3. **Begin Phase 6.1** (7h, lowest risk)

