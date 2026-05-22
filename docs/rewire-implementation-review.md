# LoopBreaker Rewire Implementation Review

**Date:** 2026-05-06  
**Scope:** Comprehensive audit of how LoopBreaker implements Rewire book principles  
**Status:** Strong architecture, pedagogical gaps  

---

## Executive Summary

LoopBreaker correctly implements the **mechanisms** (breathing, grounding, cognitive reframing) but misses the core Rewire teaching: helping users **recognize their personal behavioral loop** and understand **why** each intervention breaks it.

**Key Finding:** The data exists to teach users about their loops, but the app doesn't surface it. Users see interventions without context.

**Grade:** B- (Good mechanics, weak teaching)

---

## 1. Rewire Concepts: Coverage Matrix

| Rewire Principle | Implementation | Status | Grade |
|---|---|---|---|
| **Loop Awareness** — Know your trigger → response → consequence cycle | 7 emotional states detected; Phase 6.2 loop visualization | ✅ Partial — lacks *personal* loop mapping | C+ |
| **Nervous System Education** — Teach vagus, parasympathetic, threat response | 3-depth education (introduce/reinforce/deepen) exists | ✅ Present but **not integrated into UX** | C |
| **Intervention Matching** — Right tool for right state | Interventions mapped to 7 states; variants available | ✅ Good | A- |
| **Physiological Awareness** — Sleep, movement, stress correlations | Phase 6.4 adds daily checks and correlation analysis | ✅ In progress | B+ |
| **Repeated Exposure** — Progressive deepening as user learns | `seen_count` tracks exposure; education depth auto-selects | ✅ Good | A |
| **Personal Pattern Recognition** — "My loop repeats every 4 hours starting with Stress" | Phase 6.2 extracts transitions and cycle length | ⚠️ Extracted but **not explained to user** | C |

---

## 2. Critical Gaps

### Gap 1: Education is Hidden
**Problem:**
- ✅ 3-depth education content exists (introduce/reinforce/deepen)
- ❌ Only shown in an expandable tile — users skip it
- ❌ Generic neuroscience, not personal to user's loop
- ❌ No connection to *why this intervention breaks their specific pattern*

**Current UX:**
```
User: "I feel stressed about my deadline"
App:  [Intervention Dialog]
      ├─ Title: "Physiological Sigh"
      ├─ Task: "Inhale for 4 counts, exhale for 8..."
      └─ [Expandable] "Why this works"
            └─ "Your vagus nerve controls parasympathetic activation..."
            
User reaction: "OK I'll try it" (doesn't read expandable)
```

**Needed:**
```
User: "I feel stressed about my deadline"
App:  [Intervention Dialog - PERSONALIZED]
      ├─ Title: "Physiological Sigh"
      ├─ Context: "Your loop: Stress → Procrastination (4h later) → Shame (6h later)"
      ├─ Why now: "You're in the Stress phase. This interrupts before avoidance kicks in."
      ├─ The mechanism: "CO2 resets your threat detector in 90 seconds."
      ├─ Task: "Inhale for 4 counts, exhale for 8..."
      └─ Track: "Did this help?" → Personal effectiveness tracking
```

---

### Gap 2: No "Why" for the 7-State Model
**Problem:**
- App detects emotional states but never explains **the loop**
- Users don't understand: *How does Stress → Procrastination → Shame?*
- **Missing:** Explanation of the feedback mechanism

**What's in code (from `ai.py`):**
```python
THE 8-NODE REWIRE FEEDBACK LOOP:
1. STRESS — Physiological spikes and overwhelm
2. COPING STRUGGLE — Decreased executive function, difficulty regulating
3. PROCRASTINATION — Avoidance and task delay behaviors
4. NEGLECT NEEDS — Ignoring sleep, food, movement, social connection
5. HYPERVIGILANCE — Heightened sensitivity, anxiety, defensive scanning
6. NEGATIVE BELIEFS — Distorted self-talk, rumination, catastrophizing
7. LOW SELF-ESTEEM — Degraded self-worth, internalized criticism
8. SHAME — Isolation, worthlessness, loop restart condition
```

**What user sees:** "Detected: Stress (Tension)"

**Gap:** The loop sequence is invisible.

---

### Gap 3: Interventions Lack Context
**Current:**
- ✅ "Do 5-minute sprint for Procrastination"
- ❌ No explanation: "This works because it shrinks the task below the threat threshold"
- ❌ No variant guidance: "Try breathing first (Stress), grounding second (Anxiety), cognitive reframe last (Procrastination)"

**Missing:**
1. State-specific explanations ("Why Procrastination happens")
2. Intervention mechanism ("Why this intervention works")
3. When to use alternatives ("When to choose a different variant")

---

### Gap 4: Journal Not Persisted
**Currently:** 
- Entries analyzed → Intervention shown → Forgotten
- No way to review patterns or improvement
- Can't correlate entries with outcomes

**Why This Matters:**
- Users can't see their loop in action
- No way to learn which interventions work *for them*
- Can't track progress ("I used to feel Shame daily, now it's weekly")
- Misses Rewire's core teaching: **recognizing your personal pattern**

**Recommendation:** YES, save journals. See Section 5 for data model.

---

## 3. Current State: By Screen

### Journal Screen (Grade: C)
**What it does:**
- ✅ Accepts journal entry
- ✅ Detects state + sublabel + confidence
- ✅ Shows intervention dialog

**What's missing:**
- ❌ Explains why the detected state matters
- ❌ Connects to user's personal loop
- ❌ Saves entry for later review
- ❌ Shows which interventions worked before
- ❌ Tracks outcomes

**Impact:** Users get a tool but not the understanding.

---

### History Screen (Grade: C+)
**Current:**
- List of past entries (coming in Phase 6.2)

**What's missing:**
- ❌ Loop visualization without explanation
- ❌ No annotation like "Your Stress → Procrastination repeats every 4 hours"
- ❌ No correlation with daily check-ins
- ❌ No progress tracking

**Phase 6.2 adds:** Loop path chart (timeline visualization)  
**Still needs:** Annotation explaining the pattern

---

### Intervention Dialog (Grade: C)
**Current:**
- Title + task
- Expandable "Why this works" with 3-depth education

**Problems:**
- ✅ Education exists but hidden
- ❌ Generic ("Your vagus nerve...") not personal ("Your loop shows...")
- ❌ No variants guidance
- ❌ No outcome tracking

---

### Thought Records Tab (Grade: B)
**Strength:** Good CBT foundation (capture beliefs, challenge them)  
**Weakness:** Disconnected from Rewire teaching — feels like separate feature

---

### Library Screen (Phase 6.5 planned) (Grade: A — if done right)
**Plan:** All 7 states × 3 education levels  
**Opportunity:** Could be the "Learn Your Loop" hub if designed right

**Risk:** Will be generic education, not personal patterns

---

### Loop Path Chart (Phase 6.2) (Grade: C+)
**What it shows:** Timeline of state transitions  
**What it's missing:** 
- ❌ No annotation ("This is your pattern")
- ❌ No explanation of *why* states flow together
- ❌ No guidance ("What breaks this cycle?")

---

### Daily Check-In (Phase 6.4) (Grade: B)
**Strength:** Tracks physiological factors (sleep, hydration, stress)  
**Weakness:** Not connected to states or interventions

**Missing:**
- ❌ Correlation explanation
- ❌ Link to intervention guidance ("Low sleep → avoid Procrastination, focus on rest")

---

## 4. Visual Plan: Current vs. Proposed Architecture

### Current Data Flow
```
Journal Entry
    ↓
[AI Analysis] → Detect: State + Sublabel + Confidence
    ↓
[Intervention Selection] → Match state to intervention
    ↓
[Show Dialog] → Title + Task + [Expandable Education]
    ↓
[Forgotten] → No persistence, no outcome tracking, no pattern learning
```

**Problem:** User sees *what* but not *why* or *how it helps their loop*

---

### Proposed Data Flow (Rewire-Aligned)
```
┌─────────────────────────────────────────────────────────────┐
│  JOURNAL ENTRY                                              │
│  "I can't start my project and I feel terrible about it"   │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│  AI ANALYSIS                                                │
│  ├─ State: Procrastination → Shame (double detection)       │
│  ├─ Confidence: 0.92 (high)                                │
│  └─ Reasoning: Avoidance + self-blame                       │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│  PERSONALIZATION LAYER ← NEW                                │
│  ├─ Fetch user's loop pattern (from Phase 6.2)             │
│  │   "Your Procrastination usually follows Stress (2-4h)"   │
│  ├─ Check previous entries                                  │
│  │   "Shame follows Procrastination 70% of the time"        │
│  └─ Check past interventions for this state                 │
│      "You chose 5-Minute Sprint last time (worked: Yes)"    │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│  SHOW INTERVENTION (PERSONALIZED)                           │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ STATE: Procrastination → Moving toward Shame             ││
│  │ ┌─────────────────────────────────────────────────────┐ ││
│  │ │ Your Pattern:                                       │ ││
│  │ │ Stress (2pm) → Procrastination (4pm) → Shame (8pm) │ ││
│  │ │                                                     │ ││
│  │ │ You're here: [PROCRASTINATION] (urgent stop needed)│ ││
│  │ └─────────────────────────────────────────────────────┘ ││
│  │                                                         ││
│  │ RECOMMENDED: 5-Minute Sprint                            ││
│  │ Why: Breaks avoidance before Shame kicks in (30% odds)  ││
│  │                                                         ││
│  │ [EDUCATION CARD] (auto-shown, not expandable)           ││
│  │ ┌─────────────────────────────────────────────────────┐ ││
│  │ │ How it works:                                       │ ││
│  │ │ Avoidance is threat-perception. Your brain says     │ ││
│  │ │ "Project = danger." A 5-min window is too brief     │ ││
│  │ │ for your amygdala to activate. You feel the         │ ││
│  │ │ accomplishment (proof it's safe), rewiring the      │ ││
│  │ │ threat association.                                 │ ││
│  │ │                                                     │ ││
│  │ │ For YOUR Procrastination:                           │ ││
│  │ │ - Breathing works: 40% (less effective for you)     │ ││
│  │ │ - 5-Min Sprint works: 85% (your best tool)         │ ││
│  │ │ - Reframe works: 60% (good backup)                  │ ││
│  │ └─────────────────────────────────────────────────────┘ ││
│  │                                                         ││
│  │ TASK: Pick one small task. Do it for exactly 5 min.    ││
│  │ [Start] [Skip]                                          ││
│  └─────────────────────────────────────────────────────────┘│
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│  SAVE & TRACK ← NEW                                         │
│  ├─ Save entry with label (user can edit)                  │
│  ├─ Ask: "Did this help?" → Track effectiveness            │
│  └─ Offer note-taking: "What happened next?"               │
│      (builds personal loop awareness)                       │
└──────────────────┬──────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────────────┐
│  HISTORICAL VIEW (Phase 6 + Journal Persistence)            │
│  ├─ Timeline showing ALL entries                            │
│  ├─ Pattern annotation: "Procrastination → Shame in 4h"     │
│  ├─ Intervention tracking: "5-Min Sprint: 85% effectiveness"│
│  └─ Progress: "Shame reduced from daily → 2x/week"         │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Implementation Recommendations

### Priority 1: Journal Persistence (High Impact, Medium Effort)

**Data Model:**
```python
class JournalEntry(BaseModel):
    id: str  # UUID
    user_id: str
    timestamp: datetime
    raw_text: str  # User's journal entry
    
    # AI Analysis
    detected_state: str  # e.g., "Procrastination"
    sublabel: str  # e.g., "Avoidance"
    confidence: float  # 0.0-1.0
    reasoning: str
    
    # Intervention Given
    intervention_title: str  # e.g., "5-Minute Sprint"
    intervention_type: str  # breathing|grounding|cognitive|movement
    
    # User Outcome
    user_label: Optional[str]  # "Procrastination" → user can correct
    user_outcome: Optional[str]  # "helped" | "didn't help" | "neutral"
    user_notes: Optional[str]  # Follow-up thoughts
    
    # Derived
    is_loop_start: Optional[bool]  # Does this state trigger the loop?
    follows_state: Optional[str]  # What state preceded this?
```

**New Endpoints:**
```
POST /journal
  Body: {"text": "...", "label": "..."} → returns JournalEntry

GET /journal?start_date=...&end_date=...&limit=100
  Returns: List[JournalEntry]

GET /journal/analysis
  Returns: {
    "most_common_state": "Procrastination",
    "state_frequency": {"Procrastination": 15, "Shame": 10, ...},
    "loop_pattern": {
      "entry_point": "Stress",
      "most_common_sequence": ["Stress", "Procrastination", "Shame"],
      "cycle_time_hours": 4.5
    },
    "intervention_effectiveness": {
      "Procrastination": {
        "5-Minute Sprint": {"worked": 8, "total": 10},  // 80%
        "Breathing": {"worked": 2, "total": 5}  // 40%
      }
    }
  }

POST /journal/:id/outcome
  Body: {"outcome": "helped"|"didn't help", "notes": "..."} → Update entry
```

---

### Priority 2: Personalize Intervention Education (High Impact, Low Effort)

**Current:**
```
"Your vagus nerve controls parasympathetic activation..."
```

**New:**
```
"Your loop: Stress (peak 2pm) → Procrastination (peak 4pm) → Shame (peak 8pm)

You're in the Procrastination phase. A 5-minute sprint works because it 
shrinks the task below your threat threshold before Shame kicks in.

Your track record: 5-Minute Sprint worked 8/10 times. Breathing: 2/5 times.
This intervention is your best bet right now."
```

**Implementation:**
1. In `/analyze` endpoint, fetch user's personal loop (from Phase 6.2)
2. Fetch intervention effectiveness (from new `/journal/analysis` endpoint)
3. Include in `AnalysisResponse`:
   ```python
   class AnalysisResponse(BaseModel):
       # ... existing fields ...
       education_depth: str
       education_info: str
       # NEW:
       personal_context: Optional[str]  # "Your loop pattern is..."
       intervention_effectiveness: Optional[Dict[str, float]]  # "5-Min Sprint: 85%"
   ```

---

### Priority 3: Add "Learn Your Loop" Section (Medium Impact, Medium Effort)

**Create new screen/tab:** `lib/screens/loop_education_screen.dart`

**Contents:**
1. **The 8-Node Model** — Explain the feedback loop
   ```
   STRESS (overload)
       ↓
   COPING STRUGGLE (dysregulation)
       ↓
   PROCRASTINATION (avoidance) ← YOU ARE HERE
       ↓
   NEGLECT NEEDS (sleep/food/movement)
       ↓
   HYPERVIGILANCE (threat detection up)
       ↓
   NEGATIVE BELIEFS (rumination)
       ↓
   LOW SELF-ESTEEM (self-criticism)
       ↓
   SHAME (isolation, loop restarts)
       ↓
   [Back to STRESS]
   ```

2. **Your Personal Loop** — Show from `/journal/analysis`
   ```
   Your pattern (based on your entries):
   STRESS (Mon 2pm) → 
   PROCRASTINATION (Mon 4pm) [70% of the time] → 
   SHAME (Mon 8pm) [50% of the time]
   
   Cycle time: ~4-6 hours
   Most effective interruption: 5-Minute Sprint (breaks at Procrastination stage)
   ```

3. **How to Break It** — Interactive
   ```
   [Interactive] Choose a state to see interventions:
   - Catch it at STRESS → Use breathing (fastest reset)
   - Catch it at PROCRASTINATION → Use 5-Min Sprint (shrink threat)
   - Catch it at SHAME → Use compassion practice (rebuild self-worth)
   ```

---

### Priority 4: Track & Visualize Intervention Effectiveness (Medium Impact, High Effort)

**In History/Analysis screens, show:**
```
INTERVENTION EFFECTIVENESS (Your Data)
┌─────────────────────────┬──────────┬──────────┐
│ Intervention            │ Success  │ Count    │
├─────────────────────────┼──────────┼──────────┤
│ 5-Minute Sprint         │ 85% ✓    │ 10 uses  │
│ Physiological Sigh      │ 70% ✓    │ 7 uses   │
│ 5-4-3-2-1 Grounding     │ 60%      │ 5 uses   │
│ Breathing (general)     │ 40%      │ 5 uses   │
│ Reframe (cognitive)     │ 75% ✓    │ 4 uses   │
└─────────────────────────┴──────────┴──────────┘

YOUR BEST TOOLS:
1. For Procrastination: 5-Minute Sprint (85%)
2. For Anxiety: Physiological Sigh (70%)
3. For Shame: Reframe + Compassion (75%)
```

---

## 6. Phase 6 Integration Points

### Phase 6.1: Progressive Education
**Current:** 3-depth education dicts  
**Add:** Personalization layer using user's loop pattern

**Change in `ai.py`:**
```python
async def query_local_ai_with_context(
    text: str,
    user_loop_pattern: Optional[Dict] = None,  # From Phase 6.2
    intervention_effectiveness: Optional[Dict] = None,  # From journal
    request_id: str = "",
) -> Dict[str, Any]:
    """
    Include personal context in system prompt for Claude.
    """
    personal_context = ""
    if user_loop_pattern:
        personal_context += f"\nUser's Loop: {user_loop_pattern['pattern']}\n"
    if intervention_effectiveness:
        personal_context += f"\nWhat works for this user: {intervention_effectiveness}\n"
    
    # Add to SYSTEM_PROMPT before sending
```

---

### Phase 6.2: Loop Path Visualization
**Current:** Timeline showing state transitions  
**Add:** Annotation explaining the loop

**Change in `loop_path_chart.dart`:**
```dart
// Instead of just showing timeline, add:
Text(
  'Your Pattern: ${analysis['most_common_entry']} '
  '→ [next state] (every ${analysis['cycle_length_hours']}h)',
  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
),
Text(
  'Most effective intervention at this stage: ${recommendedIntervention}',
  style: TextStyle(fontSize: 12, color: Colors.blue),
),
```

---

### Phase 6.3: Weekly Tracking
**Current:** Aggregated stats  
**Add:** State correlation with physiology

**Show:**
```
THIS WEEK'S PATTERN
Sleep < 6h: Stress appears 3x more often
Movement < 30m/day: Procrastination increases 2x
Stress level ≥ 4: Shame appears within 4-6 hours

Recommendation: Prioritize movement on high-stress days to break cycle earlier
```

---

### Phase 6.4: Daily Checks
**Current:** Track sleep, hydration, movement, stress  
**Add:** Link to intervention guidance

**Show:**
```
TODAY'S PHYSIOLOGY
Sleep: 5.5h (LOW) ⚠️
Movement: 15m (LOW) ⚠️
Stress: 4/5 (HIGH) ⚠️

ALERT: Based on your pattern, you're at risk for Procrastination → Shame today
RECOMMENDATION: Start with movement (breaks stress cycle before avoidance)
```

---

## 7. New Feature: Journal Persistence Screen

### Screen 1: Journal List
```dart
class JournalListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Your Journal')),
      body: FutureBuilder<List<JournalEntry>>(
        future: ApiClient.getJournal(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final entry = snapshot.data![index];
              return ListTile(
                title: Text(entry.detected_state),
                subtitle: Text(entry.raw_text.substring(0, 50)),
                trailing: Icon(
                  entry.user_outcome == "helped" 
                    ? Icons.check_circle 
                    : Icons.circle,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JournalEntryDetail(entry: entry),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

### Screen 2: Journal Entry Detail + Outcome
```dart
class JournalEntryDetail extends StatefulWidget {
  final JournalEntry entry;
  
  @override
  State<JournalEntryDetail> createState() => _JournalEntryDetailState();
}

class _JournalEntryDetailState extends State<JournalEntryDetail> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Entry Details')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Original entry text
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What you wrote:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(widget.entry.raw_text),
                  SizedBox(height: 12),
                  Text('Timestamp: ${widget.entry.timestamp}', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          
          // AI Analysis
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analysis:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('State: ${widget.entry.detected_state} (${widget.entry.sublabel})'),
                  Text('Confidence: ${(widget.entry.confidence * 100).toInt()}%'),
                  SizedBox(height: 8),
                  Text('AI Reasoning:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(widget.entry.reasoning),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          
          // Intervention Given
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Intervention Shown:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(widget.entry.intervention_title),
                  Text('Type: ${widget.entry.intervention_type}'),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          
          // Did it help?
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Did this help?', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.check),
                        label: Text('Yes'),
                        onPressed: () => _recordOutcome('helped'),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.close),
                        label: Text('No'),
                        onPressed: () => _recordOutcome('didn\'t help'),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.remove),
                        label: Text('Neutral'),
                        onPressed: () => _recordOutcome('neutral'),
                      ),
                    ],
                  ),
                  if (widget.entry.user_outcome != null)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'You marked: ${widget.entry.user_outcome}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          
          // Notes
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    initialValue: widget.entry.user_notes ?? '',
                    decoration: InputDecoration(hintText: 'What happened next?'),
                    onChanged: (val) => _saveNotes(val),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _recordOutcome(String outcome) async {
    await ApiClient.recordOutcome(widget.entry.id, outcome);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recorded: $outcome')),
    );
  }
  
  void _saveNotes(String notes) async {
    await ApiClient.updateJournalNotes(widget.entry.id, notes);
  }
}
```

---

## 8. Summary: What Changes?

| Component | Current | Proposed | Impact |
|---|---|---|---|
| **Journal** | Analyze & forget | Analyze, save, track outcomes | Users learn what works *for them* |
| **Education** | Generic neuroscience | Personal + generic | Users see how interventions fit *their loop* |
| **Loop Path** | Timeline visualization | Timeline + annotation ("This is your pattern") | Users *understand* their loop, not just see it |
| **Interventions** | One-size-fits-all | Personalized ("You rated 5-Min Sprint 85% effective") | Users trust recommendations |
| **Learning** | No "Learn Your Loop" section | New screen explaining 8-node model + personal loop | Core Rewire teaching is explicit |
| **Tracking** | No outcome tracking | "Did this help?" + effectiveness dashboard | Data-driven, personalized guidance |

---

## 9. Timeline & Effort Estimate

| Feature | Effort | Timing | Dependencies |
|---|---|---|---|
| Journal persistence (backend) | 3h | Weeks 1-2 | None |
| Journal list UI (frontend) | 2h | Weeks 1-2 | Backend complete |
| Personalize education (backend) | 2h | Week 2 | Phase 6.2 loop analysis |
| Personalize education (frontend) | 1h | Week 2 | Backend changes |
| Learn Your Loop screen | 4h | Week 3 | Journal data, UI design |
| Outcome tracking (backend + frontend) | 3h | Week 3 | Journal persistence done |
| Intervention effectiveness dashboard | 3h | Week 4 | Outcome tracking done |
| **Total** | **~18h** | **Weeks 1-4** | Parallel-able tasks |

---

## 10. Why This Matters: Rewire Principle

**Rewire Book Core Teaching:**
> "Your loop is uniquely yours. Once you see it, you can interrupt it. Each intervention is a specific lever in your personal feedback system."

**What we're missing:** The *seeing* part. Users get tools but not the mirror.

**What we're adding:** The mirror. Journal persistence + personal pattern recognition + effectiveness tracking = users see their loop and learn what breaks it.

**Result:** Users don't just breathe better — they *understand why* and *when*.

---

## Appendix: Quick Reference

### Data Added to `/analyze` Response
```json
{
  "detected_state": "Procrastination",
  "sublabel": "Avoidance",
  "confidence": 0.92,
  
  // NEW: Personal context
  "personal_context": {
    "loop_pattern": "Stress (2pm) → Procrastination (4pm) → Shame (8pm)",
    "cycle_time_hours": 4.5,
    "where_in_cycle": "procrastination_phase"
  },
  
  // NEW: Personalized recommendation
  "recommended_interventions": [
    {
      "title": "5-Minute Sprint",
      "your_effectiveness": 0.85,  // 85% of times you used it, it helped
      "usage_count": 10,
      "reason": "Breaks avoidance before shame kicks in"
    }
  ],
  
  // ENHANCED: Education is now personal
  "education_info": {
    "generic": "Avoidance is threat-perception. Your brain says 'Project = danger.'...",
    "personal": "For YOUR Procrastination: 5-Min Sprint works 85% of the time. Breathing works only 40%. This intervention is your best bet.",
    "depth": "introduce"  // or "reinforce", "deepen"
  }
}
```

### New Database Schema
```sql
CREATE TABLE journal_entries (
  id UUID PRIMARY KEY,
  user_id UUID,
  timestamp DATETIME,
  raw_text TEXT,
  
  detected_state VARCHAR(50),
  sublabel VARCHAR(50),
  confidence FLOAT,
  reasoning TEXT,
  
  intervention_title VARCHAR(100),
  intervention_type VARCHAR(20),
  
  user_label VARCHAR(50),  -- User can correct AI
  user_outcome VARCHAR(20),  -- "helped" | "didn't help" | "neutral"
  user_notes TEXT,
  
  created_at DATETIME,
  updated_at DATETIME
);

CREATE INDEX idx_user_state ON journal_entries(user_id, detected_state);
CREATE INDEX idx_user_timestamp ON journal_entries(user_id, timestamp DESC);
```

---

**Document Created:** 2026-05-06  
**Review Author:** Claude (AI Assistant)  
**Status:** Ready for team review and implementation planning
