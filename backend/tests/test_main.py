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


def test_health_and_passcode_auth(monkeypatch):
    class FakeDB:
        is_available = True

        def ping(self):
            return True

        def get_history(self, start_date=None, end_date=None, limit=500):
            return []

        def close(self):
            pass

    monkeypatch.setenv("GEMINI_API_KEY", "test-key")
    monkeypatch.setenv("APP_PASSCODE", "secret-1234")

    with patch("app.main.create_db_manager", return_value=FakeDB()):
        with TestClient(app_main.app) as client:
            assert client.get("/health").status_code == 200
            assert client.get("/health?db=true").json() == {"status": "ok", "db_available": True}
            assert client.get("/auth/status").json() == {"auth_required": True}

            # Missing or wrong passcode rejected on protected API routes
            assert client.get("/history").status_code == 401
            assert client.get("/history", headers={"X-App-Passcode": "wrong"}).status_code == 401

            # Verify endpoint works
            assert client.post("/auth/verify", json={"passcode": "wrong"}).status_code == 401
            assert client.post("/auth/verify", json={"passcode": "secret-1234"}).status_code == 200

            # Correct passcode grants access
            assert client.get("/history", headers={"X-App-Passcode": "secret-1234"}).status_code == 200


def test_auth_verify_rate_limiting(monkeypatch):
    class FakeDB:
        is_available = True

        def close(self):
            pass

    monkeypatch.setenv("GEMINI_API_KEY", "test-key")
    monkeypatch.setenv("APP_PASSCODE", "secret-1234")
    app_main._auth_failures.clear()

    with patch("app.main.create_db_manager", return_value=FakeDB()):
        with TestClient(app_main.app) as client:
            headers = {"X-Forwarded-For": "203.0.113.42"}
            for _ in range(app_main._AUTH_MAX_ATTEMPTS):
                resp = client.post("/auth/verify", json={"passcode": "wrong"}, headers=headers)
                assert resp.status_code == 401

            blocked = client.post("/auth/verify", json={"passcode": "secret-1234"}, headers=headers)
            assert blocked.status_code == 429
            assert "Retry-After" in blocked.headers
