import logging
from unittest.mock import patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app import main as app_main


def test_lifespan_warns_when_ollama_unavailable(caplog: pytest.LogCaptureFixture):
    class OfflineClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, *args, **kwargs):
            request = httpx.Request("GET", "http://localhost")
            raise httpx.ConnectError("Connection failed", request=request)

    with patch("app.main.httpx.AsyncClient", return_value=OfflineClient()):
        caplog.set_level(logging.WARNING)
        with TestClient(app_main.app) as client:
            response = client.get("/history")
            assert response.status_code == 200

    assert "AI: Ollama service not detected" in caplog.text
