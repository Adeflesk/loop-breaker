## API Specification

All endpoints are served by the FastAPI backend.

### `POST /analyze`

- **Request body**

```json
{
  "user_text": "I keep putting off my work and feel stuck."
}
```

- **Response body (example)**

```json
{
  "detected_node": "Procrastination",
  "sublabel": "Avoidance",
  "emotion_sublabel": "Avoidance",
  "confidence": 0.87,
  "reasoning": "mentions avoidance and delay",
  "risk_level": "High",
  "loop_detected": true,
  "intervention_title": "The 5-Minute Sprint",
  "intervention_task": "Pick the smallest sub-task and do it for 5 minutes. You can stop after that."
}
```

- `sublabel` is the compatibility field consumed by frontend flows.
- `emotion_sublabel` mirrors the same value for explicit granularity naming.

### `GET /insight`

- **Response body (example)**

```json
{
  "message": "You've disrupted 3 patterns in your top loop. Keep going!",
  "success_rate": 66.67,
  "top_loop": "Stress",
  "trend": "improving",
  "streak": 3
}
```

- `trend` values: `improving`, `stable`, `declining`, `unknown`.
- `streak` is an integer and defaults to `0` if unavailable.

### `GET /history`

- **Response body (example)**

```json
[
  {
    "time": "2025-01-01T12:00:00",
    "state": "Stress",
    "intervention": "Physiological Sigh",
    "confidence": 0.92,
    "was_successful": true
  }
]
```

- Returns up to the latest 20 entries ordered by most recent first.

### `POST /feedback`

- **Request body**

```json
{
  "success": true
}
```

- **Response body**

```json
{
  "status": "recorded"
}
```

### `DELETE /reset`

- **Description**
  - Deletes all `Entry`, `Intervention`, and `Outcome` nodes from Neo4j.

- **Response body**

```json
{
  "status": "Database reset successful"
}
```

- If the database is unavailable, returns `503` with detail `"Database unavailable"`.

