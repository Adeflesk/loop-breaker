# Task 4: Loop Path Visualization (6.2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract and visualize user's personal feedback loop patterns—showing state transitions over time, identifying entry points, and calculating cycle lengths.

**Architecture:** Backend extracts chronological Entry→Node sequences from Neo4j, analyzes patterns (cycle detection, most common entry), and exposes via `/loop-path` endpoint. Frontend displays timeline with state transitions and highlights most common entry point.

**Tech Stack:** Neo4j (backend), Cypher queries (date ranges, relationships), Dart/Flutter (frontend UI), canvas/custom painting for timeline visualization.

---

## File Structure & Changes

**Backend Changes:**
- `backend/app/db.py` — Add `get_loop_path()` and `analyze_loop_path()` methods
- `backend/app/main.py` — Add `/loop-path` GET endpoint

**Frontend Changes:**
- `frontend/lib/services/api_client.dart` — Add `getLoopPath()` method
- `frontend/lib/widgets/loop_path_chart.dart` — NEW: Timeline visualization widget
- `frontend/lib/screens/history_screen.dart` — Add loop path section with FutureBuilder

**Testing:**
- `backend/tests/test_loop_path.py` — Unit tests for loop path extraction and analysis

---

## Task 1: Add Backend `get_loop_path()` Method to db.py

**Files:**
- Modify: `backend/app/db.py` (add new method around line 430, before `create_db_manager()`)
- Test: `backend/tests/test_loop_path.py` (create new file)

- [ ] **Step 1: Read db.py to understand existing query patterns**

Navigate to `/Users/adriancorsini/Development/loop-breaker/backend/app/db.py` and review:
- How `get_history()` builds Neo4j queries (line 190)
- How error handling works in existing methods
- Import statements (datetime, typing, logging already present)

- [ ] **Step 2: Write the failing test for `get_loop_path()`**

Create `backend/tests/test_loop_path.py`:

```python
import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, patch
from app.db import BehavioralStateManager

def test_get_loop_path_returns_empty_on_unavailable_db():
    """When DB is unavailable, return empty list."""
    mock_driver = Mock()
    db = BehavioralStateManager.__new__(BehavioralStateManager)
    db.driver = mock_driver
    db.is_available = False
    
    result = db.get_loop_path(days=30)
    
    assert result == []

def test_get_loop_path_extracts_entries_with_states():
    """Extract chronological entries with states and confidence."""
    mock_driver = Mock()
    mock_session = Mock()
    mock_driver.session.return_value.__enter__.return_value = mock_session
    
    # Mock Neo4j result
    mock_record_1 = Mock()
    mock_record_1.__getitem__ = lambda self, key: {
        "timestamp": "2026-05-02T10:00:00Z",
        "state": "Stress",
        "confidence": 0.92,
        "has_intervention": True,
    }[key]
    
    mock_record_2 = Mock()
    mock_record_2.__getitem__ = lambda self, key: {
        "timestamp": "2026-05-02T14:00:00Z",
        "state": "Procrastination",
        "confidence": 0.85,
        "has_intervention": False,
    }[key]
    
    mock_session.run.return_value = [mock_record_1, mock_record_2]
    
    db = BehavioralStateManager.__new__(BehavioralStateManager)
    db.driver = mock_driver
    db.is_available = True
    
    result = db.get_loop_path(days=30)
    
    assert len(result) == 2
    assert result[0]["state"] == "Stress"
    assert result[0]["confidence"] == 0.92
    assert result[1]["state"] == "Procrastination"
```

Run: `cd backend && pytest tests/test_loop_path.py::test_get_loop_path_returns_empty_on_unavailable_db -v`

Expected: FAIL (method doesn't exist)

- [ ] **Step 3: Implement `get_loop_path()` in db.py**

Add this method after `get_history()` (around line 220) and before `get_ai_insight()`:

```python
def get_loop_path(self, days: int = 30) -> List[Dict[str, Any]]:
    """
    Returns list of entries in chronological order with their states.
    Used to compute loop sequences and patterns.
    
    Args:
        days: Number of days back to query (default 30)
    
    Returns:
        List of dicts with: timestamp, state, confidence, has_intervention
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
                    "confidence": record["confidence"],
                    "has_intervention": record["has_intervention"],
                })
            self.is_available = True
            return path
    except Exception:
        logger.error("DB loop path error", exc_info=True)
        return []
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && pytest tests/test_loop_path.py::test_get_loop_path_returns_empty_on_unavailable_db -v`

Expected: PASS

Run: `cd backend && pytest tests/test_loop_path.py -v`

Expected: Both tests pass

- [ ] **Step 5: Commit**

```bash
cd backend
git add app/db.py tests/test_loop_path.py
git commit -m "feat(6.2): add get_loop_path() method for state transition extraction"
```

---

## Task 2: Add Backend `analyze_loop_path()` Method to db.py

**Files:**
- Modify: `backend/app/db.py` (add method after `get_loop_path()`)
- Test: `backend/tests/test_loop_path.py` (add tests)

- [ ] **Step 1: Write failing tests for `analyze_loop_path()`**

Add to `backend/tests/test_loop_path.py`:

```python
def test_analyze_loop_path_returns_empty_on_unavailable_db():
    """When DB is unavailable, return empty dict."""
    db = BehavioralStateManager.__new__(BehavioralStateManager)
    db.is_available = False
    
    result = db.analyze_loop_path(days=30)
    
    assert result == {}

def test_analyze_loop_path_identifies_entry_point():
    """Identify most common entry point in cycles."""
    # Simulated path: Stress → Procrastination → Stress (7h gap, cycle 1)
    #                Stress → Procrastination (no cycle 2 yet)
    path = [
        {"timestamp": "2026-05-01T10:00:00", "state": "Stress", "confidence": 0.9, "has_intervention": True},
        {"timestamp": "2026-05-01T12:00:00", "state": "Procrastination", "confidence": 0.85, "has_intervention": False},
        {"timestamp": "2026-05-01T17:00:00", "state": "Stress", "confidence": 0.88, "has_intervention": True},
        {"timestamp": "2026-05-02T01:00:00", "state": "Stress", "confidence": 0.92, "has_intervention": True},  # 8h gap = new cycle
        {"timestamp": "2026-05-02T03:00:00", "state": "Procrastination", "confidence": 0.80, "has_intervention": False},
    ]
    
    db = BehavioralStateManager.__new__(BehavioralStateManager)
    db.is_available = True
    
    # Mock get_loop_path to return our test path
    with patch.object(db, 'get_loop_path', return_value=path):
        result = db.analyze_loop_path(days=30)
    
    # Stress is the starting point of most cycles (appears at 0h and after 8h gap)
    assert result["most_common_entry"] == "Stress"
    assert result["total_cycles"] == 2

def test_analyze_loop_path_calculates_cycle_length():
    """Calculate average time between repeats of most common state."""
    path = [
        {"timestamp": "2026-05-01T10:00:00", "state": "Stress", "confidence": 0.9, "has_intervention": True},
        {"timestamp": "2026-05-01T12:00:00", "state": "Procrastination", "confidence": 0.85, "has_intervention": False},
        {"timestamp": "2026-05-01T17:00:00", "state": "Stress", "confidence": 0.88, "has_intervention": True},  # 7 hours later
        {"timestamp": "2026-05-02T01:00:00", "state": "Stress", "confidence": 0.92, "has_intervention": True},  # 8 hours later
    ]
    
    db = BehavioralStateManager.__new__(BehavioralStateManager)
    db.is_available = True
    
    with patch.object(db, 'get_loop_path', return_value=path):
        result = db.analyze_loop_path(days=30)
    
    # Stress repeats at 7h and 8h intervals → avg = 7.5h
    assert result["cycle_length_hours"] == 7.5
```

Run: `cd backend && pytest tests/test_loop_path.py::test_analyze_loop_path_returns_empty_on_unavailable_db -v`

Expected: FAIL (method doesn't exist)

- [ ] **Step 2: Implement `analyze_loop_path()` in db.py**

Add after `get_loop_path()` (around line 240):

```python
def analyze_loop_path(self, days: int = 30) -> Dict[str, Any]:
    """
    Analyze personal loop patterns: entry point, cycle length, transitions.
    
    Args:
        days: Number of days back to query (default 30)
    
    Returns:
        Dict with: most_common_entry, cycle_length_hours, total_cycles
    """
    if not self.is_available:
        return {}
    
    path = self.get_loop_path(days=days)
    if not path:
        return {}
    
    # Find most common starting state (first state in each "cycle")
    # Heuristic: state repeated after N hours = new cycle
    entry_counts = {}
    current_cycle_start = None
    last_timestamp = None
    
    from datetime import datetime
    
    for entry in path:
        ts = entry["timestamp"]
        if last_timestamp:
            # If gap > 6 hours, assume new cycle
            time_diff = (datetime.fromisoformat(ts.replace('Z', '+00:00')) - 
                        datetime.fromisoformat(last_timestamp.replace('Z', '+00:00'))).total_seconds() / 3600
            if time_diff > 6:
                current_cycle_start = entry["state"]
        else:
            current_cycle_start = entry["state"]
        
        if current_cycle_start:
            entry_counts[current_cycle_start] = entry_counts.get(current_cycle_start, 0) + 1
        last_timestamp = ts
    
    most_common_entry = max(entry_counts, key=entry_counts.get) if entry_counts else None
    
    # Compute average cycle length (time between repeats of most common state)
    cycle_length_hours = None
    if most_common_entry:
        timestamps_of_state = [
            entry["timestamp"] for entry in path 
            if entry["state"] == most_common_entry
        ]
        if len(timestamps_of_state) > 1:
            time_diffs = []
            for i in range(1, len(timestamps_of_state)):
                diff = (datetime.fromisoformat(timestamps_of_state[i].replace('Z', '+00:00')) - 
                        datetime.fromisoformat(timestamps_of_state[i-1].replace('Z', '+00:00'))).total_seconds() / 3600
                time_diffs.append(diff)
            cycle_length_hours = sum(time_diffs) / len(time_diffs) if time_diffs else None
    
    return {
        "most_common_entry": most_common_entry,
        "cycle_length_hours": cycle_length_hours,
        "total_cycles": len(entry_counts),
    }
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd backend && pytest tests/test_loop_path.py -v`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
cd backend
git add app/db.py tests/test_loop_path.py
git commit -m "feat(6.2): add analyze_loop_path() for cycle detection and pattern analysis"
```

---

## Task 3: Add `/loop-path` Endpoint to main.py

**Files:**
- Modify: `backend/app/main.py` (add endpoint after `/history`, around line 298)
- Test: `backend/tests/test_api.py` (add integration test)

- [ ] **Step 1: Read the existing `/history` endpoint pattern**

Review `backend/app/main.py` lines 288–297 to understand:
- How endpoints accept Query params
- How they use Depends(get_db)
- How they handle errors with HTTPException

- [ ] **Step 2: Write failing integration test**

Add to `backend/tests/test_api.py`:

```python
def test_loop_path_endpoint_returns_path_and_analysis(client, monkeypatch):
    """GET /loop-path returns state transitions and analysis."""
    mock_path = [
        {"timestamp": "2026-05-02T10:00:00Z", "state": "Stress", "confidence": 0.92, "has_intervention": True},
        {"timestamp": "2026-05-02T14:00:00Z", "state": "Procrastination", "confidence": 0.85, "has_intervention": False},
    ]
    mock_analysis = {
        "most_common_entry": "Stress",
        "cycle_length_hours": 4.5,
        "total_cycles": 3,
    }
    
    def mock_get_loop_path(days):
        return mock_path
    
    def mock_analyze_loop_path(days):
        return mock_analysis
    
    # Patch the db methods
    monkeypatch.setattr("app.main.db.get_loop_path", mock_get_loop_path, raising=False)
    monkeypatch.setattr("app.main.db.analyze_loop_path", mock_analyze_loop_path, raising=False)
    
    response = client.get("/loop-path?days=30")
    
    assert response.status_code == 200
    data = response.json()
    assert "path" in data
    assert "analysis" in data
    assert len(data["path"]) == 2
    assert data["analysis"]["most_common_entry"] == "Stress"
```

Run: `cd backend && pytest tests/test_api.py::test_loop_path_endpoint_returns_path_and_analysis -v`

Expected: FAIL (endpoint doesn't exist)

- [ ] **Step 3: Implement the `/loop-path` endpoint**

Add after `/history` endpoint (around line 298 in `backend/app/main.py`):

```python
@app.get("/loop-path")
async def get_loop_path(
    days: int = 30,
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db)
):
    """
    Get user's personal loop path: state transitions and cycle analysis.
    
    Query params:
        days: Number of days back to query (default 30)
    
    Returns:
        {
            "path": [{"timestamp": str, "state": str, "confidence": float, "has_intervention": bool}, ...],
            "analysis": {
                "most_common_entry": str or None,
                "cycle_length_hours": float or None,
                "total_cycles": int
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
    except Exception:
        logger.error("Loop path retrieval failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Loop path service unavailable")
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd backend && pytest tests/test_api.py::test_loop_path_endpoint_returns_path_and_analysis -v`

Expected: PASS

- [ ] **Step 5: Run all backend tests to ensure no regressions**

Run: `cd backend && pytest -v`

Expected: All tests pass, or only pre-existing failures

- [ ] **Step 6: Commit**

```bash
cd backend
git add app/main.py tests/test_api.py
git commit -m "feat(6.2): add /loop-path endpoint for state transition queries"
```

---

## Task 4: Add `getLoopPath()` Method to api_client.dart

**Files:**
- Modify: `frontend/lib/services/api_client.dart` (add method near other GET methods)
- Test: Manual verification (integration with UI in next task)

- [ ] **Step 1: Review existing API client methods**

Open `frontend/lib/services/api_client.dart` and review:
- How `getHistory()` or `getInsight()` methods are structured
- The `_uri()` helper
- The response parsing pattern
- The error handling with try/catch

- [ ] **Step 2: Add `getLoopPath()` method**

Add after existing GET methods (search for `static Future<List` or `static Future<Map`):

```dart
/// Fetches the user's loop path visualization data.
/// 
/// Returns a map containing:
/// - "path": List of state transitions with timestamps and confidence
/// - "analysis": Map with most_common_entry, cycle_length_hours, total_cycles
static Future<Map<String, dynamic>> getLoopPath({int days = 30}) async {
  try {
    final response = await _httpClient.get(
      _uri('/loop-path?days=$days'),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    }
  } catch (e) {
    debugPrint("Loop path fetch error: $e");
  }
  return {"path": [], "analysis": {}};
}
```

- [ ] **Step 3: Verify syntax by checking the file compiles**

Run: `cd frontend && flutter analyze lib/services/api_client.dart`

Expected: No errors (only warnings if pre-existing)

- [ ] **Step 4: Commit**

```bash
cd frontend
git add lib/services/api_client.dart
git commit -m "feat(6.2): add getLoopPath() API client method"
```

---

## Task 5: Create Loop Path Chart Widget (loop_path_chart.dart)

**Files:**
- Create: `frontend/lib/widgets/loop_path_chart.dart`
- Modify: `frontend/lib/widgets/` (to ensure imports work)

- [ ] **Step 1: Create the loop_path_chart.dart file**

Create new file at `frontend/lib/widgets/loop_path_chart.dart` with:

```dart
import 'package:flutter/material.dart';

/// Visualizes state transition timeline for loop path.
/// Shows chronological entries with state names, confidence values, and highlights
/// the most common entry point.
class LoopPathChart extends StatelessWidget {
  final List<dynamic> path;
  final String? mostCommonEntry;
  
  const LoopPathChart({
    required this.path,
    this.mostCommonEntry,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No loop data available yet',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline header
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              'State Transitions (Last 30 Days)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          // Timeline nodes
          Row(
            children: [
              for (int i = 0; i < path.length; i++)
                _buildNode(context, path[i] as Map<String, dynamic>, i, path.length),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildNode(BuildContext context, Map<String, dynamic> entry, int index, int total) {
    final state = entry['state'] as String? ?? 'Unknown';
    final confidence = entry['confidence'] as double? ?? 0.0;
    final timestamp = entry['timestamp'] as String? ?? '';
    final isCommonEntry = state == mostCommonEntry;
    
    // Parse timestamp for display
    String timeLabel = 'Unknown';
    try {
      final dt = DateTime.parse(timestamp);
      timeLabel = '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
    
    // Color coding by state
    final nodeColor = _getStateColor(state);
    final nodeBorder = isCommonEntry ? 3.0 : 2.0;
    final nodeBorderColor = isCommonEntry ? Colors.red : nodeColor;
    
    return Expanded(
      child: Column(
        children: [
          // Timestamp label
          Text(
            timeLabel,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Node circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: nodeColor.withOpacity(0.2),
              border: Border.all(
                color: nodeBorderColor,
                width: nodeBorder,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.substring(0, (state.length > 3 ? 3 : state.length)),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${(confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // State label
          Text(
            state,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCommonEntry ? FontWeight.bold : FontWeight.normal,
              color: isCommonEntry ? Colors.red : Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Arrow to next node (if not last)
          if (index < total - 1) ...[
            const SizedBox(height: 8),
            const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
          ],
        ],
      ),
    );
  }
  
  Color _getStateColor(String state) {
    // Map states to colors matching the emotion wheel
    switch (state.toLowerCase()) {
      case 'stress':
        return Colors.orange;
      case 'anxiety':
        return Colors.deepOrange;
      case 'overwhelm':
        return Colors.red;
      case 'procrastination':
        return Colors.purple;
      case 'numbness':
        return Colors.blue;
      case 'shame':
        return Colors.brown;
      case 'isolation':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
```

- [ ] **Step 2: Verify the widget compiles**

Run: `cd frontend && flutter analyze lib/widgets/loop_path_chart.dart`

Expected: No errors

- [ ] **Step 3: Commit**

```bash
cd frontend
git add lib/widgets/loop_path_chart.dart
git commit -m "feat(6.2): create LoopPathChart widget for state transition visualization"
```

---

## Task 6: Update history_screen.dart to Display Loop Path

**Files:**
- Modify: `frontend/lib/screens/history_screen.dart` (add loop path section)

- [ ] **Step 1: Review history_screen.dart structure**

Open `frontend/lib/screens/history_screen.dart` and find:
- Where the main content column is defined
- Where existing sections (like thought records) are added
- The FutureBuilder pattern used for async data

- [ ] **Step 2: Add import for LoopPathChart**

At the top of `history_screen.dart`, add:

```dart
import '../widgets/loop_path_chart.dart';
```

- [ ] **Step 3: Add loop path section after main history content**

Find the main content Column or ListView and add the following FutureBuilder section at the end (before the closing bracket of the content widget):

```dart
// Loop Path Section
FutureBuilder<Map<String, dynamic>>(
  future: ApiClient.getLoopPath(days: 30),
  builder: (context, snapshot) {
    if (!snapshot.hasData || snapshot.data == null) {
      return const SizedBox.shrink();
    }
    
    final data = snapshot.data!;
    final path = data['path'] as List? ?? [];
    final analysis = data['analysis'] as Map? ?? {};
    
    if (path.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            'Your Loop Pattern',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        LoopPathChart(
          path: path,
          mostCommonEntry: analysis['most_common_entry'] as String?,
        ),
        if (analysis['most_common_entry'] != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most common entry point: ${analysis['most_common_entry']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (analysis['cycle_length_hours'] != null)
                  Text(
                    'Average cycle length: ${(analysis['cycle_length_hours'] as num).toStringAsFixed(1)} hours',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (analysis['total_cycles'] != null)
                  Text(
                    'Total cycles: ${analysis['total_cycles']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
      ],
    );
  },
),
```

- [ ] **Step 4: Test the widget integration manually**

Run: `cd frontend && flutter run --dart-define=API_URL=http://localhost:8000`

Expected: No compilation errors; if data exists in backend, loop path section appears in history screen

- [ ] **Step 5: Commit**

```bash
cd frontend
git add lib/screens/history_screen.dart
git commit -m "feat(6.2): add loop path visualization section to history screen"
```

---

## Task 7: Run Full Backend & Frontend Tests

**Files:**
- Test: `backend/tests/test_loop_path.py`, `backend/tests/test_api.py`
- Test: `frontend/test/widget_test.dart` (if applicable)

- [ ] **Step 1: Run all backend tests**

Run: `cd backend && pytest -v --cov=app --cov-report=term-missing`

Expected: All tests pass; coverage report shows loop_path.py with >70% coverage

- [ ] **Step 2: Check for regressions in existing tests**

Run: `cd backend && pytest tests/test_api.py -v`

Expected: All API tests pass, including new /loop-path endpoint

- [ ] **Step 3: Build frontend and check for compilation errors**

Run: `cd frontend && flutter pub get && flutter analyze`

Expected: No errors (warnings acceptable)

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test(6.2): verify loop path implementation with comprehensive tests"
```

---

## Task 8: Verification & Documentation

**Files:**
- Verify: Backend endpoint responses
- Verify: Frontend integration
- Update: docs/phase-6-specification.md if needed

- [ ] **Step 1: Manual end-to-end test**

Start backend: `cd backend && ./run_app.sh` (or uvicorn)
Start frontend: `cd frontend && flutter run`

Actions:
1. Log several journal entries with different states
2. Navigate to History screen
3. Verify loop path section appears
4. Verify state transitions show in timeline
5. Verify most common entry point is highlighted in red

- [ ] **Step 2: Test with curl for backend endpoint**

```bash
curl -X GET "http://localhost:8000/loop-path?days=30" \
  -H "Content-Type: application/json"
```

Expected response:
```json
{
  "path": [
    {"timestamp": "2026-05-02T10:00:00", "state": "Stress", "confidence": 0.92, "has_intervention": true},
    ...
  ],
  "analysis": {
    "most_common_entry": "Stress",
    "cycle_length_hours": 4.5,
    "total_cycles": 3
  }
}
```

- [ ] **Step 3: Test empty path scenario**

If no entries exist in database:
- Backend should return: `{"path": [], "analysis": {}}`
- Frontend should show: "No loop data available yet"

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(6.2): complete loop path visualization—backend and frontend"
```

---

## Spec Coverage Checklist

- [x] `get_loop_path()` returns state transitions with timestamp, state, confidence, has_intervention (6.2 Data Model)
- [x] `analyze_loop_path()` identifies most_common_entry and cycle_length_hours (6.2 Backend Changes)
- [x] `/loop-path` endpoint exposes path and analysis (6.2 API Contract)
- [x] LoopPathChart widget visualizes transitions with timeline (6.2 Frontend Changes)
- [x] history_screen displays loop path section with FutureBuilder (6.2 Frontend Changes)
- [x] api_client.dart includes getLoopPath() method (6.2 Frontend Changes)
- [x] Error handling: Returns empty path on DB unavailable (6.2 Acceptance Criteria)
- [x] Error handling: No crash when path is empty (6.2 Acceptance Criteria)
- [x] Most common entry point is highlighted (bonus visual distinction)
- [x] Cycle analysis extracts entry point and length accurately (6.2 Acceptance Criteria)

---

## Implementation Order & Dependencies

1. **Backend methods first** (Tasks 1–2): DB methods must exist before endpoint
2. **Backend endpoint** (Task 3): Exposes data via HTTP
3. **Frontend API client** (Task 4): Fetches data from endpoint
4. **Frontend widget** (Task 5): Displays data in reusable component
5. **Frontend integration** (Task 6): Adds widget to history screen
6. **Testing** (Task 7): Comprehensive coverage
7. **Verification** (Task 8): End-to-end testing

No parallel tracks needed; each task depends on previous.

---

## Known Limitations & Future Work

- **Cycle detection heuristic:** Uses 6-hour gap to define cycle boundary (could be tuned per user in future)
- **Timeline layout:** Horizontal scroll; future could add collapsible groups by date
- **Cycle length calculation:** Simple average; could add median or trend analysis
- **Performance:** Current Cypher query is O(n) on entries; OK for <1000 entries; may need indexing at scale

Plan complete and saved to `docs/superpowers/plans/2026-05-03-loop-path-visualization.md`.

---

## Execution Options

**Two execution approaches available:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks sequentially in this session using executing-plans

Which approach would you prefer?
