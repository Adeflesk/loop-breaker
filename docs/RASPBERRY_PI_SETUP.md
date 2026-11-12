# Running LoopBreaker on a Raspberry Pi 3 B (1 GB RAM)

LoopBreaker can run 24/7 on a **Raspberry Pi 3 Model B** (~80 MB total RAM) by combining:
1. **Gemini API (`GEMINI_API_KEY`)** — offloads LLM classification from local Ollama (~1.5 GB RAM) to `gemini-3.5-flash-lite` (0 MB local RAM).
2. **Local SQLite (`DB_BACKEND=sqlite`)** — stores all journal entries, loop patterns, daily checks, practices, and environment audits locally on the SD card without Neo4j/JVM (~1 GB RAM).
3. **Single-Process Web Serving (`SERVE_STATIC_WEB=true`)** — FastAPI serves the pre-built Flutter Web app (`frontend/build/web`) directly on port `8000` so you don't need a separate web server or CORS configuration.

---

## Step 1: Build the Flutter Web Bundle on Your Mac
Do not install Flutter or compile the web app on the Pi 3. Build it on your Mac pointing to the same origin (or your Pi's IP):

```bash
cd frontend
flutter build web --release --dart-define=API_URL=""
```

*(Leaving `API_URL=""` lets the web app call the same `http://<pi-ip>:8000` origin that serves it, or pass `--dart-define=API_URL=http://raspberrypi.local:8000`.)*

Copy the repo (including `frontend/build/web`) to your Raspberry Pi 3 (e.g., via `git clone` + `scp -r frontend/build/web pi@raspberrypi.local:~/loop-breaker/frontend/build/`).

---

## Step 2: Run the Pi 3 Setup Script
On your Raspberry Pi 3 (running **Raspberry Pi OS Lite 64-bit**):

```bash
cd ~/loop-breaker
chmod +x scripts/setup_pi3.sh
./scripts/setup_pi3.sh
```

This creates `backend/venv`, installs Python dependencies, configures `backend/.env` with `DB_BACKEND=sqlite` and your `GEMINI_API_KEY`, and prepares a `systemd` unit file so LoopBreaker starts automatically on boot.

---

## Step 3: Open LoopBreaker from Any Device on Your Wi-Fi
Once running, open `http://<pi-ip>:8000` (or `http://raspberrypi.local:8000`) from your phone or laptop browser.
