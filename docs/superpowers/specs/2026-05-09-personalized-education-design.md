# Priority 2: Personalized Education — Design Specification

**Date:** 2026-05-09  
**Status:** Design Complete, Ready for Implementation  
**Owner:** Development Team  
**Priority:** High Impact, Low Effort  

---

## Executive Summary

Transform generic interventions into personalized teaching by adding three layers of user context:

1. **Loop Context** — "Your Pattern: Stress → Procrastination → Shame"
2. **Intervention Effectiveness** — "5-Minute Sprint worked 80% for you"
3. **Personalized Education** — "Why this breaks YOUR specific loop"

**Result:** Users see themselves in the teaching. Interventions are trusted because they're based on personal data.

---

## 1. Requirements

### Functional Requirements

**FR1: Calculate Intervention Effectiveness by State+Sublabel**
- Query last 10 journal entries for a given (state, sublabel) pair
- Count outcomes: "helped", "neutral", "didn't help"
- Return percentages only if ≥3 entries with recorded outcomes
- Include only interventions that have been used 3+ times

**FR2: Include Loop Pattern in Every Intervention**
- Fetch user's loop analysis (most_common_entry, cycle_length_hours)
- Show only if 3+ journal entries exist (sufficient data for pattern detection)
- Annotate where user is in their personal cycle

**FR3: Enhance /analyze Response**
- Add `personal_loop` field (loop pattern data)
- Add `intervention_effectiveness` field (effectiveness by intervention)
- Keep response backward-compatible (new fields are optional)

**FR4: Personalize Education Text**
- Rewrite education snippets to reference user's personal data
- Keep existing 3-depth structure (introduce/reinforce/deepen)
- Example: "For YOUR Procrastination, 5-Min Sprint interrupts before Shame kicks in"

### Non-Functional Requirements

**NFR1: Performance**
- DB queries execute within 100ms (acceptable latency for /analyze)
- No caching required initially (fresh data on every request)
- Graceful degradation if Neo4j unavailable

**NFR2: Data Quality**
- Only count outcomes that user has explicitly recorded ("Did this help?")
- Exclude entries without outcome data
- Require minimum threshold (3 uses) to show percentages

**NFR3: UX Consistency**
- Personalization appears only when there's data (no "N/A" placeholders)
- Education remains professional and evidence-based
- No increase in dialog complexity for new users

---

## 2. Data Model

### New Response Fields (in `/analyze`)

```python
class PersonalLoopContext(BaseModel):
    """User's personal behavioral loop pattern."""
    most_common_entry: Optional[str] = None  # e.g., "Stress"
    cycle_length_hours: Optional[float] = None  # e.g., 4.5
    where_in_cycle: Optional[str] = None  # e.g., "procrastination_phase"

class InterventionStats(BaseModel):
    """Effectiveness stats for a single intervention."""
    helped: int
    neutral: int
    didn_help: int
    total: int
    percentage: int  # 0-100

class AnalysisResponse(BaseModel):
    # ... existing fields remain unchanged ...
    
    # NEW FIELDS
    personal_loop: Optional[PersonalLoopContext] = None
    intervention_effectiveness: Optional[Dict[str, InterventionStats]] = None
```

### Data Source

**Journal entries** (already persisted via Neo4j):
```
JournalEntry {
  id: UUID
  timestamp: datetime
  raw_text: string
  detected_state: string
  sublabel: string
  confidence: float
  reasoning: string
  risk_level: string
  intervention_title: string
  intervention_type: string
  user_outcome: "helped" | "didn't help" | "neutral" | null  ← What we query
  user_notes: string (optional)
}
```

---

## 3. Backend Implementation

### 3.1 New DB Method: `get_intervention_effectiveness()`

**Signature:**
```python
def get_intervention_effectiveness(
    self,
    state: str,
    sublabel: Optional[str] = None,
    limit: int = 10,
    min_threshold: int = 3
) -> Dict[str, Dict[str, Any]]:
    """
    Calculate intervention effectiveness for a specific state+sublabel.
    
    Args:
        state: Detected emotional state (e.g., "Procrastination")
        sublabel: Sublabel variant (e.g., "Avoidance")
        limit: Look at last N entries for this state+sublabel (default 10)
        min_threshold: Only include interventions used 3+ times (default)
    
    Returns:
        {
            "5-Minute Sprint": {
                "helped": 8,
                "neutral": 1,
                "didn't_help": 1,
                "total": 10,
                "percentage": 80
            },
            "Breathing": {
                "helped": 2,
                "neutral": 0,
                "didn't_help": 3,
                "total": 5,
                "percentage": 40
            }
        }
    
    Notes:
    - Only counts entries where user_outcome is not null
    - Excludes interventions with < min_threshold uses
    - Returns empty dict if no data
    - Gracefully handles Neo4j unavailability
    """
```

**Neo4j Query:**
```cypher
MATCH (j:JournalEntry)
WHERE j.detected_state = $state
  AND j.sublabel = $sublabel
  AND j.user_outcome IS NOT NULL
RETURN j.intervention_title, j.user_outcome
ORDER BY j.timestamp DESC
LIMIT $limit

# Post-process in Python:
# Group by intervention_title
# Count outcomes
# Calculate percentage
# Filter by min_threshold
```

### 3.2 Existing Method: `analyze_loop_path()`

Already implemented. Ensure it's called in `/analyze`:

```python
def analyze_loop_path(self, days: int = 30) -> Dict[str, Any]:
    """
    Returns:
        {
            "most_common_entry": "Stress",
            "cycle_length_hours": 4.5,
            "total_cycles": 12
        }
    """
```

### 3.3 Update `/analyze` Endpoint

**In main.py, after AI detection:**

```python
@app.post("/analyze", response_model=AnalysisResponse)
async def analyze(body: AnalysisRequest, request: Request, db: BehavioralStateManager = Depends(get_db)):
    # ... existing AI detection logic ...
    
    node = prediction["node"]
    sublabel = prediction.get("sublabel")
    
    # Fetch personal context (non-blocking)
    personal_loop = {}
    intervention_effectiveness = {}
    
    try:
        personal_loop = db.analyze_loop_path(days=30) or {}
    except Exception:
        logger.warning("Failed to fetch loop pattern", exc_info=True)
    
    try:
        intervention_effectiveness = db.get_intervention_effectiveness(
            state=node,
            sublabel=sublabel
        ) or {}
    except Exception:
        logger.warning("Failed to fetch intervention effectiveness", exc_info=True)
    
    # Build response
    response_data = {
        # ... existing fields ...
        "personal_loop": personal_loop if personal_loop else None,
        "intervention_effectiveness": intervention_effectiveness if intervention_effectiveness else None,
    }
    
    return response_data
```

---

## 4. Frontend Implementation

### 4.1 Intervention Dialog Enhancements

**Location:** `frontend/lib/screens/journal_screen.dart` (intervention dialog)

**Three new optional sections:**

#### Section 1: Loop Context Card
Display only if `personal_loop` exists and `most_common_entry` is not null:

```dart
if (response['personal_loop'] != null && 
    response['personal_loop']['most_common_entry'] != null) {
  
  Card(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Pattern', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          SizedBox(height: 8),
          Text(
            '${personalLoop['most_common_entry']} → Procrastination → Shame',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey[800], fontWeight: FontWeight.w600)
          ),
          SizedBox(height: 4),
          Text(
            'Cycle: every ${personalLoop['cycle_length_hours']}h',
            style: TextStyle(fontSize: 11, color: Colors.grey)
          ),
        ],
      ),
    ),
  )
}
```

#### Section 2: Effectiveness Track Record
Display only if `intervention_effectiveness` has entries with ≥3 total uses:

```dart
if (response['intervention_effectiveness'] != null && 
    response['intervention_effectiveness'].isNotEmpty) {
  
  Card(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Track Record', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          SizedBox(height: 8),
          // For each intervention in effectiveness map:
          for (var entry in effectiveness.entries)
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: TextStyle(fontSize: 12)),
                  Text(
                    '${entry.value['percentage']}% worked',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  )
}
```

#### Section 3: Personalized Education
Replace generic education text with personal variant. Backend provides it; frontend just displays:

```dart
Text(
  response['education_info'],  // Now includes personal context
  style: TextStyle(fontSize: 12, color: Colors.blueGrey[700], height: 1.5)
)
```

### 4.2 Data Parsing

```dart
final personalLoop = response['personal_loop'] as Map<String, dynamic>?;
final effectiveness = response['intervention_effectiveness'] as Map<String, dynamic>?;
final educationInfo = response['education_info'] as String? ?? '';
```

---

## 5. Education Text Personalization

**Where:** `backend/app/ai.py` (when building education response)

**Pattern:** Include user's personal data in the education snippet.

**Example transformations:**

| Current (Generic) | Personalized (with user data) |
|---|---|
| "Your amygdala perceives the task as a threat..." | "For YOUR Procrastination, your brain perceives 'work' as threat. A 5-min sprint is too brief for panic to activate. You've found this works 85% of the time..." |
| "This intervention resets your nervous system." | "This interrupts your pattern before Shame kicks in (usually 4 hours after Procrastination starts)." |

**Implementation:**

In the `/analyze` endpoint, after fetching effectiveness data, pass it to the education selection:

```python
# After detecting state + sublabel + fetching effectiveness:
education_context = {
    "state": node,
    "sublabel": sublabel,
    "effectiveness": intervention_effectiveness.get(breaker["title"]),
    "loop_pattern": personal_loop,
}

# Then education selection logic can conditionally include personal data
education_text = build_personalized_education(
    breaker.get("education"),
    education_depth,
    education_context  # NEW
)
```

---

## 6. Error Handling & Fallbacks

### Scenario 1: Neo4j Unavailable
**Behavior:** Return empty dicts for personal_loop and intervention_effectiveness. Frontend skips personalization sections, shows generic intervention.

**Code:**
```python
try:
    personal_loop = db.analyze_loop_path(days=30) or {}
except Exception:
    logger.warning("Loop pattern unavailable", exc_info=True)
    personal_loop = {}  # Empty dict → frontend skips section
```

### Scenario 2: Insufficient Data
**Behavior:** Skip the section if data doesn't meet threshold.

| Threshold | Action |
|-----------|--------|
| < 3 journal entries total | Skip loop context |
| < 3 uses of an intervention | Exclude from effectiveness list |
| 0 outcomes recorded | Skip effectiveness section entirely |

### Scenario 3: New User (First Journal Entry)
**Behavior:** Show generic intervention (no personal data yet). As user journals more, personalization appears automatically.

### Scenario 4: Intervention Not in Effectiveness Data
**Behavior:** Still show it (it's the recommended intervention), just without personal track record.

---

## 7. Data Flow Diagram

```
User journals "I can't start my project"
      ↓
POST /analyze
      ↓
AI detects: Procrastination (Avoidance sublabel)
      ↓
[Parallel queries]
      ├→ analyze_loop_path() → "Stress→Procrastination→Shame every 4.5h"
      ├→ get_intervention_effectiveness("Procrastination", "Avoidance")
      │  → Last 10 entries, outcomes recorded
      │  → "5-Min Sprint: 8 helped, 2 neutral/didn't help"
      └→ Fetch breaker intervention ("5-Minute Sprint")
      ↓
Combine into AnalysisResponse with 3 layers
      ↓
Return to Flutter
      ↓
Frontend renders:
  • Loop context: "Your pattern repeats every 4.5h"
  • Effectiveness: "5-Min Sprint: 80% worked for you"
  • Education: "Why this works for YOUR Procrastination"
  • Task: "Pick one small task..."
```

---

## 8. Testing Strategy

### Unit Tests (Backend)

**Test `get_intervention_effectiveness()`:**
- ✅ Returns percentages only for interventions with 3+ uses
- ✅ Ignores entries without user_outcome
- ✅ Returns correct percentages (helped/total)
- ✅ Handles empty data gracefully
- ✅ Respects limit parameter (last N entries)

**Test `analyze_loop_path()` (already exists):**
- ✅ Detects most_common_entry correctly
- ✅ Calculates cycle_length_hours accurately
- ✅ Handles edge cases (< 3 entries, large gaps)

### Integration Tests

**Test `/analyze` endpoint:**
- ✅ Returns personal_loop when ≥3 entries exist
- ✅ Returns intervention_effectiveness when available
- ✅ Returns both as optional (backward compatible)
- ✅ Gracefully omits sections if data insufficient

### Frontend Tests

**Test intervention dialog rendering:**
- ✅ Displays loop context when personal_loop data exists
- ✅ Displays effectiveness track record when available
- ✅ Skips sections when data is null/empty
- ✅ No layout shift or visual artifacts

### Manual Testing Checklist

- [ ] New user: No personalization shown (expected)
- [ ] After 3 entries: Loop context appears
- [ ] After 3 uses of same intervention on same state: Effectiveness appears
- [ ] Outcome recording: Effectiveness updates on refresh
- [ ] Neo4j down: Generic intervention shown (degraded gracefully)
- [ ] Mobile view: Dialog remains readable with additional content

---

## 9. Implementation Order

1. **Backend DB method** (`get_intervention_effectiveness()`) — 2h
2. **Update /analyze endpoint** to fetch & return new fields — 1h
3. **Frontend: Parse response** and conditional rendering — 1.5h
4. **Frontend: Add UI sections** (loop context, effectiveness, education) — 1.5h
5. **Testing & QA** — 2h

**Total: ~8 hours** (can be done in 1-2 sprints)

---

## 10. Success Criteria

**Code:**
- ✅ New DB method passes unit tests (3+ threshold respected)
- ✅ /analyze returns new fields (optional, backward compatible)
- ✅ Frontend renders all 3 layers correctly
- ✅ Tests pass (unit + integration + manual checklist)

**UX:**
- ✅ Users see their personal loop pattern in intervention dialog
- ✅ Users see which interventions worked best for them
- ✅ Education text reflects personal data, not generic
- ✅ No personalization shown to new users (doesn't feel broken)

**Performance:**
- ✅ /analyze latency remains <500ms with new queries
- ✅ DB queries efficient (indexes on state+sublabel)

---

## 11. Rollout & Monitoring

**Initial rollout:** Feature enabled for all users (no flag needed)

**Metrics to monitor:**
- % of interventions with personal_loop data (target: >70% after 2 weeks)
- % of interventions with intervention_effectiveness (target: >50% after 1 month)
- User engagement with journal history (should increase as data accumulates)
- No performance degradation in /analyze latency

**Rollback:** If issues arise, remove personal_loop & intervention_effectiveness from response in main.py, frontend gracefully skips sections.

---

## 12. Future Enhancements (Out of Scope)

- **Cache effectiveness for 1 hour** (performance optimization if needed)
- **Weekly email:** "Your top 3 interventions this week"
- **Learn Your Loop screen** (Priority 3) — full 8-node education
- **Intervention recommendation engine** — ML-based "try this next"

---

## Appendix: Example Response

```json
{
  "detected_node": "Procrastination",
  "sublabel": "Avoidance",
  "emotion_sublabel": "Avoidance",
  "confidence": 0.92,
  "reasoning": "User describes task avoidance with self-blame, characteristic of procrastination-to-shame pattern.",
  "risk_level": "medium",
  "loop_detected": false,
  "intervention_title": "5-Minute Sprint",
  "intervention_task": "Pick one small task. Set a timer for exactly 5 minutes. Do only that task until time is up.",
  "education_info": "For YOUR Procrastination, your brain perceives 'work' as threat (→ avoidance). A 5-min sprint is too brief for your amygdala to activate. Completing it proves it's safe, rewiring the threat association. You've found this works 85% of the time.",
  "education_depth": "introduce",
  "intervention_type": "movement",
  "node_arc_position": 3,
  "node_arc_label": "Node 3 of 8 — Procrastination",
  "intervention_variants": null,
  "msc_steps": null,
  "shame_safety_alert": false,
  "movement_protocol": null,
  "journal_entry_id": "uuid-here",
  
  "personal_loop": {
    "most_common_entry": "Stress",
    "cycle_length_hours": 4.5,
    "where_in_cycle": "procrastination_phase"
  },
  
  "intervention_effectiveness": {
    "5-Minute Sprint": {
      "helped": 8,
      "neutral": 1,
      "didn't_help": 1,
      "total": 10,
      "percentage": 80
    },
    "Breathing": {
      "helped": 2,
      "neutral": 0,
      "didn't_help": 3,
      "total": 5,
      "percentage": 40
    }
  }
}
```

---

**Document Status:** Complete and ready for implementation planning  
**Next Step:** Invoke writing-plans skill to create detailed implementation plan
