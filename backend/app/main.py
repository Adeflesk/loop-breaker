import logging
import os
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import List, Optional

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request

try:
    import sentry_sdk
except ImportError:
    sentry_sdk = None
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .ai import query_local_ai
from .crisis import CrisisSafetyService
from .db import BehavioralStateManager, create_db_manager
from .interventions import INTERVENTIONS
from .models import (
    AnalysisRequest,
    AnalysisResponse,
    CrisisHotline,
    CrisisResourcesResponse,
    FeedbackRequest,
    InsightResponse,
    JournalEntryResponse,
    JournalOutcomeRequest,
    ThoughtRecordRequest,
    ThoughtRecordResponse,
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db = create_db_manager()
    app.state.crisis_service = CrisisSafetyService()

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
FEATURE_MOVEMENT_PROTOCOLS = os.getenv("FEATURE_MOVEMENT_PROTOCOLS", "false").lower() == "true"

# Crisis Safety Feature
FEATURE_CRISIS_SAFETY = os.getenv("FEATURE_CRISIS_SAFETY", "true").lower() == "true"

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


def _build_crisis_response() -> AnalysisResponse:
    """Build crisis response with hotline resources."""
    return AnalysisResponse(
        detected_node="Crisis",
        sublabel=None,
        emotion_sublabel=None,
        confidence=1.0,
        reasoning="Crisis keywords detected",
        risk_level="high",
        loop_detected=False,
        intervention_title="Crisis Resources",
        intervention_task="Reach out to a crisis hotline for immediate support",
        education_info="Crisis support is available 24/7",
        crisis_detected=True,
        detected_keywords=[],  # Will be populated in endpoint
        crisis_resources=CrisisResourcesResponse(
            message="We're concerned about your safety. Please reach out for support:",
            hotlines=[
                CrisisHotline(
                    name="988 Suicide & Crisis Lifeline",
                    phone="988",
                    url="https://988lifeline.org",
                    available="24/7",
                ),
                CrisisHotline(
                    name="Crisis Text Line",
                    text="Text HOME to 741741",
                    url="https://www.crisistextline.org",
                    available="24/7",
                ),
                CrisisHotline(
                    name="International Association for Suicide Prevention",
                    url="https://www.iasp.info/resources/Crisis_Centres/",
                    note="Find resources in your country",
                ),
            ],
            emergency="If you are in immediate danger, call 911 (US) or your local emergency number",
        ),
        journal_entry_id=None,
    )


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
        "Restlessness": (6, "Restlessness — Trapped Activation"),
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

    # ===== NEW: Crisis Detection =====
    if FEATURE_CRISIS_SAFETY:
        is_crisis, keywords = app.state.crisis_service.detect_crisis(body.user_text)

        if is_crisis:
            # Log to audit table
            user_id = None  # TODO: Extract from auth if available
            ip_address = request.client.host if request.client else "unknown"
            crisis_audit_id = db.log_crisis_event(
                user_id=user_id,
                keywords=keywords,
                detected_state=None,  # Not yet classified
                ip_address=ip_address,
            )

            # Save to journal with crisis flag
            entry_id = str(uuid.uuid4())
            db.save_journal_entry(
                entry_id=entry_id,
                raw_text=body.user_text,
                detected_state="Crisis",
                sublabel="",
                confidence=1.0,
                reasoning="Crisis keywords detected",
                risk_level="high",
                intervention_title="Crisis Resources",
                intervention_type="crisis",
                crisis_audit_id=crisis_audit_id,
            )

            # Log to Sentry
            logger.warning(
                "Crisis detected in journal entry",
                extra={
                    "event": "crisis_detected",
                    "keywords": keywords,
                    "crisis_audit_id": crisis_audit_id,
                    "entry_id": entry_id,
                },
            )

            # Return crisis response
            response = _build_crisis_response()
            response.detected_keywords = keywords
            response.journal_entry_id = entry_id
            return response

    # ===== Continue with normal flow (existing code) =====
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

    # 3b. Fetch personal context (non-blocking)
    personal_loop = None
    intervention_effectiveness = None

    try:
        loop_data = db.analyze_loop_path(days=30)
        if loop_data:
            personal_loop = loop_data
    except Exception as e:
        logger.warning(f"Failed to fetch loop pattern: {e}")

    try:
        effectiveness_data = db.get_intervention_effectiveness(
            state=node,
            sublabel=sublabel
        )
        if effectiveness_data:
            intervention_effectiveness = effectiveness_data
    except Exception as e:
        logger.warning(f"Failed to fetch intervention effectiveness: {e}")

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
                # Convert education dict to string (use "introduce" depth as default for variants display)
                variant_copy = dict(variant)
                if isinstance(variant_copy.get("education"), dict):
                    variant_copy["education"] = variant_copy["education"].get("introduce", "")
                variant_list.append(variant_copy)
        if len(variant_list) > 1:
            variants = variant_list

    # 6. Populate MSC steps for Shame interventions
    msc_steps = None
    shame_safety_alert = None
    if FEATURE_SHAME_PROTOCOL and node == "Shame":
        raw_steps = INTERVENTIONS.get("Shame", {}).get("msc_steps")
        if raw_steps:
            # Convert education dicts to strings (use "introduce" depth for MSC display)
            msc_steps = []
            for step in raw_steps:
                step_copy = dict(step)
                if isinstance(step_copy.get("education"), dict):
                    step_copy["education"] = step_copy["education"].get("introduce", "")
                msc_steps.append(step_copy)

        # Shame safety alert: check if 3+ times in 24h
        try:
            shame_count = db.get_shame_count_24h()
            shame_safety_alert = shame_count >= 3
        except Exception:
            logger.error("Shame count check failed", exc_info=True, extra={"request_id": request_id})
            shame_safety_alert = False

    # 6b. Determine education depth based on heuristic
    # Heuristic: first exposure = introduce, 2-4 = reinforce, 5+ = deepen
    # (For MVP, we use a simple heuristic; later phases can fetch seen_count from DB)
    education_depth = "introduce"

    # Select education text from depth-based dict
    if isinstance(breaker.get("education"), dict):
        education_text = breaker["education"].get(
            education_depth,
            breaker["education"].get("introduce", "")
        )
    else:
        # Fallback for old-style single-string education
        education_text = breaker.get("education", "")

    # 6c. Personalize education_info with user loop and effectiveness data
    if education_text:
        if education_depth == "introduce" and personal_loop and personal_loop.get("most_common_entry"):
            most_common = personal_loop["most_common_entry"]
            # Add context about their specific loop pattern
            if education_text:
                education_text = f"For YOUR {most_common} pattern, {education_text[0].lower()}{education_text[1:]}"

        elif education_depth == "reinforce" and personal_loop and personal_loop.get("most_common_entry"):
            most_common = personal_loop["most_common_entry"]
            # Add effectiveness reference if available
            if intervention_effectiveness and breaker.get("title") in intervention_effectiveness:
                stats = intervention_effectiveness[breaker["title"]]
                percentage = stats.get("percentage", 0)
                education_text = f"{education_text}\n\nFor you, {breaker['title']} works {percentage}% of the time based on your history."
            else:
                education_text = f"{education_text}\n\nThis is particularly important for your {most_common} pattern."

        elif education_depth == "deepen" and personal_loop and personal_loop.get("most_common_entry"):
            most_common = personal_loop["most_common_entry"]
            # Add both context and effectiveness for deeper dives
            context_text = f"In your {most_common} cycle, {education_text[0].lower()}{education_text[1:]}" if education_text else ""
            if intervention_effectiveness and breaker.get("title") in intervention_effectiveness:
                stats = intervention_effectiveness[breaker["title"]]
                percentage = stats.get("percentage", 0)
                context_text += f"\n\nYour track record shows this works {percentage}% of the time, making it a proven strategy for your pattern."
            education_text = context_text

    # 6d. Extract movement protocol if feature flag enabled
    movement_protocol = None
    if FEATURE_MOVEMENT_PROTOCOLS:
        state_catalog = INTERVENTIONS.get(node, {})
        # Sublabel-variant states store interventions under sublabel keys
        if isinstance(state_catalog.get(sublabel), dict) and "movement" in state_catalog.get(sublabel, {}):
            movement_protocol = state_catalog[sublabel]["movement"]
        elif "movement" in state_catalog:
            movement_protocol = state_catalog["movement"]

    # 7. Save journal entry for persistence and outcome tracking
    entry_id = str(uuid.uuid4())
    try:
        db.save_journal_entry(
            entry_id=entry_id,
            raw_text=body.user_text,
            detected_state=node,
            sublabel=sublabel or "",
            confidence=prediction["confidence"],
            reasoning=prediction["reasoning"],
            risk_level=risk,
            intervention_title=breaker["title"],
            intervention_type=breaker.get("type", ""),
        )
    except Exception:
        logger.error("Journal entry save failed", exc_info=True, extra={"request_id": request_id})
        # Non-critical; do not propagate

    # 8. Return the full payload to Flutter
    response_data = {
        "detected_node": node,
        "sublabel": sublabel,
        "emotion_sublabel": sublabel,
        "confidence": prediction["confidence"],
        "reasoning": prediction["reasoning"],
        "risk_level": risk,
        "loop_detected": is_loop,
        "intervention_title": breaker["title"],
        "intervention_task": breaker["task"],
        "education_info": education_text,
        "education_depth": education_depth,
        "intervention_type": breaker.get("type"),
        "node_arc_position": arc_pos,
        "node_arc_label": arc_label,
        "intervention_variants": variants,
        "msc_steps": msc_steps,
        "shame_safety_alert": shame_safety_alert,
        "movement_protocol": movement_protocol,
        "journal_entry_id": entry_id,
        "personal_loop": personal_loop,
        "intervention_effectiveness": intervention_effectiveness,
    }

    # After return, increment seen_count (non-blocking)
    try:
        db.increment_intervention_seen_count(breaker["title"])
    except Exception:
        pass  # Non-critical

    return response_data


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


@app.get("/journal-entries", response_model=List[JournalEntryResponse])
async def get_journal_entries(
    limit: int = Query(50, ge=1, le=500),
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db),
):
    """
    Returns saved journal entries in reverse chronological order.

    Query params:
    - limit: Max entries to return (1-500, default 50)

    Response: List of JournalEntry objects with raw text, analysis, and outcomes
    """
    request_id = getattr(request.state, "request_id", "") if request else ""
    try:
        return db.get_journal_entries(limit=limit)
    except Exception:
        logger.error("Journal entries fetch failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Journal unavailable")


@app.patch("/journal-entries/{entry_id}/outcome", status_code=200)
async def record_journal_outcome(
    entry_id: str,
    body: JournalOutcomeRequest,
    request: Request = None,
    db: BehavioralStateManager = Depends(get_db),
):
    """
    Records the user's self-reported outcome on a journal entry.

    Path params:
    - entry_id: UUID of the journal entry

    Request body:
    {
      "outcome": "helped" | "didn't help" | "neutral",
      "notes": "optional user notes"
    }

    Response: {"status": "recorded"}
    """
    request_id = getattr(request.state, "request_id", "") if request else ""
    if body.outcome not in ("helped", "didn't help", "neutral"):
        raise HTTPException(
            status_code=422,
            detail="outcome must be 'helped', 'didn't help', or 'neutral'"
        )
    try:
        success = db.record_journal_outcome(entry_id=entry_id, outcome=body.outcome, notes=body.notes)
        if not success:
            raise HTTPException(status_code=503, detail="Journal outcome service unavailable")
        return {"status": "recorded"}
    except HTTPException:
        raise
    except Exception:
        logger.error("Journal outcome failed", exc_info=True, extra={"request_id": request_id})
        raise HTTPException(status_code=503, detail="Journal outcome service unavailable")


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
