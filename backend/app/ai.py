import json
import logging
import os
from typing import Any, Dict

import httpx

from .interventions import INTERVENTIONS

logger = logging.getLogger(__name__)

VALID_NODES = list(INTERVENTIONS.keys())
DEFAULT_NODE = "Stress"
DEFAULT_SUBLABEL = "General"

SYSTEM_PROMPT = """
Classify this journal entry into ONE emotional state.

VALID STATES (choose exactly one):
Procrastination, Anxiety, Stress, Shame, Overwhelm, Numbness, Isolation

SUBLABELS BY STATE:
- Procrastination: Avoidance, Perfectionism, Fear of Failure
- Anxiety: Worry, Panic, Dread
- Stress: Overwhelmed, Anxious, Burnt-out
- Shame: Guilt, Embarrassment, Self-blame
- Overwhelm: Paralysis, Cognitive Overload, Scattered
- Numbness: Disconnected, Apathy, Exhaustion
- Isolation: Loneliness, Withdrawal, Avoidance of Others

Return ONLY this JSON format:
{"node": "StateName", "sublabel": "SubLabel", "confidence": 0.8, "reasoning": "brief explanation"}

EXAMPLES:
"I can't start my work" → {"node": "Procrastination", "sublabel": "Avoidance", "confidence": 0.9, "reasoning": "avoiding task initiation"}
"Everything feels threatening" → {"node": "Anxiety", "sublabel": "Dread", "confidence": 0.85, "reasoning": "pervasive anticipatory fear"}
"I'm behind on deadlines" → {"node": "Stress", "sublabel": "Overwhelmed", "confidence": 0.9, "reasoning": "time pressure and workload"}
"I feel terrible about myself" → {"node": "Shame", "sublabel": "Self-blame", "confidence": 0.85, "reasoning": "self-directed criticism"}
"Too many things at once" → {"node": "Overwhelm", "sublabel": "Cognitive Overload", "confidence": 0.9, "reasoning": "mental capacity exceeded"}
"I don't feel anything" → {"node": "Numbness", "sublabel": "Disconnected", "confidence": 0.85, "reasoning": "emotional blunting present"}
"I don't want to see anyone" → {"node": "Isolation", "sublabel": "Withdrawal", "confidence": 0.9, "reasoning": "social avoidance pattern"}
"""


def clean_ai_response(raw_json: str) -> Dict[str, Any]:
    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError as e:
        logger.warning(f"AI returned invalid JSON: {raw_json[:200]} | Error: {e}")
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
    logger.info(f"AI raw response: node={node}, sublabel={sublabel}, confidence={confidence}")

    try:
        confidence_value = float(confidence)
    except (TypeError, ValueError):
        confidence_value = 0.5

    confidence_value = max(0.0, min(1.0, confidence_value))

    if node not in VALID_NODES:
        logger.warning(f"AI returned invalid node '{node}'. Valid nodes: {VALID_NODES}. Defaulting to {DEFAULT_NODE}")
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

async def query_local_ai(text: str) -> Dict[str, Any]:
    prompt = (
        f"{SYSTEM_PROMPT}\n\n"
        f"Journal entry: \"{text}\"\n\n"
        "JSON response:"
    )

    model = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
    ollama_url = os.getenv("OLLAMA_URL", "http://localhost:11434")

    logger.info(f"Querying Ollama with model={model}, text_length={len(text)}")

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

        raw_data = response.json()

        if "response" not in raw_data:
            logger.warning("Ollama unexpected format: %s", raw_data)
            return {
                "detected_node": DEFAULT_NODE,
                "emotion_sublabel": DEFAULT_SUBLABEL,
                "confidence": 0.5,
                "reasoning": "AI is warming up or busy. Please try again.",
            }

        ai_response = raw_data["response"]
        logger.info(f"Ollama raw response: {ai_response[:300]}")  # Log first 300 chars
        
        return clean_ai_response(ai_response)

    except Exception:
        logger.error("AI client error", exc_info=True)
        return {
            "detected_node": DEFAULT_NODE,
            "emotion_sublabel": DEFAULT_SUBLABEL,
            "confidence": 0.5,
            "reasoning": "AI service unavailable.",
        }
