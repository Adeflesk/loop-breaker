import logging
import os
import time
import uuid
from contextlib import asynccontextmanager
from typing import List, Optional

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
from .models import (
    AnalysisRequest,
    AnalysisResponse,
    FeedbackRequest,
    InsightResponse,
    ThoughtRecordRequest,
    ThoughtRecordResponse,
)

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

# Phase 5 Feature Flags
FEATURE_SUBLABEL_ROUTING = os.getenv("FEATURE_SUBLABEL_ROUTING", "true").lower() == "true"
FEATURE_THOUGHT_RECORDS = os.getenv("FEATURE_THOUGHT_RECORDS", "false").lower() == "true"
FEATURE_SHAME_PROTOCOL = os.getenv("FEATURE_SHAME_PROTOCOL", "false").lower() == "true"

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


def compute_arc_position(node: str, sublabel: Optional[str]) -> tuple:
    """
    Map (node, sublabel) to arc position (1-8) on the 8-node Rewire loop.

    Returns: (position: int, label: str)
    """
    ARC_MAPPING = {
        "Stress": (1, "Stress — Physiological Activation"),
        "Procrastination": (3, "Procrastination — Avoidance Pattern"),
        "Anxiety": (2, "Anxiety — Coping Struggle"),  # refined below
        "Overwhelm": (2, "Overwhelm — Coping Struggle"),  # refined below
        "Numbness": (7, "Numbness — Low Self-Esteem"),
        "Shame": (8, "Shame — Loop Restart"),
        "Isolation": (8, "Isolation — Shame Context"),
    }

    base_pos, base_label = ARC_MAPPING.get(node, (1, "Unknown Node"))

    # Refine position based on sublabel for multi-position states
    if node == "Anxiety":
        if sublabel in ["Hypervigilance", "Panic"]:
            return (5, "Node 5 of 8 — Hypervigilance")
        else:  # Worry, Dread
            return (2, "Node 2 of 8 — Coping Struggle (Anxious)")
    elif node == "Overwhelm":
        if sublabel in ["Scattered", "Cognitive Overload"]:
            return (2, "Node 2 of 8 — Coping Struggle (Overwhelmed)")
        else:  # Paralysis
            return (4, "Node 4 of 8 — Neglecting Needs")
    elif node == "Stress":
        if sublabel in ["Burnout", "Burnt-out"]:
            return (4, "Node 4 of 8 — Neglecting Needs (Burnout)")
        else:  # Overload, Tension, Urgency
            return (1, "Node 1 of 8 — Stress")

    return (base_pos, f"Node {base_pos} of 8 — {base_label.split(' — ')[1] if ' — ' in base_label else base_label}")


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
    # Supports both simple interventions and sublabel-variant interventions.
    # Variants have a None key for default; simple interventions are just the dict.
    intervention_options = INTERVENTIONS.get(node)

    if intervention_options and None in intervention_options:
        # State has sublabel variants—try to match sublabel first, then None default
        breaker = intervention_options.get(sublabel) or intervention_options.get(None)
    else:
        # Regular intervention (no variants, or state not found)
        breaker = intervention_options or {
            "title": "General Check-in",
            "task": "Take a moment to breathe and observe your surroundings.",
            "education": "Checking in helps move from reactive patterns to conscious awareness."
        }

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

    # 4. Compute arc position (8-node loop positioning)
    arc_pos, arc_label = compute_arc_position(node, sublabel)

    # 5. Build list of available intervention variants for this state/sublabel
    variants = None
    intervention_options = INTERVENTIONS.get(node)
    if intervention_options and None in intervention_options:
        # This state has sublabel variants
        variant_list = []
        for key, variant in intervention_options.items():
            if key is not None and isinstance(variant, dict) and "title" in variant:
                variant_list.append(variant)
        if len(variant_list) > 1:
            variants = variant_list

    # 6. Populate MSC steps for Shame interventions
    msc_steps = None
    shame_safety_alert = None
    if FEATURE_SHAME_PROTOCOL and node == "Shame":
        raw_steps = INTERVENTIONS.get("Shame", {}).get("msc_steps")
        if raw_steps:
            msc_steps = raw_steps

        # Shame safety alert: check if 3+ times in 24h
        try:
            shame_count = db.get_shame_count_24h()
            shame_safety_alert = shame_count >= 3
        except Exception:
            logger.error("Shame count check failed", exc_info=True, extra={"request_id": request_id})
            shame_safety_alert = False

    # 7. Return the full payload to Flutter
    return {
        "detected_node": node,
        "sublabel": sublabel,
        "emotion_sublabel": sublabel,
        "confidence": prediction["confidence"],
        "reasoning": prediction["reasoning"],
        "risk_level": risk,
        "loop_detected": is_loop,
        "intervention_title": breaker["title"],
        "intervention_task": breaker["task"],
        "education_info": breaker["education"],
        "intervention_type": breaker.get("type"),
        "node_arc_position": arc_pos,
        "node_arc_label": arc_label,
        "intervention_variants": variants,
        "msc_steps": msc_steps,
        "shame_safety_alert": shame_safety_alert,
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


@app.post("/thought-record", status_code=201)
async def create_thought_record(
    body: ThoughtRecordRequest, request: Request, db: BehavioralStateManager = Depends(get_db)
):
    request_id = getattr(request.state, "request_id", "")
    try:
        success = db.create_thought_record(
            situation=body.situation,
            automatic_thought=body.automatic_thought,
            evidence_for=body.evidence_for,
            evidence_against=body.evidence_against,
            balanced_thought=body.balanced_thought,
            linked_node=body.linked_node,
        )
        if success:
            return {"status": "created"}
        raise HTTPException(status_code=503, detail="Thought record creation failed")
    except Exception:
        logger.error("Thought record creation failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Thought record service temporarily unavailable")


@app.get("/thought-records", response_model=List[ThoughtRecordResponse])
async def get_thought_records(
    limit: int = 20, offset: int = 0, request: Request = None, db: BehavioralStateManager = Depends(get_db)
):
    request_id = getattr(request.state, "request_id", "") if request else ""
    try:
        return db.get_thought_records(limit=limit, offset=offset)
    except Exception:
        logger.error("Thought records retrieval failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Thought records service temporarily unavailable")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
