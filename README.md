🌀 LoopBreaker
LoopBreaker is a behavioral engineering platform designed to identify, track, and disrupt self-reinforcing psychological feedback loops. Specifically, it targets the cycle of stress, procrastination, and distorted beliefs using a "Circuit Breaker" software pattern.

Built natively for Apple Silicon (M3).

🎯 Project Aims
Mapping: Translate subjective emotional states into a Directed Cyclic Graph (DCG).

Detection: Use biometrics (Heart Rate) and digital breadcrumbs (Screen Time) to identify the current "Node" in the cycle.

Intervention: Trigger "Circuit Breakers"—forced UI/UX shifts that require the user to perform a grounding task before continuing.

🛠 The Stack
Frontend: Flutter (Mobile/Desktop) - Handles UI and biometric ingestion.

Backend: Python + FastAPI - The orchestration layer.

Intelligence: Ollama (llama3.2:1b) - Local AI for sentiment analysis and state classification.

Database: Neo4j (Graph) - Stores the relationships between emotional states.

🏗 Project Structure
Plaintext
```
loop-breaker/
├── .github/workflows/ci.yml   # CI for backend + frontend tests
├── ai/                        # Ollama Modelfiles and prompt engineering
├── backend/                   # FastAPI, logic engine, and agent orchestration
│   ├── app/                   # API, AI, DB, models
│   └── tests/                 # Pytest suite
├── database/                  # Neo4j cypher scripts and schemas
├── docs/                      # Research, diagrams, and logic maps
├── frontend/                  # Flutter application logic
│   ├── lib/                   # UI + services
│   └── test/                  # Flutter tests
├── launch_all.sh              # Local launcher (full stack)
├── run_app.sh                 # Local app launcher
└── README.md
```

📚 Docs
- [docs/overview.md](docs/overview.md)
- [docs/backend.md](docs/backend.md)
- [docs/frontend.md](docs/frontend.md)
- [docs/api.md](docs/api.md)
- [docs/data-model.md](docs/data-model.md)
- [docs/runbook.md](docs/runbook.md)
- [docs/best-practices-review.md](docs/best-practices-review.md)
- [docs/rewire-implementation-plan.md](docs/rewire-implementation-plan.md)
- [docs/rewire-specs.md](docs/rewire-specs.md)
- [docs/rewire-backlog.md](docs/rewire-backlog.md)
- [docs/testing-spec.md](docs/testing-spec.md)

✅ CI
GitHub Actions runs backend pytest and frontend Flutter tests on every push and pull request.

🧪 Tests
Backend:
```
python -m pytest backend/tests
```

Frontend:
```
cd frontend
flutter test
```
🧠 The Behavioral Logic (For AI Agents)
The system operates on a 8-Node Feedback Loop. AI agents should refer to this cycle when generating state transition logic:

Stress → Triggered by physiological spikes.

Inability to cope with emotions → Decreased executive function.

Unhelpful coping (Procrastination) → High digital usage/avoidance.

Inability to prioritize needs → Neglecting physical health (sleep/water).

Hypervigilance/Anxiety → Heightened sensitivity to stimuli.

Distorted negative beliefs → Negative self-talk identified via NLP.

Low self-esteem → Long-term state degradation.

Shame → The final gate before the loop restarts at "Stress."

The "Circuit Breaker" Pattern
When the backend identifies a high probability of moving from Node 3 (Procrastination) to Node 4 (Neglecting Needs), the InterventionService must trigger a "hard interrupt" in the frontend.

🚀 Setup for M3
Local AI: ollama serve must be running.

Environment: Use venv in /backend for Python dependencies.

Flutter: Use flutter doctor to ensure the ARM64 toolchain is healthy.

✨ Personalized Education

Every intervention is tailored to the user's personal behavioral patterns and history:

- **Your Loop Pattern** — Shows your detected emotional cycle (e.g., "Stress → Procrastination → Shame repeats every 4.5 hours")
- **Your Track Record** — Displays effectiveness of each intervention you've tried (e.g., "5-Minute Sprint: 80% effective")
- **Personalized Teaching** — Education text references your specific situation (e.g., "For YOUR Procrastination...")

The feature gracefully appears only when sufficient journal data is available, ensuring new users don't see incomplete information.

[View Complete Feature Documentation →](docs/FEATURE-PERSONALIZED-EDUCATION-COMPLETE.md)

🛡 Privacy & Ethics
Zero-Cloud AI: All sentiment analysis stays on-device via Ollama.

Encryption: Personal health data must be encrypted at rest using AES-256.
