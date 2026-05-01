import logging
import os
import time
import uuid
from contextlib import asynccontextmanager

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Request

try:
    import sentry_sdk
except ImportError:
    sentry_sdk = None
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .ai import query_local_ai
from .db import BehavioralStateManager, create_db_manager
from .interventions import INTERVENTIONS
from .models import AnalysisRequest, AnalysisResponse, FeedbackRequest, InsightResponse

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db = create_db_manager()

    # Initialize Sentry if DSN is provided and sentry_sdk is installed
    sentry_dsn = os.getenv("SENTRY_DSN", "")
    if sentry_dsn and sentry_sdk:
        sentry_sdk.init(dsn=sentry_dsn, traces_sample_rate=0.1)

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


ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3000,http://localhost:8080,http://localhost:5173,"
    "http://127.0.0.1:3000,http://127.0.0.1:8080,http://127.0.0.1:5173",
).split(",")

app = FastAPI(title="LoopBreaker AI Analysis Engine", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    logger.info(
        "request.start",
        extra={
            "event": "request_start",
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
        },
    )
    start_time = time.perf_counter()
    response = await call_next(request)
    latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
    response.headers["X-Request-ID"] = request_id
    logger.info(
        "request.complete",
        extra={
            "event": "request_complete",
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "latency_ms": latency_ms,
        },
    )
    return response


def get_db(request: Request) -> BehavioralStateManager:
    return request.app.state.db


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_behavior(body: AnalysisRequest, request: Request, db: BehavioralStateManager = Depends(get_db)):
    request_id = getattr(request.state, "request_id", "")
    # 1. Get Intelligence from ai.py
    # Returns: {"detected_node": "...", "confidence": 0.0, "reasoning": "..."}
    prediction = await query_local_ai(body.user_text, request_id=request_id)

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
    try:
        risk, is_loop = db.log_and_analyze(
            node,
            prediction["confidence"],
            breaker["title"],
            breaker["task"],
            sublabel=sublabel,
        )
    except Exception:
        logger.error("DB log failed in /analyze", exc_info=True, extra={"request_id": request_id})
        risk, is_loop = "Low", False

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
        "education_info": breaker["education"] if is_loop else "",
        "intervention_type": breaker.get("type") if is_loop else None
    }


@app.get("/insight", response_model=InsightResponse)
async def get_insight(request: Request, db: BehavioralStateManager = Depends(get_db)):
    request_id = getattr(request.state, "request_id", "")
    try:
        stats = db.get_ai_insight()
    except Exception:
        logger.error("Insight retrieval failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Insight service temporarily unavailable")

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
async def get_history(request: Request, db: BehavioralStateManager = Depends(get_db)):
    request_id = getattr(request.state, "request_id", "")
    try:
        return db.get_history()
    except Exception:
        logger.error("History retrieval failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="History service temporarily unavailable")


@app.post("/feedback")
async def receive_feedback(body: FeedbackRequest, request: Request, db: BehavioralStateManager = Depends(get_db)):
    request_id = getattr(request.state, "request_id", "")
    try:
        needs_payload = body.needs_check or body.halt_results
        db.resolve_intervention(body.success, needs_payload)
        return {"status": "recorded"}
    except Exception:
        logger.error("Feedback recording failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Feedback service temporarily unavailable")


@app.get("/stats")
async def get_stats(request: Request, db: BehavioralStateManager = Depends(get_db)):
    request_id = getattr(request.state, "request_id", "")
    try:
        return db.get_trend_stats()
    except Exception:
        logger.error("Stats retrieval failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Stats service temporarily unavailable")


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
