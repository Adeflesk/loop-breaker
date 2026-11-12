import logging
from unittest.mock import patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app import main as app_main


def test_lifespan_warns_when_ollama_unavailable(
    caplog: pytest.LogCaptureFixture, monkeypatch: pytest.MonkeyPatch
):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    class OfflineClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, *args, **kwargs):
            request = httpx.Request("GET", "http://localhost")
            raise httpx.ConnectError("Connection failed", request=request)

    class FakeDB:
        def get_history(self, start_date=None, end_date=None, limit=500):
            return []

        def close(self):
            pass

    with (
        patch("app.main.httpx.AsyncClient", return_value=OfflineClient()),
        patch("app.main.create_db_manager", return_value=FakeDB()),
    ):
        caplog.set_level(logging.WARNING)
        with TestClient(app_main.app) as client:
            response = client.get("/history")
            assert response.status_code == 200

    assert "AI: Ollama service not detected" in caplog.text


def test_lifespan_logs_ready_when_gemini_api_key_set(
    caplog: pytest.LogCaptureFixture, monkeypatch: pytest.MonkeyPatch
):
    monkeypatch.setenv("GEMINI_API_KEY", "test-key")

    class FakeDB:
        def get_history(self, start_date=None, end_date=None, limit=500):
            return []

        def close(self):
            pass

    with patch("app.main.create_db_manager", return_value=FakeDB()):
        caplog.set_level(logging.INFO)
        with TestClient(app_main.app) as client:
            response = client.get("/history")
            assert response.status_code == 200

    assert "AI Ready: Gemini API configured" in caplog.text
