# Best Practices Review

Date: 2026-02-12
Scope: Backend and frontend (selected core files)

## Findings (ordered by severity)

### High
- CORS allows any origin and credentials at the same time. Browsers will block this and it is insecure for production. Use an explicit allowlist or disable credentials.
  - File: backend/app/main.py
- agent_service.py runs network calls and prints at import time, and the request has no timeout. This can hang processes and cause side effects.
  - File: backend/agent_service.py

### Medium
- Neo4j driver is created at import with a default password and never closed. Prefer app lifespan setup/teardown and require credentials via environment.
  - File: backend/app/db.py
- AI and history endpoints swallow errors (print + fallback/empty response) and skip HTTP status checks. This hides failures and complicates debugging.
  - Files: backend/app/ai.py, backend/app/main.py
- History UI assumes fields are always present and valid (intervention and time); substring slicing and string comparisons can crash or misclassify.
  - File: frontend/lib/screens/history_screen.dart

### Low
- TextEditingController is not disposed; and history refresh uses reassemble(). Prefer dispose() and a stateful refresh pattern.
  - Files: frontend/lib/screens/journal_screen.dart, frontend/lib/screens/history_screen.dart

## Suggested Actions

1. Tighten CORS: configure explicit origins and disable credentials if not needed.
2. Remove side effects from agent_service.py imports; make it a CLI or a callable module, and add request timeouts.
3. Manage Neo4j driver lifecycle with FastAPI lifespan events and remove default credentials.
4. Use structured logging and return proper HTTP errors instead of silent fallbacks.
5. Harden history UI parsing: null checks, defensive parsing, and safe time formatting.
6. Dispose controllers and refresh data using setState or a notifier instead of reassemble().

## Notes
- Review focused on correctness and maintainability, not feature completeness.
