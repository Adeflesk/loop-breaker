# Phase 5: Book Fidelity Sprint — Detailed Specifications

**Date:** 2026-05-02  
**Status:** In Development  
**Scope:** 5.1–5.4: Model reconciliation, sublabel routing, thought records, shame protocol  
**Target Duration:** Weeks 1–3

---

## Overview

Phase 5 closes the highest-impact Tier 1 gaps, making LoopBreaker a recognizable implementation of the Rewire framework. This spec provides task-level detail for implementation.

**Key deliverables:**
- 8-node model reconciliation with clear node-to-arc mapping
- Sublabel-driven intervention selection (2–3 options per state)
- Thought Record workflow (4-step guided exercise)
- Enhanced shame protocol (3-step MSC-informed sequence)

---

## 5.1 — 8-Node Model Reconciliation

### Context

**Current state:**
- `BehavioralAgent.Modelfile` defines 8 nodes: Stress, Coping Struggle, Procrastination, Neglect Needs, Hypervigilance, Negative Beliefs, Low Self-Esteem, Shame
- Live system has 7 states: Procrastination, Anxiety, Stress, Shame, Overwhelm, Numbness, Isolation
- `DEFAULT_SUBLABEL = "General"` in `ai.py` conflicts with spec (`"unspecified"`)
- No mapping between the two models

**Decision:** **Option B (Pragmatic Hybrid)** — Keep 7 user-facing states, add invisible mapping to 8-node arc for coaching context and loop position display. No data migration required.

**Rationale:**
- Preserves all user data (zero migration risk)
- Aligns with book framework without retraining the AI model
- Enables "Node X of 8" messaging without state name changes
- Can upgrade to full 8-node model later if needed

### Mapping: 7 Live States → 8-Node Arc

Each live state maps to a position on the 8-node arc:

| Live State | Arc Position(s) | Book Node(s) | Reasoning |
|------------|-----------------|--------------|-----------|
| Stress | 1 | Stress | Direct match |
| Procrastination | 3 | Procrastination | Direct match |
| Anxiety | 2, 5 | Coping Struggle, Hypervigilance | Both have anxious energy |
| Overwhelm | 2, 4 | Coping Struggle, Neglect Needs | Stems from inability to cope or unmet needs |
| Numbness | 7 | Low Self-Esteem | Dissociation/shutdown response |
| Shame | 8 | Shame | Direct match |
| Isolation | 8 | Shame (context) | Shame's social manifestation |

**Sublabel refinement:** Different sublabels can shift position within the range. For example:
- Stress (urgency) = Node 1
- Stress (burnout) = Node 4 (Neglect Needs triggered by overextension)
- Anxiety (panic) = Node 5 (Hypervigilance acute)
- Anxiety (apprehension) = Node 2 (Coping Struggle early)

### 5.1.1 — Data Model Updates

**File:** `backend/app/models.py`

Add to `AnalysisResponse`:
```python
class AnalysisResponse(BaseModel):
    # ... existing fields ...
    detected_node: str
    node_arc_position: Optional[int] = None  # 1-8
    node_arc_label: Optional[str] = None  # e.g., "Node 3 of 8 — Procrastination"
```

**File:** `backend/app/db.py`

No Neo4j schema changes. The arc position is computed at response time, not stored.

### 5.1.2 — AI System Prompt Update

**File:** `backend/app/ai.py`

Update the system prompt to include the 8-node arc in the context, but continue classifying into the 7 live states:

```python
SYSTEM_PROMPT = """
You are a Behavioral Science Specialist in LoopBreaker.

THE 8-NODE REWIRE FEEDBACK LOOP (context only):
1. STRESS — Physiological spikes and overwhelm
2. COPING STRUGGLE — Decreased executive function, difficulty regulating
3. PROCRASTINATION — Avoidance and task delay behaviors
4. NEGLECT NEEDS — Ignoring sleep, food, movement, social connection
5. HYPERVIGILANCE — Heightened sensitivity, anxiety, defensive scanning
6. NEGATIVE BELIEFS — Distorted self-talk, rumination, catastrophizing
7. LOW SELF-ESTEEM — Degraded self-worth, internalized criticism
8. SHAME — Isolation, worthlessness, loop restart condition

YOUR TASK:
Classify the user's journal entry into ONE of these 7 emotional states:
- Procrastination (avoidance, distraction, fear of failure)
- Anxiety (worry, panic, dread, hypervigilance)
- Stress (overload, tension, urgency, burnout)
- Shame (guilt, embarrassment, self-blame, isolation)
- Overwhelm (paralysis, cognitive overload, scattered)
- Numbness (disconnected, apathy, exhaustion, freeze)
- Isolation (loneliness, withdrawal, avoidance of others)

Also extract a specific emotion sublabel and a confidence level.

Respond ONLY with valid JSON:
{
  "detected_node": "Procrastination",
  "emotion_sublabel": "avoidance",
  "confidence": 0.87,
  "reasoning": "User mentions avoiding work tasks and scrolling."
}
"""
```

**Sublabel sets (refined):**
- Procrastination: Avoidance, Perfectionism, Fear of Failure
- Anxiety: Worry, Panic, Dread, Hypervigilance
- Stress: Overload, Tension, Urgency, Burnout
- Shame: Guilt, Embarrassment, Self-Blame, Isolation
- Overwhelm: Paralysis, Cognitive Overload, Scattered
- Numbness: Disconnected, Apathy, Exhaustion, Freeze
- Isolation: Loneliness, Withdrawal, Avoidance of Others

### 5.1.3 — Arc Position Computation

**File:** `backend/app/main.py` (in `/analyze` endpoint)

After calling `clean_ai_response()`, compute the arc position:

```python
ARC_MAPPING = {
    "Stress": (1, "Stress — Physiological Activation"),
    "Procrastination": (3, "Procrastination — Avoidance Pattern"),
    "Anxiety": (2 or 5, "varies by sublabel"),  # 2=Coping Struggle, 5=Hypervigilance
    "Overwhelm": (2 or 4, "varies by trigger"),  # 2=Coping, 4=Neglect
    "Numbness": (7, "Low Self-Esteem — Shutdown State"),
    "Shame": (8, "Shame — Loop Restart"),
    "Isolation": (8, "Shame Context — Social Isolation"),
}

def compute_arc_position(node: str, sublabel: str) -> Tuple[int, str]:
    """Map (node, sublabel) to arc position 1-8."""
    base_pos, base_label = ARC_MAPPING.get(node, (1, "Unknown"))
    
    # Refine based on sublabel for states with range
    if node == "Anxiety":
        if sublabel in ["Hypervigilance", "Panic"]:
            return (5, "Node 5 of 8 — Hypervigilance")
        else:
            return (2, "Node 2 of 8 — Coping Struggle (Anxious)")
    elif node == "Overwhelm":
        if sublabel in ["Scattered", "Cognitive Overload"]:
            return (2, "Node 2 of 8 — Coping Struggle (Overwhelmed)")
        else:
            return (4, "Node 4 of 8 — Neglecting Needs")
    elif node == "Stress":
        if sublabel in ["Burnout", "Exhaustion"]:
            return (4, "Node 4 of 8 — Neglecting Needs (Burnout)")
        else:
            return (1, "Node 1 of 8 — Stress")
    
    return (base_pos, base_label)
```

### 5.1.4 — DEFAULT_SUBLABEL Fix

**File:** `backend/app/ai.py`

Change:
```python
DEFAULT_SUBLABEL = "General"
```

To:
```python
DEFAULT_SUBLABEL = "unspecified"
```

Update `clean_ai_response()` to use this new default.

### 5.1.5 — Frontend Display

**File:** `frontend/lib/screens/journal_screen.dart`

Add to the Status Card (after `detected_node` display):

```dart
// After "Detected: [node] ([sublabel])" line
if (response.nodeArcPosition != null) {
  Text(
    "${response.nodeArcLabel}",
    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
  ),
}
```

Example output:
```
Detected: Stress (Urgency)
Node 1 of 8 — Stress
```

### 5.1.6 — Acceptance Criteria

- [ ] AI system prompt updated with 8-node context but maintains 7-state classification
- [ ] Arc position computed correctly for all 7 states + sublabels
- [ ] `AnalysisResponse` includes `node_arc_position` and `node_arc_label` (optional, non-breaking)
- [ ] Status card displays arc position on UI
- [ ] DEFAULT_SUBLABEL changed to `"unspecified"` throughout
- [ ] All existing tests pass (no breaking changes to endpoints)
- [ ] New unit test: `test_arc_position_mapping.py` covers all state + sublabel combinations

---

## 5.2 — Sublabel-Driven Intervention Selection

### Context

Sublabels are stored but unused for routing. The same intervention plays for all sublabels within a state. Example: "Avoidance" and "Perfectionism" (both Procrastination) benefit from different techniques.

**Goal:** Offer 2–3 intervention options per state, routed by sublabel. User selects preferred approach.

### 5.2.1 — Expanded INTERVENTIONS Catalog

**File:** `backend/app/interventions.py`

Restructure to support multiple options:

```python
INTERVENTIONS = {
    "Procrastination": {
        "default": {  # fallback for unspecified sublabel
            "title": "The 5-Minute Sprint",
            "task": "Pick the smallest sub-task and do it for 5 minutes. You can stop after that.",
            "education": "Procrastination is often 'emotional regulation'—your brain is protecting you from a task that feels threatening.",
            "type": "cognitive"
        },
        "Avoidance": {
            "title": "The 5-Minute Sprint",
            "task": "Pick the smallest sub-task and do it for 5 minutes. You can stop after that.",
            "education": "Avoidance is a protective mechanism. By taking a micro-action, you prove to your brain the threat isn't real.",
            "type": "cognitive"
        },
        "Fear of Failure": {
            "title": "Permission to Imperfect",
            "task": "Set a 10-minute timer and aim for 'good enough' — not perfect. Write one rough paragraph, sketch one idea, or draft one email badly.",
            "education": "Fear of failure stems from perfectionism. Done and imperfect beats perfect and never done. Progress builds confidence.",
            "type": "cognitive"
        },
        "Distraction": {
            "title": "Friction Reduction",
            "task": "Remove one distraction source: close browser tabs, silence notifications, move to a different location for 10 minutes.",
            "education": "Distraction isn't a character flaw—it's an attention hijack. Reducing friction at the environment level works faster than willpower.",
            "type": "cognitive"
        },
    },
    "Anxiety": {
        "default": {
            "title": "5-4-3-2-1 Grounding",
            "task": "Name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, 1 you taste.",
            "education": "Grounding switches your brain from the Default Mode Network (worrying) to the Saliency Network (present reality).",
            "type": "grounding"
        },
        "Hypervigilance": {
            "title": "Safe Space Anchor",
            "task": "Identify one safe place (room, chair, outdoor spot). Close your eyes and recall 3 sensory details: what you heard, felt, smelled there.",
            "education": "Hypervigilance is defensive scanning. Anchoring to a proven-safe memory helps your nervous system recalibrate threat detection.",
            "type": "grounding"
        },
        "Panic": {
            "title": "Physiological Sigh + Box Breathing",
            "task": "Sigh: deep breath + short inhale + long exhale. Then: 4-count in, 4-count hold, 4-count out, 4-count hold. Repeat 3x.",
            "education": "Panic hijacks your breathing. Regulating CO2 and creating rhythm signals safety to your vagus nerve.",
            "type": "breathing"
        },
    },
    "Stress": {
        "default": {
            "title": "Physiological Sigh",
            "task": "Take a deep breath in, followed by a second short sharp inhale, then a long slow exhale.",
            "education": "This is the fastest biological way to offload CO2 and lower your heart rate by activating the Vagus nerve.",
            "type": "breathing"
        },
        "Burnout": {
            "title": "5-Minute Pause Ritual",
            "task": "Stop everything. Drink water. Step outside for 5 minutes or move to a different room. Notice one thing that brings you small joy.",
            "education": "Burnout is accumulated stress without recovery. Even 5-minute pauses reset your nervous system and restore capacity.",
            "type": "grounding"
        },
        "Urgency": {
            "title": "Priority Triage",
            "task": "Write down 3 things you're stressed about. Circle the ONE that, if solved, would relieve the most pressure.",
            "education": "Urgency creates the illusion that everything is equally critical. Triage redirects energy to the highest-leverage action.",
            "type": "cognitive"
        },
    },
    "Shame": {
        "default": {  # expanded in 5.4, kept here for reference
            "title": "The Compassionate Friend (3-Step)",
            "task": "[Multi-step, see 5.4 spec]",
            "education": "Shame thrives in secrecy. Self-compassion breaks the isolation loop.",
            "type": "cognitive"
        },
    },
    "Overwhelm": {
        "default": {
            "title": "Brain Dump",
            "task": "Write down every tiny thing on your mind for 2 minutes. No organizing, just dump.",
            "education": "Overwhelm = full working memory. Externalizing clears 'RAM' and activates executive function.",
            "type": "cognitive"
        },
        "Paralysis": {
            "title": "Start With the Easiest",
            "task": "Identify the one smallest item from your list. Do ONLY that. Nothing else. One thing done beats nothing.",
            "education": "Paralysis breaks when you move. Start absurdly small. Momentum builds from the first action.",
            "type": "cognitive"
        },
        "Scattered": {
            "title": "Single-Tasking Timer",
            "task": "Pick one item. Set a 15-minute timer. Work on only that. After, take a 3-minute break and reassess.",
            "education": "Scattered attention is context-switching overload. Single-tasking with a timer reduces cognitive load and restores focus.",
            "type": "cognitive"
        },
    },
    "Numbness": {
        "default": {
            "title": "Temperature Shock",
            "task": "Hold an ice cube or splash cold water on your face.",
            "education": "Numbness = Freeze response. Intense sensory input safely pulls your nervous system back into the Window of Tolerance.",
            "type": "grounding"
        },
        "Disconnected": {
            "title": "Sensation Inventory",
            "task": "Slowly name 5 physical sensations in your body right now (pressure, temperature, texture, etc.). Don't judge them.",
            "education": "Disconnection severs the mind-body link. Gentle body awareness rebuilds interoception (sensing internal state).",
            "type": "grounding"
        },
    },
    "Isolation": {
        "default": {
            "title": "Low-Stakes Connection",
            "task": "Send a simple 'Thinking of you' or a meme to one person. No deep conversation needed.",
            "education": "Isolation creates a loop that says 'no one cares.' Small, low-friction interactions provide proof to the contrary.",
            "type": "other"
        },
    },
}
```

### 5.2.2 — Routing Logic

**File:** `backend/app/main.py` (in `/analyze` endpoint)

After selecting the intervention, check for sublabel-specific variant:

```python
def get_intervention(node: str, sublabel: Optional[str]) -> dict:
    """Fetch intervention, prioritizing sublabel variant."""
    node_interventions = INTERVENTIONS.get(node, {})
    
    # Try sublabel-specific first
    if sublabel and sublabel in node_interventions:
        return node_interventions[sublabel]
    
    # Fall back to default
    return node_interventions.get("default", {})
```

### 5.2.3 — Multi-Option Selection UI

**File:** `frontend/lib/screens/journal_screen.dart`

When the AI returns multiple options for a sublabel, show a selection dialog before the intervention dialog:

**Flow:**
1. User submits journal entry
2. Status card updates with analysis
3. (Optional) If HALT gate needed, show that first
4. Check: does this node+sublabel have multiple options?
   - If YES: show "Choose Your Approach" dialog
   - If NO: show intervention dialog directly

**Choose Your Approach Dialog** (new widget):

```dart
class InterventionChoiceDialog extends StatelessWidget {
  final String node;
  final List<Intervention> options;  // 2-3 variants
  final Function(Intervention) onSelected;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Choose Your Approach"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Different techniques work for different people. Pick one that resonates:"),
          SizedBox(height: 16),
          ...options.map((option) => 
            Card(
              child: ListTile(
                title: Text(option.title),
                subtitle: Text(option.education, maxLines: 2),
                onTap: () => onSelected(option),
              ),
            )
          ).toList(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Back"),
        ),
      ],
    );
  }
}
```

**Visual example:**
```
┌─────────────────────────────────────┐
│  Choose Your Approach               │
├─────────────────────────────────────┤
│ Different techniques work for       │
│ different people. Pick one:         │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ The 5-Minute Sprint             │ │
│ │ Avoidance is protective...      │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ Permission to Imperfect         │ │
│ │ Done and imperfect beats...     │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ Friction Reduction              │ │
│ │ Distraction isn't a flaw...     │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### 5.2.4 — Data Model Update

**File:** `backend/app/db.py`

Add `intervention_variant` tracking to Outcome node creation:

```python
def log_feedback(entry_id, success, needs_check, intervention_variant=None):
    """Store feedback with chosen intervention variant."""
    outcome_props = {
        "success": success,
        "timestamp": datetime.utcnow(),
        "intervention_title": intervention_variant or "unknown",
        "hydration": needs_check.get("water") if needs_check else None,
        "fuel": needs_check.get("food") if needs_check else None,
        "rest": needs_check.get("rest") if needs_check else None,
        "movement": needs_check.get("movement") if needs_check else None,
    }
    # ... create Outcome node with props
```

### 5.2.5 — API Contract Update

**File:** `backend/app/models.py`

Update `AnalysisResponse`:

```python
class InterventionOption(BaseModel):
    title: str
    task: str
    education: str
    type: str

class AnalysisResponse(BaseModel):
    # ... existing fields ...
    intervention_title: str  # primary/default option
    intervention_task: str
    education_info: Optional[str] = None
    intervention_type: Optional[str] = None
    
    # NEW: alternative options for this node+sublabel
    alternative_interventions: Optional[List[InterventionOption]] = None
```

If `alternative_interventions` is non-empty, the frontend shows the choice dialog.

### 5.2.6 — Acceptance Criteria

- [ ] INTERVENTIONS dict restructured with "default" + sublabel variants for 3+ states
- [ ] `get_intervention()` logic routes by sublabel with fallback
- [ ] `AnalysisResponse` includes `alternative_interventions` list (non-breaking, optional)
- [ ] Frontend renders choice dialog when options present
- [ ] Selected intervention variant tracked in Outcome node
- [ ] Existing single-option states work as before (backward compatible)
- [ ] Unit test: `test_intervention_routing.py` covers all node + sublabel combinations

---

## 5.3 — Cognitive Restructuring / Thought Records

### Context

The book's signature clinical tool is the Thought Record: a 4-step structured exercise for cognitive reframing. Current app has no mechanism for this. Adding it requires:
- New Neo4j node type
- New API endpoints
- New UI screen with 4-step guided flow
- Integration with intervention system

### 5.3.1 — Data Model

**Neo4j Schema:**

```
(:ThoughtRecord {
  id: string (uuid),
  timestamp: datetime,
  user_entry_id: string (links to :Entry),
  situation: string,
  automatic_thought: string,
  evidence_for: string (max 500 chars),
  evidence_against: string (max 500 chars),
  balanced_thought: string,
  related_emotion: string (e.g., "Stress", "Procrastination"),
  related_node: string (1-8 arc position)
})-[:REFRAMES]->(:Entry)
```

**Pydantic Models:**

```python
# backend/app/models.py

class ThoughtRecordRequest(BaseModel):
    situation: str = Field(..., min_length=10, max_length=500)
    automatic_thought: str = Field(..., min_length=5, max_length=500)
    evidence_for: str = Field(..., min_length=0, max_length=500)
    evidence_against: str = Field(..., min_length=0, max_length=500)
    balanced_thought: str = Field(..., min_length=10, max_length=500)
    related_emotion: Optional[str] = None  # e.g., "Procrastination"

class ThoughtRecord(BaseModel):
    id: str
    timestamp: datetime
    situation: str
    automatic_thought: str
    evidence_for: str
    evidence_against: str
    balanced_thought: str
    related_emotion: Optional[str] = None

class ThoughtRecordList(BaseModel):
    records: List[ThoughtRecord]
    total: int
    page: int
```

### 5.3.2 — API Endpoints

**POST /thought-record**

Request:
```json
{
  "situation": "My presentation is next week and I haven't started.",
  "automatic_thought": "I'm going to fail. Everyone will judge me. I'm incompetent.",
  "evidence_for": "I procrastinated on it. I'm not as prepared as others.",
  "evidence_against": "I've delivered successful presentations before. I'm capable. I have a week to prepare.",
  "balanced_thought": "I'm nervous but capable. I can start now and iterate. A good-enough presentation is better than nothing.",
  "related_emotion": "Procrastination"
}
```

Response (201 Created):
```json
{
  "id": "uuid-...",
  "timestamp": "2026-05-02T14:30:00Z",
  "situation": "...",
  "automatic_thought": "...",
  "evidence_for": "...",
  "evidence_against": "...",
  "balanced_thought": "...",
  "related_emotion": "Procrastination"
}
```

**GET /thought-records?page=1&limit=20**

Response (200 OK):
```json
{
  "records": [
    {
      "id": "uuid-...",
      "timestamp": "2026-05-02T14:30:00Z",
      ...
    },
    ...
  ],
  "total": 47,
  "page": 1
}
```

**GET /thought-records/{id}**

Response (200 OK):
```json
{
  "id": "uuid-...",
  "timestamp": "2026-05-02T14:30:00Z",
  ...
}
```

### 5.3.3 — Backend Implementation

**File:** `backend/app/db.py`

```python
def create_thought_record(record_data: dict) -> str:
    """Create a ThoughtRecord node linked to the latest Entry."""
    query = """
    MATCH (e:Entry)
    ORDER BY e.timestamp DESC
    LIMIT 1
    CREATE (tr:ThoughtRecord {
      id: $id,
      timestamp: datetime(),
      situation: $situation,
      automatic_thought: $automatic_thought,
      evidence_for: $evidence_for,
      evidence_against: $evidence_against,
      balanced_thought: $balanced_thought,
      related_emotion: $related_emotion
    })-[:REFRAMES]->(e)
    RETURN tr.id
    """
    result = driver.execute_query(query, {
      "id": str(uuid.uuid4()),
      "situation": record_data.get("situation"),
      "automatic_thought": record_data.get("automatic_thought"),
      "evidence_for": record_data.get("evidence_for"),
      "evidence_against": record_data.get("evidence_against"),
      "balanced_thought": record_data.get("balanced_thought"),
      "related_emotion": record_data.get("related_emotion"),
    })
    return result[0][0]["tr.id"]

def get_thought_records(page=1, limit=20):
    """Fetch paginated thought records."""
    skip = (page - 1) * limit
    query = """
    MATCH (tr:ThoughtRecord)
    RETURN tr
    ORDER BY tr.timestamp DESC
    SKIP $skip
    LIMIT $limit
    """
    records = driver.execute_query(query, {"skip": skip, "limit": limit})
    
    count_query = "MATCH (tr:ThoughtRecord) RETURN count(tr)"
    total = driver.execute_query(count_query)[0][0]["count(tr)"]
    
    return {
      "records": [row[0] for row in records],
      "total": total,
      "page": page
    }

def get_thought_record(record_id: str):
    """Fetch a single thought record."""
    query = "MATCH (tr:ThoughtRecord {id: $id}) RETURN tr"
    result = driver.execute_query(query, {"id": record_id})
    return result[0][0] if result else None
```

**File:** `backend/app/main.py`

```python
@router.post("/thought-record")
async def create_thought_record(request: ThoughtRecordRequest):
    """Create a new thought record."""
    record_id = db.create_thought_record(request.dict())
    record = db.get_thought_record(record_id)
    return ThoughtRecord(**record)

@router.get("/thought-records")
async def list_thought_records(page: int = 1, limit: int = 20):
    """List all thought records."""
    data = db.get_thought_records(page, limit)
    return ThoughtRecordList(**data)

@router.get("/thought-records/{record_id}")
async def get_thought_record(record_id: str):
    """Fetch a single thought record."""
    record = db.get_thought_record(record_id)
    if not record:
        raise HTTPException(status_code=404, detail="Record not found")
    return ThoughtRecord(**record)
```

### 5.3.4 — Frontend: Thought Record Screen

**File:** `frontend/lib/screens/thought_record_screen.dart` (NEW)

4-step guided flow with explanations:

```dart
class ThoughtRecordScreen extends StatefulWidget {
  final String? relatedEmotion;  // optional, pre-filled from intervention
  
  @override
  State<ThoughtRecordScreen> createState() => _ThoughtRecordScreenState();
}

class _ThoughtRecordScreenState extends State<ThoughtRecordScreen> {
  int _currentStep = 0;
  
  final _situationController = TextEditingController();
  final _thoughtController = TextEditingController();
  final _evidenceForController = TextEditingController();
  final _evidenceAgainstController = TextEditingController();
  final _balancedController = TextEditingController();
  
  final List<ThoughtRecordStep> steps = [
    ThoughtRecordStep(
      title: "1. Describe the Situation",
      prompt: "What happened or what are you thinking about?",
      hint: "E.g., 'I procrastinated on my presentation again'",
      field: "situation",
      explanation: "Be specific and factual. Separate the event from your reaction.",
    ),
    ThoughtRecordStep(
      title: "2. Automatic Thought",
      prompt: "What's the thought that popped into your head?",
      hint: "E.g., 'I'm incompetent. I'll fail.'",
      field: "automatic_thought",
      explanation: "This is the immediate, often harsh thought. Don't judge it yet—just write it.",
    ),
    ThoughtRecordStep(
      title: "3. Evidence For & Against",
      prompt: "What evidence supports OR contradicts this thought?",
      hint: "For: 'I procrastinated.' Against: 'I've succeeded before.'",
      field: "evidence",
      explanation: "Be journalist-like: What facts exist? What contradicts the thought?",
      isTwoColumn: true,
    ),
    ThoughtRecordStep(
      title: "4. Balanced Thought",
      prompt: "What's a more balanced, realistic version?",
      hint: "E.g., 'I'm nervous but capable. I can start now and iterate.'",
      field: "balanced_thought",
      explanation: "Not 'toxic positivity.' Just realistic and self-compassionate.",
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Thought Record"),
        leading: BackButton(),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _handleNext,
        onStepCancel: _handlePrevious,
        steps: steps.map((step) => Step(
          title: Text(step.title),
          subtitle: Text(step.explanation),
          content: _buildStepContent(step),
          isActive: _currentStep >= steps.indexOf(step),
        )).toList(),
      ),
    );
  }
  
  Widget _buildStepContent(ThoughtRecordStep step) {
    if (step.isTwoColumn) {
      return Column(
        children: [
          TextField(
            controller: _evidenceForController,
            decoration: InputDecoration(
              labelText: "Evidence For the Thought",
              hintText: step.hint.split(" ").first,
            ),
            maxLines: 3,
          ),
          SizedBox(height: 16),
          TextField(
            controller: _evidenceAgainstController,
            decoration: InputDecoration(
              labelText: "Evidence Against the Thought",
              hintText: step.hint.split(" ").last,
            ),
            maxLines: 3,
          ),
        ],
      );
    }
    
    final controller = {
      "situation": _situationController,
      "automatic_thought": _thoughtController,
      "balanced_thought": _balancedController,
    }[step.field]!;
    
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: step.prompt,
        hintText: step.hint,
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }
  
  void _handleNext() async {
    if (_currentStep < steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      await _submitThoughtRecord();
    }
  }
  
  void _handlePrevious() {
    setState(() => _currentStep--);
  }
  
  Future<void> _submitThoughtRecord() async {
    final request = ThoughtRecordRequest(
      situation: _situationController.text,
      automaticThought: _thoughtController.text,
      evidenceFor: _evidenceForController.text,
      evidenceAgainst: _evidenceAgainstController.text,
      balancedThought: _balancedController.text,
      relatedEmotion: widget.relatedEmotion,
    );
    
    try {
      await ApiClient.createThoughtRecord(request);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Thought record saved. Nice work rewiring! 🧠")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving record: $e")),
      );
    }
  }
  
  @override
  void dispose() {
    _situationController.dispose();
    _thoughtController.dispose();
    _evidenceForController.dispose();
    _evidenceAgainstController.dispose();
    _balancedController.dispose();
    super.dispose();
  }
}
```

### 5.3.5 — Integration with Intervention System

**File:** `frontend/lib/screens/journal_screen.dart`

After user completes an intervention, offer the thought record as a next step:

```dart
// In the intervention dialog's "I feel better" button:
void _handleInterventionSuccess() async {
  await ApiClient.sendFeedback(success: true);
  
  // Show a follow-up prompt
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Dig Deeper?"),
      content: Text(
        "Thought records are a powerful way to reframe the beliefs behind your loop. "
        "Want to do one now?"
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Not now"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ThoughtRecordScreen(
                  relatedEmotion: analysisResponse.detectedNode,
                ),
              ),
            );
          },
          child: Text("Let's try"),
        ),
      ],
    ),
  );
}
```

### 5.3.6 — History Dashboard Integration

**File:** `frontend/lib/screens/history_screen.dart`

Add a "Thought Records" tab or section:

```dart
// In History screen:
DefaultTabController(
  length: 2,
  child: Column(
    children: [
      TabBar(
        tabs: [
          Tab(text: "Journal Entries"),
          Tab(text: "Thought Records (${thoughtRecordCount})"),
        ],
      ),
      Expanded(
        child: TabBarView(
          children: [
            _buildEntryList(),     // existing
            _buildThoughtRecordList(),  // new
          ],
        ),
      ),
    ],
  ),
);

Widget _buildThoughtRecordList() {
  return FutureBuilder<ThoughtRecordList>(
    future: ApiClient.fetchThoughtRecords(page: 1),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
      
      return ListView(
        children: snapshot.data!.records.map((tr) =>
          Card(
            child: ListTile(
              title: Text(tr.automaticThought),
              subtitle: Text(tr.balancedThought),
              trailing: Text(
                DateFormat('MMM d').format(tr.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          )
        ).toList(),
      );
    },
  );
}
```

### 5.3.7 — API Client

**File:** `frontend/lib/services/api_client.dart`

```dart
static Future<ThoughtRecord> createThoughtRecord(ThoughtRecordRequest request) async {
  final response = await http.post(
    Uri.parse('$baseUrl/thought-record'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(request.toJson()),
  );
  
  if (response.statusCode == 201) {
    return ThoughtRecord.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to create thought record');
  }
}

static Future<ThoughtRecordList> fetchThoughtRecords({int page = 1, int limit = 20}) async {
  final response = await http.get(
    Uri.parse('$baseUrl/thought-records?page=$page&limit=$limit'),
  );
  
  if (response.statusCode == 200) {
    return ThoughtRecordList.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to fetch thought records');
  }
}
```

### 5.3.8 — Acceptance Criteria

- [ ] ThoughtRecord Neo4j node created with all 6 fields
- [ ] POST /thought-record endpoint accepts and validates input
- [ ] GET /thought-records endpoint returns paginated list
- [ ] ThoughtRecordScreen implemented with 4-step guided UI
- [ ] Thought records linked to related Entry via :REFRAMES relationship
- [ ] History dashboard shows thought records in a separate tab/section
- [ ] API client methods implemented for CRUD operations
- [ ] Follow-up prompt appears after successful intervention
- [ ] Unit tests: CRUD operations, validation, Neo4j persistence
- [ ] Integration test: full flow from intervention to thought record creation

---

## 5.4 — Enhanced Self-Compassion Protocol for Shame

### Context

Shame (Node 8) is the loop's most dangerous node per the book. Current intervention is a single prompt. Phase 5 replaces it with a 3-step MSC (Mindful Self-Compassion) sequence based on the book's emphasis on self-compassion as the exit ramp from shame spirals.

### 5.4.1 — 3-Step MSC Sequence

The new protocol replaces the single-sentence "Compassionate Friend" with:

**Step 1: Mindfulness (Naming the Pain)**
- Goal: Acknowledge the shame without judgment or amplification
- Prompt: "What you're feeling right now is shame. It's painful. Shame thrives in secrecy. By naming it, you're already beginning to break free."
- Task: Say or write aloud: "I'm experiencing shame right now. It's uncomfortable, and that's okay. This feeling is temporary."

**Step 2: Common Humanity (You're Not Alone)**
- Goal: Counter the shame narrative of "I'm the only one"
- Prompt: "Shame whispers 'you're the only one who feels this way.' But shame is universal. Everyone you know has felt it. You're not broken—you're human."
- Task: Think of someone you admire or love. Recall a moment they struggled or failed. Remind yourself: "Even they experienced shame. Difficulty is part of the human condition."

**Step 3: Self-Kindness (Tender Words)**
- Goal: Offer yourself the compassion you'd give a friend
- Prompt: "Now, speak to yourself with the tenderness you'd use with a person you love deeply. What would you say?"
- Task: Write or say a self-compassionate phrase. Examples: 'I deserve kindness, especially from myself.' 'This mistake doesn't define me.' 'I'm doing the best I can.'

### 5.4.2 — Data Model & Intervention Update

**File:** `backend/app/interventions.py`

```python
INTERVENTIONS = {
    # ... existing ...
    "Shame": {
        "default": {
            "title": "The Compassionate Friend (3-Step)",
            "type": "cognitive",
            "steps": [
                {
                    "step_number": 1,
                    "title": "Mindfulness",
                    "prompt": "What you're feeling right now is shame. It's painful. Shame thrives in secrecy. By naming it, you're breaking free.",
                    "task": "Say aloud: 'I'm experiencing shame right now. It's uncomfortable, and that's okay. This feeling is temporary.'",
                    "education": "Mindfulness means observing emotion without judgment. You don't eliminate shame by ignoring it—you process it.",
                },
                {
                    "step_number": 2,
                    "title": "Common Humanity",
                    "prompt": "Shame whispers 'you're the only one.' But shame is universal. Everyone you know has felt it.",
                    "task": "Think of someone you admire who struggled. Remind yourself: 'Even they experienced shame. Difficulty is human.'",
                    "education": "Common humanity breaks the isolation that fuels shame. Shame grows in secrecy; it withers in connection.",
                },
                {
                    "step_number": 3,
                    "title": "Self-Kindness",
                    "prompt": "Speak to yourself with the tenderness you'd give someone you love deeply.",
                    "task": "Write or say a self-compassionate phrase. E.g., 'I deserve kindness, especially from myself.'",
                    "education": "Self-kindness isn't self-indulgence. It's the antidote to the inner critic that shame amplifies.",
                },
            ],
            "overall_education": "Shame is the final node where the loop restarts. Self-compassion is the neurobiological exit ramp. The three elements of MSC—mindfulness, common humanity, and self-kindness—directly counteract shame's isolating narrative.",
        },
    },
}
```

### 5.4.3 — API Contract

**File:** `backend/app/models.py`

Update `AnalysisResponse` to support multi-step interventions:

```python
class InterventionStep(BaseModel):
    step_number: int
    title: str
    prompt: str
    task: str
    education: str

class AnalysisResponse(BaseModel):
    # ... existing fields ...
    intervention_title: str
    intervention_task: str
    education_info: Optional[str] = None
    intervention_type: Optional[str] = None
    
    # NEW: for multi-step interventions
    intervention_steps: Optional[List[InterventionStep]] = None
```

If `intervention_steps` is populated, the frontend renders a step-by-step dialog instead of a single prompt.

### 5.4.4 — Frontend: Multi-Step Intervention Dialog

**File:** `frontend/lib/screens/journal_screen.dart` (updated)

Create a new widget for multi-step interventions:

```dart
class MultiStepInterventionDialog extends StatefulWidget {
  final String title;
  final List<InterventionStep> steps;
  final String overallEducation;
  final Function(bool) onComplete;  // pass success=true/false
  
  @override
  State<MultiStepInterventionDialog> createState() => _MultiStepInterventionDialogState();
}

class _MultiStepInterventionDialogState extends State<MultiStepInterventionDialog> {
  int _currentStep = 0;
  late PageController _pageController;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }
  
  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    
    return Dialog(
      backgroundColor: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.steps.length, (i) =>
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= _currentStep ? Colors.blue : Colors.grey[300],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            
            // Step content
            Text(
              step.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            
            Text(
              step.prompt,
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your Task:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  Text(
                    step.task,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            
            ExpansionTile(
              title: Text("Why this step?", style: TextStyle(fontSize: 12)),
              children: [
                Text(step.education, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
            SizedBox(height: 24),
            
            // Navigation buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentStep > 0
                    ? () => _pageController.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    )
                    : null,
                  child: Text("Back"),
                ),
                ElevatedButton(
                  onPressed: _handleNext,
                  child: Text(_currentStep == widget.steps.length - 1 ? "Done" : "Next"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _handleNext() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      widget.onComplete(true);  // User completed all steps
      Navigator.pop(context);
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
```

### 5.4.5 — Shame Safety Monitoring

**File:** `backend/app/db.py`

Add logic to detect high-frequency Shame detection:

```python
def check_shame_frequency(time_window_hours=24) -> bool:
    """Check if Shame node has been detected 3+ times in the last N hours."""
    query = """
    MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node {name: "Shame"})
    WHERE e.timestamp > datetime() - duration('PT${time_window_hours}H')
    RETURN count(e) as shame_count
    """
    result = driver.execute_query(query)
    count = result[0][0]["shame_count"]
    return count >= 3

def get_shame_safety_resource():
    """Return a supportive message and resource links for high Shame states."""
    return {
        "message": "You've been through a lot. You're stronger than your shame.",
        "prompt": "If you're having thoughts of self-harm, please reach out to a crisis line.",
        "resources": [
            {
                "name": "Crisis Text Line",
                "text": "Text HOME to 741741"
            },
            {
                "name": "National Suicide Prevention Lifeline",
                "text": "1-800-273-8255"
            }
        ]
    }
```

**File:** `backend/app/main.py`

Add Shame safety check to the `/analyze` response:

```python
@router.post("/analyze")
async def analyze(request: AnalysisRequest):
    analysis = get_ai_analysis(request.user_text)
    intervention = get_intervention(analysis.node, analysis.sublabel)
    
    # Store entry
    entry_id = db.log_entry(request.user_text, analysis)
    
    # Check for Shame safety condition
    shame_safety = None
    if analysis.node == "Shame":
        if db.check_shame_frequency():
            shame_safety = db.get_shame_safety_resource()
    
    return AnalysisResponse(
        detected_node=analysis.node,
        emotion_sublabel=analysis.sublabel,
        confidence=analysis.confidence,
        reasoning=analysis.reasoning,
        risk_level=analysis.risk_level,
        loop_detected=analysis.loop_detected,
        intervention_title=intervention["title"],
        intervention_task=intervention["task"],
        education_info=intervention.get("education"),
        intervention_type=intervention.get("type"),
        intervention_steps=intervention.get("steps"),
        shame_safety_alert=shame_safety,  # NEW field
    )
```

**File:** `backend/app/models.py`

```python
class SafetyResource(BaseModel):
    name: str
    text: str

class ShameSafetyAlert(BaseModel):
    message: str
    prompt: str
    resources: List[SafetyResource]

class AnalysisResponse(BaseModel):
    # ... all existing fields ...
    shame_safety_alert: Optional[ShameSafetyAlert] = None
```

### 5.4.6 — Frontend Safety Flow

**File:** `frontend/lib/screens/journal_screen.dart`

If `shame_safety_alert` is present, show it before the intervention:

```dart
void _showInterventionDialog(AnalysisResponse response) {
  // If shame safety alert, show that first
  if (response.shameSafetyAlert != null) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[50],
        title: Text("We Care About You"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(response.shameSafetyAlert!.message),
            SizedBox(height: 12),
            Text(
              response.shameSafetyAlert!.prompt,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
            ),
            SizedBox(height: 16),
            ...response.shameSafetyAlert!.resources.map((r) =>
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(r.text),
                    ],
                  ),
                ),
              ),
            ).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showShameInterventionDialog(response);
            },
            child: Text("I'm Safe, Continue"),
          ),
        ],
      ),
    );
  } else {
    _showShameInterventionDialog(response);
  }
}

void _showShameInterventionDialog(AnalysisResponse response) {
  if (response.interventionSteps != null && response.interventionSteps!.isNotEmpty) {
    showDialog(
      context: context,
      builder: (context) => MultiStepInterventionDialog(
        title: response.interventionTitle,
        steps: response.interventionSteps!,
        overallEducation: response.educationInfo ?? "",
        onComplete: (success) => _handleInterventionComplete(success),
      ),
    );
  } else {
    // fallback to single-step dialog
    _showSingleStepDialog(response);
  }
}
```

### 5.4.7 — Acceptance Criteria

- [ ] INTERVENTIONS["Shame"] updated with 3-step MSC sequence
- [ ] MultiStepInterventionDialog widget implements step-by-step flow
- [ ] `AnalysisResponse` includes `intervention_steps` list (optional, non-breaking)
- [ ] Shame frequency check implemented in `db.py`
- [ ] Safety alert surfaces when Shame detected 3+ times in 24h
- [ ] Frontend displays safety resources before shame intervention
- [ ] Unit test: `test_shame_frequency.py` tests detection logic
- [ ] Integration test: full flow from Shame detection to 3-step protocol
- [ ] Manual testing: verify step navigation, prompt clarity, resource links

---

## Implementation Order

**Week 1:**
- 5.1: Model reconciliation (2–4h) → arc position computation (3h) → frontend display (2h)
- 5.2: Expand interventions catalog (3h) → routing logic (2h) → choice dialog UI (4h)

**Week 2:**
- 5.3: ThoughtRecord schema (3h) → API endpoints (3h) → guided UI screen (6h)
- 5.3: History integration (3h) → API client (1h)

**Week 3:**
- 5.4: MSC sequence content (1h) → multi-step dialog widget (4h)
- 5.4: Shame frequency monitoring (3h) → safety alert flow (2h)
- Buffer: testing, refinement, bug fixes (5h)

---

## Testing Strategy

### Unit Tests
- `test_arc_position_mapping.py`: All node/sublabel combinations
- `test_intervention_routing.py`: Sublabel-specific selection
- `test_thought_record_validation.py`: Input validation, persistence
- `test_shame_frequency.py`: Frequency detection logic

### Integration Tests
- POST /analyze → arc position in response
- GET /analyze with Procrastination + Fear of Failure → multiple options
- POST /thought-record + GET /thought-records → round-trip persistence
- Shame detected 3 times in 24h → safety alert in response

### Manual/UI Tests
- Journal screen displays arc position correctly
- Choice dialog renders all options, selection routes to correct intervention
- Thought record screen: all 4 steps navigable, data saved
- Shame multi-step: all 3 steps display, "Done" completes dialog
- Safety alert appears, links to resources functional

---

## Rollback Plan

Each task can be rolled back independently:
- **5.1 model:** Revert `ai.py` system prompt, remove arc fields from `AnalysisResponse`
- **5.2 routing:** Revert INTERVENTIONS dict, remove choice dialog UI
- **5.3 thought records:** Drop ThoughtRecord Neo4j nodes, remove endpoints and screens
- **5.4 shame:** Revert INTERVENTIONS["Shame"], remove safety monitoring

Feature flags (if needed):
```python
FEATURE_SUBLABEL_ROUTING = os.getenv("FEATURE_SUBLABEL_ROUTING", "true").lower() == "true"
FEATURE_THOUGHT_RECORDS = os.getenv("FEATURE_THOUGHT_RECORDS", "false").lower() == "true"
FEATURE_SHAME_PROTOCOL = os.getenv("FEATURE_SHAME_PROTOCOL", "false").lower() == "true"
```

---

## Sign-Off

**Status:** Specification complete, ready for implementation  
**Created:** 2026-05-02  
**Owner:** Development Team  
**Next:** Begin Phase 5.1 (Model Reconciliation)
