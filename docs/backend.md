## Backend Architecture (FastAPI)

The backend exposes a small REST API that classifies journal entries, records them in Neo4j, detects loops, and records intervention outcomes.
It also supports graceful degradation when Neo4j is temporarily unavailable.

### Package Layout

- `backend/app/main.py`
  - Creates the FastAPI application and configures CORS.
  - Defines API endpoints: `/analyze`, `/insight`, `/history`, `/feedback`, `/stats`, `/reset`.
- `backend/app/models.py`
  - Pydantic request models:
    - `AnalysisRequest` (`user_text: str`)
    - `FeedbackRequest` (`success: bool`)
- `backend/app/interventions.py`
  - `INTERVENTIONS` mapping from detected node (e.g., `"Stress"`) to:
    - `title`: short intervention label.
    - `task`: instructions/action for the user.
- `backend/app/db.py`
  - `BehavioralStateManager` class for Neo4j access.
  - Handles node bootstrapping, entry logging, loop detection, intervention outcome recording, and insight aggregation.
  - Catches DB connectivity failures and returns safe defaults instead of crashing process startup.
- `backend/app/ai.py`
  - `query_local_ai(text: str)` helper that sends prompts to the local LLM (via Ollama) and returns structured JSON.
  - Uses strict schema cleaning to produce `detected_node`, `emotion_sublabel`, `confidence`, and `reasoning`.

### Loop Detection Logic

- Every call to `/analyze`:
  - Queries the LLM for classification with granularity (e.g., `Stress` + sublabel).
  - Logs a new `Entry` node linked to a `Node` representing the detected state.
  - Looks at the last 3 `Entry` nodes (most recent first) and checks if they all have the same `Node`.
  - If they are all the same, risk level is `"High"` and a loop is considered detected; otherwise risk is `"Low"`.
  - When a loop is detected, an `Intervention` node may be attached to the latest `Entry`.

### Response Contracts (Current)

- `/analyze` includes both compatibility and explicit granularity fields:
  - `sublabel`
  - `emotion_sublabel`
- `/insight` includes:
  - `message`, `success_rate`, `top_loop`, `trend`, `streak`

### Resilience Behavior

- Backend startup does not hard-fail if Neo4j is unavailable.
- DB-dependent methods return safe fallbacks when connection fails:
  - `/history` returns `[]`
  - `/insight` returns welcome/default insight
  - `/reset` returns `503` when DB is unavailable

