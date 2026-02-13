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
You are a psychiatric clinical encoder for the LoopBreaker app.
TASK: Analyze the user's journal entry. Map it to a Primary Node and a Granular Sub-label.

EMOTION WHEEL SCHEMA:
- Stress: [Overwhelmed, Anxious, Burnt-out]
- Procrastination: [Avoidance, Perfectionism, Fear of Failure]
- Anxiety: [Worry, Panic, Dread]
- Shame: [Guilt, Embarrassment, Self-blame]
- Overwhelm: [Paralysis, Cognitive Overload, Scattered]
- Numbness: [Disconnected, Apathy, Exhaustion]
- Isolation: [Loneliness, Withdrawal, Avoidance of Others]

OUTPUT RULES:
1. Return ONLY valid JSON.
2. If confidence is low, set sublabel to "General".
3. Keep 'reasoning' under 15 words.

EXAMPLES:
Input: "I have so much to do, I can't even start."
Output: {"node": "Procrastination", "sublabel": "Avoidance", "confidence": 0.9, "reasoning": "Task paralysis leading to entry delay."}

Input: "I keep thinking something bad is going to happen."
Output: {"node": "Anxiety", "sublabel": "Dread", "confidence": 0.85, "reasoning": "Persistent anticipatory worry without specific trigger."}
"""


def clean_ai_response(raw_json: str) -> Dict[str, Any]:
    data = json.loads(raw_json)

    node = data.get("node", DEFAULT_NODE)
    sublabel = data.get("sublabel", DEFAULT_SUBLABEL)
    reasoning = data.get("reasoning", "Pattern identified from text.")
    confidence = data.get("confidence", 0.5)

    try:
        confidence_value = float(confidence)
    except (TypeError, ValueError):
        confidence_value = 0.5

    confidence_value = max(0.0, min(1.0, confidence_value))

    if node not in VALID_NODES:
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
        f"{SYSTEM_PROMPT}\n"
        f"Input: {json.dumps(text)}\n"
        "Output:"
    )

    model = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
    ollama_url = os.getenv("OLLAMA_URL", "http://localhost:11434")

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

        return clean_ai_response(raw_data["response"])

    except Exception:
        logger.error("AI client error", exc_info=True)
        return {
            "detected_node": DEFAULT_NODE,
            "emotion_sublabel": DEFAULT_SUBLABEL,
            "confidence": 0.5,
            "reasoning": "AI service unavailable.",
        }
