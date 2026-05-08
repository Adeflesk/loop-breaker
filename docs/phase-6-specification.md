# Phase 6: Depth & Longitudinal Intelligence — Detailed Specifications

**Date:** 2026-05-03  
**Status:** Draft  
**Scope:** 6.1–6.4: Progressive education, loop path visualization, weekly tracking, physiological correlation  
**Target Duration:** Weeks 4–6 (~50h total)

---

## Executive Summary

Phase 6 transforms LoopBreaker from session-level crisis support to week-level pattern intelligence. Users will see their personal feedback loop visually, track weekly trends, and understand how sleep/nutrition correlates with risk. Education deepens based on intervention repeat exposure.

**Key deliverables:**
- Progressive neuroscience education (3 depth levels per state)
- Personal loop path visualization (state transition sequences)
- Weekly/monthly tracking without LIMIT 20 cap
- Physiological check-in + risk correlation

**Critical dependencies:**
- Phase 5 must be complete (8-node arc, sublabel routing, thought records)
- Feature flags: `FEATURE_PROGRESSIVE_EDUCATION`, `FEATURE_WEEKLY_TRACKING`, `FEATURE_DAILY_CHECK`

---

## Data Model Changes

### New/Modified Neo4j Node Types

```cypher
# Existing (Phase 5):
Entry {timestamp, confidence, emotion_sublabel, loop_broken}
Node {name}  # 7 emotional states
Intervention {title, task, timestamp}
Outcome {success, skipped, timestamp, hydration, fuel, rest, movement}
ThoughtRecord {timestamp, situation, automatic_thought, evidence_for, evidence_against, balanced_thought, linked_node}

# NEW for Phase 6:

# Track intervention exposure for progressive education
MATCH (e:Entry)-[:HAS_INTERVENTION]->(i:Intervention)
# Add property to Intervention:
Intervention {title, task, timestamp, seen_count: int}  # Incremented each time intervention is shown

# Daily physiological check-in (6.4)
DailyCheck {
  timestamp: datetime,        # Date of check-in
  sleep_hours: float,         # 0-12 range
  hydration_rating: int,      # 1-5 scale
  food_quality: int,          # 1-5 scale (quality, not quantity)
  movement_minutes: int,      # 0-180
  stress_level: int           # 1-5 scale
}

# Relationships:
(e:Entry)-[:FOLLOWS_DAY]->(dc:DailyCheck)  # Entry recorded on same day as check-in
```

### Pydantic Models

**In `backend/app/models.py`:**

```python
class DailyCheckRequest(BaseModel):
    """Daily physiological check-in."""
    sleep_hours: float = Field(..., ge=0, le=12)
    hydration_rating: int = Field(..., ge=1, le=5)
    food_quality: int = Field(..., ge=1, le=5)
    movement_minutes: int = Field(..., ge=0, le=180)
    stress_level: int = Field(..., ge=1, le=5)

class DailyCheckResponse(BaseModel):
    """Response after recording daily check-in."""
    timestamp: str
    sleep_hours: float
    hydration_rating: int
    food_quality: int
    movement_minutes: int
    stress_level: int

class WeeklySummary(BaseModel):
    """7-day aggregated stats."""
    week_start: str  # ISO 8601 date
    week_end: str
    total_entries: int
    high_risk_days: int
    avg_confidence: float
    intervention_success_rate: float  # 0-1
    top_states: Dict[str, int]  # {"Stress": 4, "Anxiety": 2, ...}
    avg_sleep: float
    avg_stress: float
    top_physiological_correlate: Optional[str]  # e.g., "low_sleep" if correlated with 2x High risk

class LoopPathNode(BaseModel):
    """Single node in state transition sequence."""
    state: str  # e.g., "Stress"
    timestamp: str
    confidence: float
    intervention_success: Optional[bool]

class LoopPathResponse(BaseModel):
    """User's personal loop transition sequence."""
    path: List[LoopPathNode]
    most_common_entry: Optional[str]  # State that appears first in cycles
    cycle_length: Optional[float]  # Avg hours between same-state repeats
    total_cycles: int
```

---

## 6.1 — Progressive Neuroscience Education

### Context

Currently, education text is identical every time a user sees an intervention. The book emphasizes understanding WHY the loop forms (neuroscience foundation). Depth should increase with repeat exposure: first time (educate), second+ (reinforce), fifth+ (deepen with advanced concepts).

### Data Model

**Intervention node changes:**
- Add `seen_count: int` property, incremented in `/analyze` when intervention is returned
- Track in database as cumulative per-user measure

**AnalysisResponse enhancement:**
```python
class AnalysisResponse(BaseModel):
    # ... existing fields ...
    education_depth: Optional[str] = None  # "introduce" | "reinforce" | "deepen"
    education_info: Optional[str] = None  # Depth-adjusted education text
```

### Education Content Structure

**In `backend/app/interventions.py`:**

Each state's education dict becomes a list with 3 depth levels:

```python
INTERVENTIONS = {
    "Stress": {
        None: {  # Default variant
            "title": "Physiological Sigh",
            "task": "...",
            "type": "breathing",
            "education": {
                "introduce": "Stress triggers your sympathetic nervous system (fight-or-flight). A physiological sigh deactivates it.",
                "reinforce": "Repeated stress keeps your nervous system in a heightened state. CO2 is the fastest biological reset. This breath technique targets it directly.",
                "deepen": "Your vagus nerve controls parasympathetic activation. The extended exhale in a physiological sigh increases vagal tone. Repeated practice rewires baseline threshold for stress activation."
            }
        },
        # Other variants...
    },
    # ... other states ...
}
```

**Expansion effort:** ~2 hours per state (7 states = 14h total for interventions.py)

### Backend Changes

**In `backend/app/db.py`:**

Add method to track intervention exposure:

```python
def increment_intervention_seen_count(self, intervention_title: str) -> None:
    """Increment seen_count for an intervention."""
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
```

**In `backend/app/main.py` (`/analyze` endpoint):**

After building intervention response, determine depth and select education text:

```python
# Determine education depth based on seen_count
education_depth = "introduce"
if intervention_title in all_interventions:  # Get current seen_count from DB
    # Query could be in-flight; for now, use heuristic:
    # First exposure: introduce, 2-4: reinforce, 5+: deepen
    # This will be refined after DB query integration
    pass

# Select education text by depth
intervention_dict = breaker  # or variant if selected
if isinstance(intervention_dict.get("education"), dict):
    education_text = intervention_dict["education"].get(
        education_depth, 
        intervention_dict["education"].get("introduce", "")
    )
else:
    education_text = intervention_dict.get("education", "")

# After calling log_and_analyze, increment seen_count:
try:
    db.increment_intervention_seen_count(breaker["title"])
except Exception:
    pass  # Non-critical
```

### Frontend Changes

**In `frontend/lib/screens/journal_screen.dart`:**

In `_showStandardInterventionDialog()`, add expandable "Learn More" section:

```dart
// After education container (existing):
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

**New screen: `frontend/lib/screens/library_screen.dart`**

Full-screen "Rewire Library" accessible from app bar menu. Shows all 7 states with 3-level education cards. ~6h to build.

### API Contract

No new endpoints; education is populated in existing `/analyze` response.

### Acceptance Criteria

- Education dict structure supports 3 depth levels in interventions.py
- `/analyze` response includes `education_depth` field
- "Learn More" section in intervention dialog expands/collapses
- Library screen displays all states with education cards
- seen_count increments in database
- All 7 states have 3 complete education levels

---

## 6.2 — Personal Loop Path Visualization

### Context

Neo4j stores every `Entry → Node` transition with timestamp. Querying these sequences reveals the user's personal feedback loop pattern: "Does Stress → Procrastination → Shame every time?" or "Anxiety cycles back to itself every 3 hours?"

### Data Model

No new nodes. Queries will extract `Entry.timestamp` and linked `Node.name` to reconstruct sequences.

### Backend Changes

**In `backend/app/db.py`:**

Add two methods:

```python
def get_loop_path(self, days: int = 30) -> List[Dict[str, Any]]:
    """
    Returns list of entries in chronological order with their states.
    Used to compute loop sequences and patterns.
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

def analyze_loop_path(self, days: int = 30) -> Dict[str, Any]:
    """
    Analyze personal loop patterns: entry point, cycle length, transitions.
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
    
    for entry in path:
        ts = entry["timestamp"]
        if last_timestamp:
            # If gap > 6 hours, assume new cycle
            time_diff = (datetime.fromisoformat(ts) - datetime.fromisoformat(last_timestamp)).total_seconds() / 3600
            if time_diff > 6:
                current_cycle_start = entry["state"]
        else:
            current_cycle_start = entry["state"]
        
        if current_cycle_start:
            entry_counts[current_cycle_start] = entry_counts.get(current_cycle_start, 0) + 1
        last_timestamp = ts
    
    most_common_entry = max(entry_counts, key=entry_counts.get) if entry_counts else None
    
    # Compute average cycle length (time between repeats of most common state)
    if most_common_entry:
        timestamps_of_state = [
            entry["timestamp"] for entry in path 
            if entry["state"] == most_common_entry
        ]
        if len(timestamps_of_state) > 1:
            time_diffs = []
            for i in range(1, len(timestamps_of_state)):
                diff = (datetime.fromisoformat(timestamps_of_state[i]) - 
                        datetime.fromisoformat(timestamps_of_state[i-1])).total_seconds() / 3600
                time_diffs.append(diff)
            avg_cycle_length = sum(time_diffs) / len(time_diffs) if time_diffs else None
        else:
            avg_cycle_length = None
    else:
        avg_cycle_length = None
    
    return {
        "most_common_entry": most_common_entry,
        "cycle_length_hours": avg_cycle_length,
        "total_cycles": len(entry_counts),
    }
```

**In `backend/app/main.py`:**

Add new endpoint:

```python
@app.get("/loop-path", response_model=Dict[str, Any])
async def get_loop_path(
    days: int = 30, 
    request: Request = None, 
    db: BehavioralStateManager = Depends(get_db)
):
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

### Frontend Changes

**New widget: `frontend/lib/widgets/loop_path_chart.dart`**

Visualize state transitions as a flow chart using `fl_chart` or custom canvas. ~6h.

```dart
class LoopPathChart extends StatelessWidget {
  final List<dynamic> path;
  final String? mostCommonEntry;
  
  const LoopPathChart({
    required this.path,
    this.mostCommonEntry,
  });
  
  @override
  Widget build(BuildContext context) {
    // Render timeline with nodes and arrows showing transitions
    // Highlight mostCommonEntry in red/bold
    // Show timestamp labels and confidence values
  }
}
```

**In `frontend/lib/screens/history_screen.dart`:**

Add section after thought records:

```dart
FutureBuilder<Map<String, dynamic>>(
  future: ApiClient.getLoopPath(days: 30),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    
    final data = snapshot.data!;
    final path = data['path'] as List? ?? [];
    final analysis = data['analysis'] as Map? ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
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
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Most common entry point: ${analysis['most_common_entry']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  },
)
```

**In `frontend/lib/services/api_client.dart`:**

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

### API Contract

```json
GET /loop-path?days=30

Response:
{
  "path": [
    {
      "timestamp": "2026-05-02T10:15:00Z",
      "state": "Stress",
      "confidence": 0.92,
      "has_intervention": true
    },
    {
      "timestamp": "2026-05-02T14:30:00Z",
      "state": "Procrastination",
      "confidence": 0.85,
      "has_intervention": false
    }
  ],
  "analysis": {
    "most_common_entry": "Stress",
    "cycle_length_hours": 4.5,
    "total_cycles": 12
  }
}
```

### Acceptance Criteria

- `/loop-path` endpoint returns state transition sequences (last 30 days)
- Analysis extracts most common entry point and average cycle length
- Loop path chart visualizes transitions with timeline
- History screen displays loop pattern section
- No errors when path is empty

---

## 6.3 — Weekly/Monthly Tracking

### Context

Current history is capped at 20 entries. Users can't see trends over weeks. Add date-range queries, remove cap, and introduce weekly summary.

### Data Model

No new nodes. Enhance history queries with optional date-range params.

### Backend Changes

**In `backend/app/db.py`:**

Modify `get_history()` to support date ranges and remove LIMIT 20:

```python
def get_history(self, start_date: Optional[str] = None, end_date: Optional[str] = None, limit: int = 500) -> List[Dict[str, Any]]:
    """
    Fetches entries within optional date range.
    start_date, end_date: ISO 8601 format (e.g., "2026-04-01")
    limit: Max entries to return (default 500, can be raised)
    """
    if not self.is_available:
        logger.warning("Neo4j unavailable, returning empty history")
        return []
    
    try:
        with self.driver.session() as session:
            where_clause = ""
            params = {"limit": limit}
            
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

Add new method for weekly summary:

```python
def get_weekly_summary(self, week_start: str) -> Dict[str, Any]:
    """
    Returns aggregated stats for a single 7-day week.
    week_start: ISO 8601 date (e.g., "2026-04-29" for Mon of that week)
    """
    if not self.is_available:
        return {}
    
    try:
        with self.driver.session() as session:
            # Date range: week_start through week_start + 6 days
            week_end = (datetime.fromisoformat(week_start) + timedelta(days=7)).isoformat()
            
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
                data.get("successful_interventions", 0) / data.get("total_interventions", 1) * 100
                if data.get("total_interventions", 0) > 0
                else 0
            )
            
            # Group states by count
            state_dict = {}
            for item in data.get("states", []):
                state_dict[item["state"]] = item["count"]
            
            return {
                "week_start": week_start,
                "total_entries": data.get("total_entries", 0),
                "days_with_entries": data.get("days_with_entries", 0),
                "avg_confidence": round(data.get("avg_confidence", 0), 2),
                "intervention_success_rate": round(success_rate, 1),
                "top_states": state_dict,
            }
    except Exception:
        logger.error("DB weekly summary error", exc_info=True)
        return {}
```

**In `backend/app/main.py`:**

Update `/history` endpoint to accept date params:

```python
@app.get("/history")
async def get_history(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    limit: int = 500,
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db)
):
    request_id = getattr(request.state, "request_id", "") if request else ""
    try:
        return db.get_history(start_date=start_date, end_date=end_date, limit=limit)
    except Exception:
        logger.error("History retrieval failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="History service unavailable")
```

Add new endpoint:

```python
@app.get("/weekly-summary", response_model=Dict[str, Any])
async def get_weekly_summary(
    week_start: str = Query(..., description="ISO 8601 date (e.g., 2026-04-29)"),
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db)
):
    request_id = getattr(request.state, "request_id", "") if request else ""
    try:
        return db.get_weekly_summary(week_start=week_start)
    except Exception:
        logger.error("Weekly summary retrieval failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Weekly summary service unavailable")
```

### Frontend Changes

**New widget: `frontend/lib/widgets/weekly_scorecard.dart`**

Card showing week-over-week comparison: entries, success rate, top states, trend arrow. ~4h.

```dart
class WeeklyScorecard extends StatelessWidget {
  final Map<String, dynamic> currentWeek;
  final Map<String, dynamic> previousWeek;
  
  const WeeklyScorecard({
    required this.currentWeek,
    required this.previousWeek,
  });
  
  @override
  Widget build(BuildContext context) {
    // Show current week stats with arrows comparing to previous week
    // Entry count, success rate, top state
  }
}
```

**In `frontend/lib/services/api_client.dart`:**

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
  return {};
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
  } catch (_) {
    // Swallow
  }
  return [];
}
```

**In `frontend/lib/screens/history_screen.dart`:**

Add date range picker + weekly comparison section:

```dart
// At top of history content:
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      'This Week vs Last Week',
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
    TextButton(
      onPressed: () {
        // Show date picker to select custom range
      },
      child: const Text('Custom Range'),
    ),
  ],
),
FutureBuilder<Map<String, dynamic>>(
  future: ApiClient.getWeeklySummary(
    DateTime.now().subtract(const Duration(days: 7)).toIso8601String().split('T')[0]
  ),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    return WeeklyScorecard(
      currentWeek: snapshot.data!,
      previousWeek: {}, // Fetch previous week similarly
    );
  },
)
```

### API Contracts

```json
GET /history?start_date=2026-04-01&end_date=2026-04-30&limit=500

Response: [
  {
    "time": "2026-04-01T10:15:00Z",
    "state": "Stress",
    "intervention": "Physiological Sigh",
    "confidence": 0.92,
    "was_successful": true
  },
  ...
]

GET /weekly-summary?week_start=2026-04-29

Response: {
  "week_start": "2026-04-29",
  "total_entries": 18,
  "days_with_entries": 6,
  "avg_confidence": 0.82,
  "intervention_success_rate": 72.5,
  "top_states": {
    "Stress": 8,
    "Anxiety": 5,
    "Procrastination": 3,
    "Procrastination": 2
  }
}
```

### Acceptance Criteria

- `/history` accepts `start_date`, `end_date`, `limit` params
- Date-range queries return correct entries
- `/weekly-summary` aggregates 7-day stats accurately
- Weekly scorecard widget displays current vs previous week
- CSV/JSON export button on history screen (bonus: ~1h)
- No performance degradation with large datasets (test with 1000+ entries)

---

## 6.4 — Proactive Body-Brain Tracking

### Context

The book emphasizes that dysregulation begins with unmet physiological needs. Daily check-in (sleep, hydration, food, movement, stress) surfaces correlations: "You had 2x more High-risk loops on low-sleep days." This makes prevention concrete.

### Data Model

**DailyCheck node (Neo4j):**

```cypher
DailyCheck {
  timestamp: datetime,      # Date of check-in
  sleep_hours: float,
  hydration_rating: int,    # 1-5
  food_quality: int,        # 1-5
  movement_minutes: int,
  stress_level: int         # 1-5
}

# Relationship: Entries on same day link to that day's DailyCheck
(e:Entry)-[:RECORDED_ON_DAY]->(dc:DailyCheck)
```

### Backend Changes

**In `backend/app/models.py`:**

(Already defined above in Data Model section)

**In `backend/app/db.py`:**

Add methods:

```python
def create_daily_check(
    self,
    sleep_hours: float,
    hydration_rating: int,
    food_quality: int,
    movement_minutes: int,
    stress_level: int,
) -> bool:
    """Records a daily physiological check-in."""
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

def get_daily_check_correlation(self, days: int = 30) -> Dict[str, Any]:
    """
    Correlates daily physiological state with loop risk.
    Returns: {
        "low_sleep_high_risk_ratio": 2.1,  # 2.1x more High-risk entries on low sleep days
        "top_correlate": "low_sleep",
        "correlates": {"low_sleep": 2.1, "high_stress": 1.8, ...}
    }
    """
    if not self.is_available:
        return {}
    
    try:
        with self.driver.session() as session:
            # Get high-risk entries
            high_risk = session.run("""
                MATCH (e:Entry)
                WHERE e.timestamp > datetime() - duration({days: $days})
                RETURN DATE(e.timestamp) as entry_date
            """, days=days).values()
            
            # Get daily checks
            checks = session.run("""
                MATCH (dc:DailyCheck)
                WHERE dc.timestamp > datetime() - duration({days: $days})
                RETURN DATE(dc.timestamp) as check_date, dc.sleep_hours, dc.stress_level
            """, days=days)
            
            sleep_data = {"low": 0, "normal": 0, "high": 0}
            stress_data = {"low": 0, "normal": 0, "high": 0}
            
            for check in checks:
                sleep = check["sleep_hours"]
                stress = check["stress_level"]
                
                # Categorize sleep
                if sleep < 6:
                    sleep_data["low"] += 1
                elif sleep <= 8:
                    sleep_data["normal"] += 1
                else:
                    sleep_data["high"] += 1
                
                # Categorize stress
                if stress <= 2:
                    stress_data["low"] += 1
                elif stress <= 3:
                    stress_data["normal"] += 1
                else:
                    stress_data["high"] += 1
            
            # Simple ratio: entries on low-sleep days / entries on normal-sleep days
            # (This is heuristic; full correlation analysis would be more complex)
            correlates = {}
            
            if sleep_data["normal"] > 0:
                ratio = sleep_data["low"] / sleep_data["normal"]
                correlates["low_sleep"] = ratio
            
            if stress_data["normal"] > 0:
                ratio = stress_data["high"] / stress_data["normal"]
                correlates["high_stress"] = ratio
            
            top = max(correlates, key=correlates.get) if correlates else None
            
            return {
                "top_correlate": top,
                "correlates": correlates,
            }
    except Exception:
        logger.error("DB correlation analysis error", exc_info=True)
        return {}
```

Update `get_ai_insight()` to include physiological correlate:

```python
# In get_ai_insight(), add:
if missing_need is None:
    correlation = self.get_daily_check_correlation()
    if correlation.get("top_correlate"):
        missing_need = correlation["top_correlate"]
```

**In `backend/app/main.py`:**

Add endpoint:

```python
@app.post("/daily-check", status_code=201)
async def create_daily_check(
    body: DailyCheckRequest,
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db),
):
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
    except Exception:
        logger.error("Daily check creation failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Daily check service unavailable")
```

### Frontend Changes

**New dialog: `_showDailyCheckIn()` in `journal_screen.dart`**

Optional 5-step check-in accessible from journal screen or periodic prompt. ~4h.

```dart
void _showDailyCheckIn() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          int sleepHours = 8;
          int hydration = 3;
          int food = 3;
          int movement = 30;
          int stress = 3;
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Daily Check-In', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Slider: Sleep hours (0-12)
                const Text('How much sleep did you get?'),
                Slider(
                  value: sleepHours.toDouble(),
                  min: 0,
                  max: 12,
                  onChanged: (val) => setDialogState(() => sleepHours = val.toInt()),
                ),
                Text('$sleepHours hours'),
                const SizedBox(height: 16),
                
                // Scale: Hydration (1-5)
                const Text('How hydrated are you feeling?'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                        child: Center(child: Text('$level')),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                
                // Similar for food quality, movement, stress
                // ... (omitted for brevity)
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await ApiClient.createDailyCheck({
                    'sleep_hours': sleepHours.toDouble(),
                    'hydration_rating': hydration,
                    'food_quality': food,
                    'movement_minutes': movement,
                    'stress_level': stress,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Check-in recorded')),
                  );
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

**Trigger daily check-in:**
- On app startup if not already checked in today
- Optional button in journal screen UI
- Or periodic background notification (requires Phase 7)

**In `frontend/lib/services/api_client.dart`:**

```dart
static Future<void> createDailyCheck(Map<String, dynamic> data) async {
  final response = await _httpClient.post(
    _uri('/daily-check'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(data),
  );
  
  if (response.statusCode != 201) {
    throw Exception('Daily check creation failed with status ${response.statusCode}');
  }
}
```

### Movement Protocol Completion

**In `backend/app/interventions.py`:**

Expand movement interventions with Zone 1–3 variants (currently stub). ~2h.

```python
"Movement": {
    "Zone 1": {
        "title": "Zone 1 Movement (Gentle)",
        "task": "Walk slowly, stretch, or gentle yoga for 5-10 minutes.",
        "education": "Zone 1 is 50-70% max heart rate. Activates parasympathetic without stress.",
        "type": "movement",
    },
    "Zone 2": {
        "title": "Zone 2 Movement (Moderate)",
        "task": "Brisk walk, light jog, or steady cycling for 10-20 minutes.",
        "education": "Zone 2 is 70-80% max heart rate. Builds aerobic capacity and vagal tone.",
        "type": "movement",
    },
    "Zone 3": {
        "title": "Zone 3 Movement (Intense)",
        "task": "High-intensity interval training, sprinting, or intense sport for 5-15 minutes.",
        "education": "Zone 3 is 80-90% max heart rate. Acute stress + recovery trains nervous system resilience.",
        "type": "movement",
    },
}
```

### API Contract

```json
POST /daily-check

Request: {
  "sleep_hours": 7.5,
  "hydration_rating": 4,
  "food_quality": 3,
  "movement_minutes": 45,
  "stress_level": 3
}

Response (201): {
  "status": "recorded"
}
```

### Acceptance Criteria

- Daily check-in dialog captures all 5 physiological inputs
- `/daily-check` endpoint stores checks in Neo4j
- Correlation analysis identifies top physiological factor (low sleep, high stress, etc.)
- Insight card surfaces top correlate ("Low sleep linked to 2x high-risk loops")
- Movement protocols expanded to Zone 1–3
- Feature flag `FEATURE_DAILY_CHECK` controls UI visibility
- No performance issues with correlation queries on 30-day window

---

## Critical Integration Points

### Data Flow

1. **Entry → Intervention → DailyCheck correlation:**
   - Entry recorded with `emotion_sublabel`
   - User optional completes daily check-in
   - On `/insight`, correlation analysis runs
   - Coaching message updated with "low sleep → 2x high-risk" etc.

2. **Loop path → Education depth:**
   - `get_loop_path()` used to visualize transitions
   - `seen_count` on interventions used to adjust education depth
   - Both query same Neo4j dataset

3. **Weekly tracking → Loop pattern:**
   - `/weekly-summary` aggregates by date
   - `/loop-path` shows transitions
   - History screen unified view with date picker

### Feature Flags

```python
FEATURE_PROGRESSIVE_EDUCATION = os.getenv("FEATURE_PROGRESSIVE_EDUCATION", "false").lower() == "true"
FEATURE_WEEKLY_TRACKING = os.getenv("FEATURE_WEEKLY_TRACKING", "true").lower() == "true"  # Default true (remove cap)
FEATURE_DAILY_CHECK = os.getenv("FEATURE_DAILY_CHECK", "false").lower() == "true"
FEATURE_LOOP_PATH = os.getenv("FEATURE_LOOP_PATH", "false").lower() == "true"
```

---

## Testing Strategy

### Backend Tests

**`test_progressive_education.py`** (3h):
- Intervention seen_count increments
- Education depth selection (introduce/reinforce/deepen)
- Multiple variants with education dicts

**`test_weekly_tracking.py`** (3h):
- `/history` date-range queries
- `/weekly-summary` aggregation accuracy
- Empty result handling

**`test_daily_check.py`** (2h):
- DailyCheck creation
- Correlation analysis (low sleep → high risk)
- DB unavailable fallback

**`test_loop_path.py`** (2h):
- Path extraction from entries
- Cycle detection
- Most common entry identification

### Frontend Tests

- Loop path widget renders without crash
- Weekly scorecard displays comparative arrows
- Daily check-in dialog validation (ranges)
- History screen pagination works with large dataset

---

## Effort Summary

| Task | Backend | Frontend | Total |
|------|---------|----------|-------|
| 6.1 (Progressive Education) | 4h | 3h | 7h |
| 6.2 (Loop Path Visualization) | 5h | 6h | 11h |
| 6.3 (Weekly Tracking) | 5h | 7h | 12h |
| 6.4 (Daily Checks + Correlation) | 6h | 4h | 10h |
| Tests | 10h | 2h | 12h |
| **Subtotal** | **30h** | **22h** | **52h** |

---

## Critical Files Summary

| File | Changes | Phase |
|------|---------|-------|
| `backend/app/interventions.py` | 3-depth education dicts | 6.1 |
| `backend/app/db.py` | 4 new methods (seen_count, loop_path, weekly_summary, daily_check) | 6.1-6.4 |
| `backend/app/main.py` | 3 new endpoints, update /history | 6.1-6.4 |
| `backend/app/models.py` | DailyCheck* models | 6.4 |
| `frontend/lib/screens/journal_screen.dart` | Education expansion, daily check-in UI | 6.1, 6.4 |
| `frontend/lib/screens/history_screen.dart` | Loop path, weekly scorecard, date picker | 6.2, 6.3 |
| `frontend/lib/screens/library_screen.dart` | NEW: Full Rewire education library | 6.1 |
| `frontend/lib/widgets/loop_path_chart.dart` | NEW: Transition flow visualization | 6.2 |
| `frontend/lib/widgets/weekly_scorecard.dart` | NEW: Week-over-week comparison card | 6.3 |
| `frontend/lib/services/api_client.dart` | 4 new API methods | 6.1-6.4 |

---

## Next Steps

1. Review spec for ambiguities or missing edge cases
2. Implement 6.1 (progressive education) first—lowest risk, highest UX impact
3. Implement 6.2 (loop path) in parallel—uses same DB queries as 6.3
4. Implement 6.3 (weekly tracking) after 6.2 complete
5. Implement 6.4 (daily checks) last—requires 6.1-6.3 stable

Recommend starting with **6.1 this sprint**, then **6.2 + 6.3 parallel**, then **6.4**.
