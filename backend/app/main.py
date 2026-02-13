import logging
import os
from contextlib import asynccontextmanager

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware

from .ai import query_local_ai
from .db import BehavioralStateManager, create_db_manager
from .interventions import INTERVENTIONS
from .models import AnalysisRequest, AnalysisResponse, FeedbackRequest, InsightResponse

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db = create_db_manager()

    try:
        url = os.getenv("OLLAMA_URL", "http://localhost:11434")
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{url}/api/tags")
        models = [m["name"] for m in response.json().get("models", [])]

        target = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
        if any(target in m for m in models):
            logger.info("AI Ready: Model '%s' is loaded.", target)
        else:
            logger.warning("AI: Model '%s' not found. Run 'ollama pull %s'", target, target)
    except Exception:
        logger.warning("AI: Ollama service not detected")

    yield

    app.state.db.close()


ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080").split(",")
    if origin.strip()
]
ALLOWED_ORIGIN_REGEX = os.getenv(
    "ALLOWED_ORIGIN_REGEX",
    r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
)

app = FastAPI(title="LoopBreaker AI Analysis Engine", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=ALLOWED_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_db(request: Request) -> BehavioralStateManager:
    return request.app.state.db


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_behavior(request: AnalysisRequest, db: BehavioralStateManager = Depends(get_db)):
    # 1. Get Intelligence from ai.py
    # Returns: {"detected_node": "...", "confidence": 0.0, "reasoning": "..."}
    prediction = await query_local_ai(request.user_text)

    # Ensure the node name matches our DB labels (Title Case)
    node = prediction["detected_node"].title()
    sublabel = (
        prediction.get("emotion_sublabel")
        or prediction.get("sublabel")
        or "General"
    )

    # 2. Get the specific "Circuit Breaker" from interventions.py
    # Defaults to a generic check-in if the AI picks a node not in our dictionary
    breaker = INTERVENTIONS.get(
        node,
        {
            "title": "General Check-in",
            "task": "Take a moment to breathe and observe your surroundings.",
            "education": "Checking in helps move from reactive patterns to conscious awareness."
        }
    )

    # 3. Log to Neo4j via db.py and check for behavioral loops
    # This stores the entry and links it to the Node and Intervention
    risk, is_loop = db.log_and_analyze(
        node,
        prediction["confidence"],
        breaker["title"],
        breaker["task"],
        sublabel=sublabel,
    )

    # 4. Return the full payload to Flutter
    return {
        "detected_node": node,
        "sublabel": sublabel,
        "emotion_sublabel": sublabel,
        "confidence": prediction["confidence"],
        "reasoning": prediction["reasoning"],
        "risk_level": risk,
        "loop_detected": is_loop,
        # Only send intervention details if a loop was actually detected
        "intervention_title": breaker["title"] if is_loop else "",
        "intervention_task": breaker["task"] if is_loop else "",
        "education_info": breaker["education"] if is_loop else ""
    }


@app.get("/insight", response_model=InsightResponse)
async def get_insight(db: BehavioralStateManager = Depends(get_db)):
    stats = db.get_ai_insight()

    if not stats:
        return {
            "message": "Welcome! Start journaling to track your resilience.",
            "success_rate": 0,
            "top_loop": "None",
            "trend": "unknown",
            "streak": 0,
            "missing_need": None,
            "trigger_count": 0,
        }

    loop_count = stats.get("count", 0)
    return {
        "message": stats.get(
            "coaching_message",
            f"You've disrupted {loop_count} patterns in your top loop. Keep going!",
        ),
        "success_rate": round(float(stats.get("success_rate", 0)), 2),
        "top_loop": stats.get("top_loop", "None"),
        "trend": stats.get("trend", "unknown"),
        "streak": int(stats.get("streak", 0)),
        "missing_need": stats.get("missing_need"),
        "trigger_count": int(stats.get("trigger_count", 0)),
    }

@app.get("/history")
async def get_history(db: BehavioralStateManager = Depends(get_db)):
    return db.get_history()


@app.post("/feedback")
async def receive_feedback(request: FeedbackRequest, db: BehavioralStateManager = Depends(get_db)):
    needs_payload = request.needs_check or request.halt_results
    db.resolve_intervention(request.success, needs_payload)
    return {"status": "recorded"}


@app.get("/stats")
async def get_stats(db: BehavioralStateManager = Depends(get_db)):
    stats = db.get_trend_stats()
    return stats


@app.delete("/reset")
async def reset_database(x_confirm_reset: str = Header(None), db: BehavioralStateManager = Depends(get_db)):
    if x_confirm_reset != "CONFIRM":
        raise HTTPException(
            status_code=400,
            detail="Missing or invalid X-Confirm-Reset header. Send 'X-Confirm-Reset: CONFIRM' to proceed.",
        )
    if db.reset_all_data():
        return {"status": "Database reset successful"}
    raise HTTPException(status_code=503, detail="Database unavailable")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
