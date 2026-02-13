## Data Model (Neo4j)

The backend uses Neo4j to store a graph of states, entries, interventions, and outcomes.

### Node Labels

- **`Node`**
  - Represents a psychological state such as `"Stress"`, `"Procrastination"`, `"Anxiety"`, `"Shame"`, `"Overwhelm"`, `"Numbness"`, `"Isolation"`.
  - Properties:
    - `name: string`

- **`Entry`**
  - Represents a single analyzed journal entry.
  - Properties:
    - `timestamp: datetime`
    - `confidence: float`

- **`Intervention`**
  - Represents an intervention suggested for a looped state (e.g., breathing exercise).
  - Properties:
    - `title: string`
    - `task: string`
    - `timestamp: datetime`

- **`Outcome`**
  - Represents user feedback about an intervention.
  - Properties:
    - `success: bool`
    - `timestamp: datetime`

### Relationships

- `(:Entry)-[:RECORDS_STATE]->(:Node)`
  - Connects each entry to the detected state node.

- `(:Entry)-[:HAS_INTERVENTION]->(:Intervention)`
  - Connects an entry to an intervention created when a loop is detected.

- `(:Intervention)-[:HAS_OUTCOME]->(:Outcome)`
  - Connects an intervention to its outcome node when feedback is received.

### Example Subgraph

- A user logs three consecutive entries classified as `"Stress"`.
- The backend detects a loop and attaches an `Intervention` to the latest `Entry`.
- When the user marks that the intervention helped, an `Outcome` node is attached to the `Intervention`.

