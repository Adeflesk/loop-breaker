## Runbook

This runbook describes how to run the LoopBreaker stack locally and what to check when something goes wrong.

### Prerequisites

- Python (to run the FastAPI backend).
- Neo4j running locally and accessible via Bolt (default `bolt://localhost:7687`).
- Ollama (or compatible) running a `llama3.2:1b` model on `http://localhost:11434`.
- Flutter SDK (to run the frontend app).

### Backend: FastAPI + Neo4j

1. Change into the backend directory:

```bash
cd backend
```

2. Install Python dependencies:

```bash
pip install -r requirements.txt
```

3. Ensure Neo4j is running and accessible.
4. (Optional) Configure environment variables for backend services:

```bash
export NEO4J_URI=bolt://localhost:7687
export NEO4J_USER=neo4j
export NEO4J_PASSWORD=your_password
export OLLAMA_URL=http://localhost:11434
export OLLAMA_MODEL=llama3.2:1b
```

5. Start the FastAPI app with Uvicorn (example):

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend: Flutter

1. Change into the frontend directory:

```bash
cd frontend
```

2. Fetch dependencies:

```bash
flutter pub get
```

3. Run the app (optionally pointing at a specific backend URL):

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000
```

### Troubleshooting

- **Backend unreachable**
  - Check that the FastAPI server is running on `http://127.0.0.1:8000`.
  - Verify no firewall or port conflict is blocking the requests.

- **Neo4j errors**
  - Confirm Neo4j is running and that credentials/URI match the backend configuration.
  - Check Neo4j logs for connection or authentication errors.

- **AI offline**
  - If the local LLM or Ollama service is not running, the backend falls back to a default classification with lower confidence.
  - Start the Ollama service and ensure the `llama3.2:1b` model is available.

