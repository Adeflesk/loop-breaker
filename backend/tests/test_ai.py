import asyncio
from unittest.mock import patch

import httpx
import pytest

from app.ai import (
    DEFAULT_NODE,
    DEFAULT_SUBLABEL,
    clean_ai_response,
    query_local_ai,
)


def test_clean_ai_response_invalid_json():
    result = clean_ai_response("not json")

    assert result["detected_node"] == DEFAULT_NODE
    assert result["emotion_sublabel"] == DEFAULT_SUBLABEL
    assert result["confidence"] == 0.5
    assert "JSON parse error" in result["reasoning"]


def test_clean_ai_response_invalid_node_falls_back_to_default():
    raw_text = '{"node": "InvalidState", "sublabel": "Scared", "confidence": 0.8, "reasoning": "bad node"}'
    result = clean_ai_response(raw_text)

    assert result["detected_node"] == DEFAULT_NODE
    assert result["emotion_sublabel"] == DEFAULT_SUBLABEL
    assert result["confidence"] == 0.8
    assert result["reasoning"] == "bad node"


def test_clean_ai_response_low_confidence_resets_sublabel():
    raw_text = '{"node": "Stress", "sublabel": "Overwhelmed", "confidence": 0.4, "reasoning": "low confidence"}'
    result = clean_ai_response(raw_text)

    assert result["detected_node"] == "Stress"
    assert result["emotion_sublabel"] == DEFAULT_SUBLABEL
    assert result["confidence"] == 0.4


def test_clean_ai_response_confidence_clamps_and_coerces_string():
    raw_text = '{"node": "Anxiety", "sublabel": "Dread", "confidence": "1.5", "reasoning": "too high"}'
    result = clean_ai_response(raw_text)

    assert result["detected_node"] == "Anxiety"
    assert result["emotion_sublabel"] == "Dread"
    assert result["confidence"] == 1.0


def test_clean_ai_response_invalid_confidence_string_falls_back():
    raw_text = '{"node": "Shame", "sublabel": "Self-blame", "confidence": "oops", "reasoning": "bad confidence"}'
    result = clean_ai_response(raw_text)

    assert result["detected_node"] == "Shame"
    assert result["emotion_sublabel"] == DEFAULT_SUBLABEL
    assert result["confidence"] == 0.5
    assert result["reasoning"] == "bad confidence"


def test_clean_ai_response_confidence_below_zero_clamps_to_zero():
    raw_text = '{"node": "Stress", "sublabel": "Overwhelmed", "confidence": -0.2, "reasoning": "negative confidence"}'
    result = clean_ai_response(raw_text)

    assert result["detected_node"] == "Stress"
    assert result["emotion_sublabel"] == DEFAULT_SUBLABEL
    assert result["confidence"] == 0.0
    assert result["reasoning"] == "negative confidence"


class FakeResponse:
    def __init__(self, payload, status_code=200):
        self._payload = payload
        self.status_code = status_code

    def json(self):
        return self._payload

    def raise_for_status(self):
        if self.status_code >= 400:
            request = httpx.Request("POST", "http://localhost")
            raise httpx.HTTPStatusError("HTTP error", request=request, response=self)


class FakeClient:
    def __init__(self, response):
        self._response = response

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def post(self, *args, **kwargs):
        return self._response


def test_query_local_ai_success_parse():
    fake_response = FakeResponse(
        {
            "response": '{"node": "Anxiety", "sublabel": "Dread", "confidence": 0.9, "reasoning": "sample"}'
        },
        status_code=200,
    )

    with patch("app.ai.httpx.AsyncClient", return_value=FakeClient(fake_response)):
        result = asyncio.run(query_local_ai("Anxious test"))

    assert result["detected_node"] == "Anxiety"
    assert result["emotion_sublabel"] == "Dread"
    assert result["confidence"] == 0.9
    assert result["reasoning"] == "sample"


def test_query_local_ai_missing_response_fallback():
    fake_response = FakeResponse({"status": "ok"}, status_code=200)

    with patch("app.ai.httpx.AsyncClient", return_value=FakeClient(fake_response)):
        result = asyncio.run(query_local_ai("Fallback test"))

    assert result["detected_node"] == DEFAULT_NODE
    assert result["emotion_sublabel"] == DEFAULT_SUBLABEL
    assert result["confidence"] == 0.5
    assert "warming up" in result["reasoning"]


def test_query_local_ai_http_exception_fallback():
    fake_response = FakeResponse({}, status_code=500)

    with patch("app.ai.httpx.AsyncClient", return_value=FakeClient(fake_response)):
        result = asyncio.run(query_local_ai("Error test"))

    assert result["detected_node"] == DEFAULT_NODE
    assert result["emotion_sublabel"] == DEFAULT_SUBLABEL
    assert result["confidence"] == 0.5
    assert "unavailable" in result["reasoning"]


def test_query_local_ai_timeout_fallback():
    class TimeoutClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def post(self, *args, **kwargs):
            request = httpx.Request("POST", "http://localhost")
            raise httpx.ReadTimeout("Request timed out", request=request)

    with patch("app.ai.httpx.AsyncClient", return_value=TimeoutClient()):
        result = asyncio.run(query_local_ai("Timeout test"))

    assert result["detected_node"] == DEFAULT_NODE
    assert result["emotion_sublabel"] == DEFAULT_SUBLABEL
    assert result["confidence"] == 0.5
    assert "unavailable" in result["reasoning"]


def test_query_local_ai_malformed_json_in_response_fallback():
    fake_response = FakeResponse(
        {
            "response": '{"node": "Stress", "sublabel": "Overwhelmed", "confidence": 0.8, "reasoning": "malformed}'
        },
        status_code=200,
    )

    with patch("app.ai.httpx.AsyncClient", return_value=FakeClient(fake_response)):
        result = asyncio.run(query_local_ai("Malformed JSON test"))

    assert result["detected_node"] == DEFAULT_NODE
    assert result["emotion_sublabel"] == DEFAULT_SUBLABEL
    assert result["confidence"] == 0.5
    assert "JSON parse error" in result["reasoning"]
