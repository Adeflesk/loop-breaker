import json
import logging
import os
from typing import Any, Dict

import httpx

from .interventions import INTERVENTIONS

logger = logging.getLogger(__name__)

VALID_NODES = list(INTERVENTIONS.keys())
DEFAULT_NODE = "Stress"
DEFAULT_SUBLABEL = "unspecified"
DEFAULT_GEMINI_MODEL = "gemini-3.5-flash-lite"
GEMINI_INTERACTIONS_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"
GEMINI_API_REVISION = "2026-05-20"
GEMINI_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "node": {"type": "string"},
        "sublabel": {"type": "string"},
        "confidence": {"type": "number"},
        "reasoning": {"type": "string"},
    },
    "required": ["node", "sublabel", "confidence", "reasoning"],
}

SYSTEM_PROMPT = """
You are a Behavioral Science Specialist in LoopBreaker.

THE 8-NODE REWIRE FEEDBACK LOOP (context for understanding):
1. STRESS — Physiological spikes and overwhelm
2. COPING STRUGGLE — Decreased executive function, difficulty regulating
3. PROCRASTINATION — Avoidance and task delay behaviors
4. NEGLECT NEEDS — Ignoring sleep, food, movement, social connection
5. HYPERVIGILANCE — Heightened sensitivity, anxiety, defensive scanning
6. NEGATIVE BELIEFS — Distorted self-talk, rumination, catastrophizing
7. LOW SELF-ESTEEM — Degraded self-worth, internalized criticism
8. SHAME — Isolation, worthlessness, loop restart condition

YOUR TASK:
Classify the user's journal entry into ONE of these 7 emotional states:
- Procrastination (avoidance, distraction, fear of failure)
- Anxiety (worry, panic, dread, hypervigilance)
- Stress (overload, tension, urgency, burnout)
- Shame (guilt, embarrassment, self-blame, isolation)
- Overwhelm (paralysis, cognitive overload, scattered)
- Numbness (disconnected, apathy, exhaustion, freeze)
- Isolation (loneliness, withdrawal, avoidance of others)

Also extract a specific emotion sublabel and confidence.

Return ONLY this JSON format:
{"node": "StateName", "sublabel": "SubLabel", "confidence": 0.8, "reasoning": "brief explanation"}

SUBLABELS BY STATE:
- Procrastination: Avoidance, Perfectionism, Fear of Failure
- Anxiety: Worry, Panic, Dread, Hypervigilance
- Stress: Overload, Tension, Urgency, Burnout
- Shame: Guilt, Embarrassment, Self-Blame, Isolation
- Overwhelm: Paralysis, Cognitive Overload, Scattered
- Numbness: Disconnected, Apathy, Exhaustion, Freeze
- Isolation: Loneliness, Withdrawal, Avoidance of Others

EXAMPLES:
"I can't start my work" → {"node": "Procrastination", "sublabel": "Avoidance", "confidence": 0.9, "reasoning": "avoiding task initiation"}
"Everything feels threatening" → {"node": "Anxiety", "sublabel": "Dread", "confidence": 0.85, "reasoning": "pervasive anticipatory fear"}
"I'm behind on deadlines" → {"node": "Stress", "sublabel": "Overload", "confidence": 0.9, "reasoning": "time pressure and workload"}
"I feel terrible about myself" → {"node": "Shame", "sublabel": "Self-Blame", "confidence": 0.85, "reasoning": "self-directed criticism"}
"Too many things at once" → {"node": "Overwhelm", "sublabel": "Cognitive Overload", "confidence": 0.9, "reasoning": "mental capacity exceeded"}
"I don't feel anything" → {"node": "Numbness", "sublabel": "Disconnected", "confidence": 0.85, "reasoning": "emotional blunting present"}
"I don't want to see anyone" → {"node": "Isolation", "sublabel": "Isolation", "confidence": 0.9, "reasoning": "social avoidance pattern"}
"""


def clean_ai_response(raw_json: str) -> Dict[str, Any]:
    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError as e:
        logger.warning(
            "AI returned invalid JSON",
            extra={"event": "ai_json_error", "snippet": raw_json[:200], "error": str(e)},
        )
        return {
            "detected_node": DEFAULT_NODE,
            "emotion_sublabel": DEFAULT_SUBLABEL,
            "confidence": 0.5,
            "reasoning": "JSON parse error",
        }

    node = data.get("node", DEFAULT_NODE)
    sublabel = data.get("sublabel", DEFAULT_SUBLABEL)
    reasoning = data.get("reasoning", "Pattern identified from text.")
    confidence = data.get("confidence", 0.5)

    # Log what AI actually returned before validation
    logger.info(
        "AI raw response",
        extra={"event": "ai_raw_response", "node": node, "sublabel": sublabel, "confidence": confidence},
    )

    try:
        confidence_value = float(confidence)
    except (TypeError, ValueError):
        confidence_value = 0.5

    confidence_value = max(0.0, min(1.0, confidence_value))

    if node not in VALID_NODES:
        logger.warning(
            "AI returned invalid node",
            extra={"event": "ai_invalid_node", "node": node, "valid_nodes": VALID_NODES},
        )
        node = DEFAULT_NODE
        sublabel = DEFAULT_SUBLABEL

    if confidence_value < 0.6:
        sublabel = DEFAULT_SUBLABEL

    return {
        "detected_node": node,
        "emotion_sublabel": sublabel,
        "confidence": confidence_value,
        "reasoning": str(reasoning),
    }

def _extract_gemini_text(raw_data: Dict[str, Any]) -> str:
    """Extracts the text payload from a Gemini Interactions API response."""
    output_text = raw_data.get("output_text")
    if isinstance(output_text, str) and output_text.strip():
        return output_text

    steps = raw_data.get("steps")
    if isinstance(steps, list):
        for step in reversed(steps):
            if isinstance(step, dict):
                content = step.get("content")
                if isinstance(content, list):
                    for part in content:
                        if isinstance(part, dict) and part.get("type") == "text" and part.get("text"):
                            return str(part["text"])

    outputs = raw_data.get("outputs")
    if isinstance(outputs, list) and outputs:
        last_output = outputs[-1]
        if isinstance(last_output, dict) and last_output.get("text"):
            return str(last_output["text"])

    return ""


async def _query_gemini(text: str, api_key: str, request_id: str = "") -> Dict[str, Any]:
    """Queries the Gemini Interactions API with structured JSON output."""
    model = os.getenv("GEMINI_MODEL", DEFAULT_GEMINI_MODEL)
    logger.info(
        "AI request (Gemini)",
        extra={"event": "ai_query", "provider": "gemini", "model": model, "text_length": len(text), "request_id": request_id},
    )

    payload = {
        "model": model,
        "system_instruction": SYSTEM_PROMPT,
        "input": f'Journal entry: "{text}"\n\nJSON response:',
        "store": False,
        "generation_config": {
            "thinking_level": "low",
        },
        "response_format": {
            "type": "text",
            "mime_type": "application/json",
            "schema": GEMINI_RESPONSE_SCHEMA,
        },
    }
    headers = {
        "x-goog-api-key": api_key,
        "Content-Type": "application/json",
        "Api-Revision": GEMINI_API_REVISION,
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                GEMINI_INTERACTIONS_URL,
                headers=headers,
                json=payload,
                timeout=30,
            )

        response.raise_for_status()
        raw_data = response.json()
        ai_response = _extract_gemini_text(raw_data)

        if not ai_response:
            logger.warning(
                "Gemini unexpected format",
                extra={"event": "ai_response_format", "provider": "gemini", "raw_data": raw_data, "request_id": request_id},
            )
            return {
                "detected_node": DEFAULT_NODE,
                "emotion_sublabel": DEFAULT_SUBLABEL,
                "confidence": 0.5,
                "reasoning": "AI is warming up or busy. Please try again.",
            }

        logger.info(
            "Gemini raw response",
            extra={"event": "ai_response", "provider": "gemini", "snippet": ai_response[:300], "request_id": request_id},
        )
        return clean_ai_response(ai_response)

    except httpx.HTTPStatusError as exc:
        logger.error(
            "Gemini service returned non-200 status",
            exc_info=True,
            extra={"event": "ai_http_status_error", "provider": "gemini", "status_code": exc.response.status_code, "request_id": request_id},
        )
    except Exception:
        logger.error("Gemini AI client error", exc_info=True, extra={"event": "ai_generic_error", "provider": "gemini", "request_id": request_id})

    return {
        "detected_node": DEFAULT_NODE,
        "emotion_sublabel": DEFAULT_SUBLABEL,
        "confidence": 0.5,
        "reasoning": "AI service unavailable.",
    }


async def query_local_ai(text: str, request_id: str = "") -> Dict[str, Any]:
    gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if gemini_api_key:
        return await _query_gemini(text, gemini_api_key, request_id=request_id)

    prompt = (
        f"{SYSTEM_PROMPT}\n\n"
        f"Journal entry: \"{text}\"\n\n"
        "JSON response:"
    )

    model = os.getenv("OLLAMA_MODEL", "llama3.2:3b")
    ollama_url = os.getenv("OLLAMA_URL", "http://localhost:11434")

    logger.info(
        "AI request",
        extra={"event": "ai_query", "model": model, "text_length": len(text), "request_id": request_id},
    )

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{ollama_url}/api/generate",
                json={
                    "model": model,
                    "prompt": prompt,
                    "stream": False,
                    "format": "json",
                },
                timeout=30,
            )

        response.raise_for_status()
        raw_data = response.json()

        if "response" not in raw_data:
            logger.warning(
                "Ollama unexpected format",
                extra={"event": "ai_response_format", "raw_data": raw_data, "request_id": request_id},
            )
            return {
                "detected_node": DEFAULT_NODE,
                "emotion_sublabel": DEFAULT_SUBLABEL,
                "confidence": 0.5,
                "reasoning": "AI is warming up or busy. Please try again.",
            }

        ai_response = raw_data["response"]
        logger.info(
            "Ollama raw response",
            extra={"event": "ai_response", "snippet": ai_response[:300], "request_id": request_id},
        )
        
        return clean_ai_response(ai_response)

    except httpx.HTTPStatusError as exc:
        logger.error(
            "Ollama service returned non-200 status",
            exc_info=True,
            extra={"event": "ai_http_status_error", "status_code": exc.response.status_code, "request_id": request_id},
        )
    except Exception:
        logger.error("AI client error", exc_info=True, extra={"event": "ai_generic_error", "request_id": request_id})

    return {
        "detected_node": DEFAULT_NODE,
        "emotion_sublabel": DEFAULT_SUBLABEL,
        "confidence": 0.5,
        "reasoning": "AI service unavailable.",
    }


def generate_weekly_narrative(summary: Dict[str, Any]) -> str:
    """Builds a concise Rewire-grounded weekly coaching narrative from aggregated pattern stats."""
    top_loop = summary.get("top_loop") or "None"
    if top_loop == "None":
        return (
            "Your journey is just beginning. Log a few entries or complete a 3-minute "
            "daily practice to unlock personalized pattern narratives."
        )

    success_rate = round(float(summary.get("success_rate") or 0))
    practice_streak = int(summary.get("practice_streak") or 0)
    peak_window = summary.get("peak_time_window")
    pre_signal = summary.get("pre_loop_signal")

    parts = [
        f"This week, your primary pattern was {top_loop} with a {success_rate}% disruption success rate."
    ]
    if peak_window:
        parts.append(
            f"Your loops cluster most often during the {peak_window.replace('_', ' ')} window."
        )
    if pre_signal:
        parts.append(
            f"Watch for {pre_signal} as an early warning signal before a full loop forms."
        )
    if practice_streak > 0:
        parts.append(
            f"Your {practice_streak}-day proactive practice streak is actively raising your baseline regulation threshold."
        )
    return " ".join(parts)
