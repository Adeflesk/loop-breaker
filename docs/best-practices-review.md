# Best Practices Review

Date: 2026-02-12 (Updated: 2026-02-13)
Scope: Backend and frontend (selected core files)

## Status Update (2026-02-13)

**Resolved since initial review:**
- ✅ CORS tightened: explicit origin list + regex-based localhost allowance with credentials (backend/app/main.py)
- ✅ agent_service.py removed from codebase (no longer exists)
- ✅ Neo4j driver lifecycle managed via FastAPI lifespan events (backend/app/db.py, backend/app/main.py)
- ✅ Rewire implementation complete: sublabel persistence, intervention_type contract, trend/streak UI, feature flags

## Findings (ordered by severity)

### High
- ~~CORS allows any origin and credentials at the same time.~~ **RESOLVED** – Now uses explicit allowlist + localhost regex pattern.
  - File: backend/app/main.py
- ~~agent_service.py runs network calls at import time~~ **RESOLVED** – File removed from codebase.
  - ~~File: backend/agent_service.py~~

### Medium
- ~~Neo4j driver created at import with default password~~ **RESOLVED** – Driver now managed in lifespan context with required env credentials.
  - File: backend/app/db.py
- AI and history endpoints swallow errors (print + fallback/empty response) and skip HTTP status checks. This hides failures and complicates debugging.
  - Files: backend/app/ai.py, backend/app/main.py
- History UI assumes fields are always present and valid (intervention and time); substring slicing and string comparisons can crash or misclassify.
  - File: frontend/lib/screens/history_screen.dart

### Low
- TextEditingController is not disposed; and history refresh uses reassemble(). Prefer dispose() and a stateful refresh pattern.
  - Files: frontend/lib/screens/journal_screen.dart, frontend/lib/screens/history_screen.dart

## Remaining Suggested Actions

1. ~~Tighten CORS~~ **DONE**
2. ~~Remove agent_service.py side effects~~ **DONE**
3. ~~Manage Neo4j driver lifecycle~~ **DONE**
4. Use structured logging and return proper HTTP errors instead of silent fallbacks in AI/history endpoints.
5. Harden history UI parsing: null checks, defensive parsing, and safe time formatting.
6. Dispose controllers and refresh data using setState or a notifier instead of reassemble().

## Notes
- Review focused on correctness and maintainability, not feature completeness.
- Most high-priority items resolved during Rewire implementation and port/CORS hardening.
