# Deploying LoopBreaker to Google Cloud Run (Free Tier)

This deploys LoopBreaker as a single container serving both the **FastAPI backend** and the **Flutter Web app** over HTTPS, accessible from your phone anywhere.

---

## Prerequisites
1. **Free Neo4j AuraDB** instance: https://neo4j.com/cloud/platform/aura-graph-database/
   - Save your `NEO4J_URI` (`neo4j+s://...`), `NEO4J_USER` (`neo4j`), and `NEO4J_PASSWORD`.
2. **Free Gemini API Key**: https://aistudio.google.com/apikey
3. **Google Cloud CLI (`gcloud`)** authenticated with a project that has Cloud Run & Cloud Build enabled.

---

## Step 1: Build the Flutter Web Bundle
Run from the repo root so the web app uses relative API URLs (same origin as Cloud Run):

```bash
cd frontend
flutter build web --release --dart-define=BACKEND_BASE_URL=
cd ..
```

---

## Step 2: Deploy to Cloud Run
Pick a private `APP_PASSCODE` so only you can unlock your journal from your phone:

```bash
gcloud run deploy loopbreaker \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --max-instances 1 \
  --set-env-vars "SERVE_STATIC_WEB=true,GEMINI_MODEL=gemini-3.5-flash-lite,NEO4J_URI=neo4j+s://YOUR_ID.databases.neo4j.io,NEO4J_USER=neo4j,NEO4J_PASSWORD=YOUR_NEO4J_PASSWORD,GEMINI_API_KEY=YOUR_GEMINI_KEY,APP_PASSCODE=YOUR_PRIVATE_PASSCODE"
```

---

## Step 3: Open on Your Phone
1. Open the printed `https://loopbreaker-....run.app` URL in Safari (iOS) or Chrome (Android).
2. Enter your `APP_PASSCODE` once (it is saved locally on your phone).
3. Tap **Share → Add to Home Screen** (iOS) or **Install app** (Android) for a full-screen mobile app experience.

