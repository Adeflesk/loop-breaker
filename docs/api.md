## API Specification

All endpoints are served by the FastAPI backend at `http://127.0.0.1:8000`.

---

### `POST /analyze`

Analyzes a journal entry and returns an intervention with full context.

**Request body**

```json
{
  "user_text": "I keep putting off my work and feel stuck."
}
```

**Response body (full example — normal flow)**

```json
{
  "detected_node": "Procrastination",
  "sublabel": "Avoidance",
  "emotion_sublabel": "Avoidance",
  "confidence": 0.87,
  "reasoning": "mentions avoidance and delay",
  "risk_level": "medium",
  "loop_detected": true,
  "intervention_title": "The 5-Minute Sprint",
  "intervention_task": "Pick the smallest sub-task and do it for 5 minutes. You can stop after that.",
  "education_info": "Procrastination is often emotional regulation...",
  "education_depth": "introduce",
  "intervention_type": "cognitive",
  "node_arc_position": 3,
  "node_arc_label": "Node 3 of 8 — Procrastination",
  "intervention_variants": [
    { "title": "The 5-Minute Sprint", "task": "...", "education": "...", "type": "cognitive" }
  ],
  "msc_steps": null,
  "alternatives": null,
  "shame_safety_alert": null,
  "movement_protocol": null,
  "journal_entry_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "personal_loop": {
    "most_common_entry": "Stress",
    "cycle_length_hours": 4.5,
    "where_in_cycle": "procrastination_phase"
  },
  "intervention_effectiveness": {
    "The 5-Minute Sprint": { "helped": 3, "neutral": 1, "didn_help": 0, "total": 4, "percentage": 75 }
  },
  "crisis_detected": null,
  "crisis_resources": null,
  "detected_keywords": null
}
```

**Shame state — msc_steps and alternatives populated**

```json
{
  "detected_node": "Shame",
  "intervention_title": "Mindful Self-Compassion",
  "intervention_task": "Take a breath. Notice what you're feeling without judgment.",
  "msc_steps": [
    { "step": 1, "name": "Mindfulness", "task": "Place a hand on your heart...", "education": "..." },
    { "step": 2, "name": "Common Humanity", "task": "Think of someone else who has felt this...", "education": "..." },
    { "step": 3, "name": "Self-Kindness", "task": "What would you say to a dear friend?", "education": "..." }
  ],
  "alternatives": [
    { "title": "Cognitive Reframe", "task": "Notice the thought... rewrite it.", "education": "...", "type": "cognitive" },
    { "title": "Zone 2 Walk", "task": "Walk at a comfortable pace for 5-10 minutes.", "education": "...", "type": "movement" }
  ]
}
```

**Crisis response — intervention fields are null**

```json
{
  "detected_node": "Crisis",
  "crisis_detected": true,
  "detected_keywords": ["suicide"],
  "crisis_resources": {
    "message": "We're concerned about your safety...",
    "hotlines": [{ "name": "988 Suicide & Crisis Lifeline", "phone": "988", "available": "24/7" }],
    "emergency": "Call 911 for immediate danger"
  },
  "intervention_title": null,
  "intervention_task": null,
  "msc_steps": null,
  "alternatives": null
}
```

**Notes:**
- `sublabel` / `emotion_sublabel` — same value; both present for compatibility.
- `education_depth` — advances `introduce` → `reinforce` → `deepen` as the user sees the same intervention repeatedly (controlled by `FEATURE_PROGRESSIVE_EDUCATION`).
- `msc_steps` — only populated for `detected_node == "Shame"`.
- `alternatives` — up to 2 fallback interventions for the "This isn't helping" cycling UI.

---

### `GET /insight`

**Response body**

```json
{
  "message": "You've disrupted 3 patterns in your top loop. Keep going!",
  "success_rate": 66.67,
  "top_loop": "Stress",
  "trend": "improving",
  "streak": 3,
  "missing_need": "hydration",
  "trigger_count": 2,
  "weekly_activity": [true, false, true, true, false, false, true]
}
```

- `trend` values: `improving`, `stable`, `declining`, `unknown`.
- `weekly_activity` — 7 booleans, Monday–Sunday.

---

### `GET /history`

Optional query params: `start_date`, `end_date` (ISO date strings), `limit` (default 20).

**Response body**

```json
[
  {
    "time": "2026-06-03T12:00:00",
    "state": "Stress",
    "intervention": "Physiological Sigh",
    "confidence": 0.92,
    "was_successful": true
  }
]
```

---

### `GET /stats`

**Response body**

```json
{
  "total_entries": 42,
  "total_loops": 7,
  "success_rate": 71.4,
  "top_state": "Stress",
  "streak": 4
}
```

---

### `GET /loop-path`

Optional query param: `days` (default 30).

**Response body**

```json
{
  "path": ["Stress", "Procrastination", "Overwhelm"],
  "analysis": { "most_common": "Stress", "cycle_length_hours": 6.2 }
}
```

---

### `GET /weekly-summary`

Query param: `week_start` (ISO date string, e.g. `2026-05-26`).

**Response body**

```json
{
  "week_start": "2026-05-26",
  "total_entries": 5,
  "days_with_entries": 4,
  "avg_confidence": 0.72,
  "intervention_success_rate": 80.0,
  "top_states": { "Stress": 3 }
}
```

---

### `POST /feedback`

**Request body**

```json
{
  "success": true,
  "needs_check": { "hydration": true, "sleep": false },
  "chosen_variant": "Somatic Reset"
}
```

**Response body**

```json
{ "status": "recorded" }
```

---

### `GET /journal-entries`

Optional query param: `limit` (default 50).

Returns persisted journal entries with user outcomes.

---

### `PATCH /journal-entries/{entry_id}/outcome`

**Request body**

```json
{ "outcome": "helped", "notes": "Felt calmer after the breathing exercise." }
```

- `outcome` values: `helped`, `didn't help`, `neutral`.

---

### `POST /thought-record`

Requires `FEATURE_THOUGHT_RECORDS=true`.

**Request body**

```json
{
  "situation": "My manager criticised my work in front of the team.",
  "automatic_thought": "I'm terrible at my job.",
  "evidence_for": "The criticism was direct.",
  "evidence_against": "I've received positive reviews in the past.",
  "balanced_thought": "One tough moment doesn't define my overall performance.",
  "linked_node": "Shame"
}
```

---

### `POST /daily-check`

**Request body**

```json
{
  "sleep_hours": 7.5,
  "hydration_rating": 4,
  "food_quality": 3,
  "movement_minutes": 30,
  "stress_level": 2
}
```

**Response body**

```json
{ "status": "recorded" }
```

---

### `DELETE /reset`

Deletes all state nodes from Neo4j.

**Response body**

```json
{ "status": "Database reset successful" }
```

Returns `503` if the database is unavailable.

