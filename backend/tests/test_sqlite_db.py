from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app import main as app_main
from app.db import create_db_manager
from app.sqlite_db import SQLiteStateManager


@pytest.fixture
def sqlite_db(tmp_path):
    db_file = tmp_path / "test_loopbreaker.db"
    db = SQLiteStateManager(str(db_file))
    yield db
    db.close()


def test_create_db_manager_sqlite(tmp_path, monkeypatch):
    db_file = tmp_path / "factory.db"
    monkeypatch.setenv("DB_BACKEND", "sqlite")
    monkeypatch.setenv("SQLITE_PATH", str(db_file))
    monkeypatch.delenv("NEO4J_PASSWORD", raising=False)

    manager = create_db_manager()
    try:
        assert isinstance(manager, SQLiteStateManager)
        assert manager.is_available is True
        assert db_file.exists()
    finally:
        manager.close()


def test_sqlite_log_and_analyze_loop_and_resolve(sqlite_db):
    risk1, loop1 = sqlite_db.log_and_analyze("Stress", 0.85, sublabel="Overload")
    assert (risk1, loop1) == ("Low", False)

    risk2, loop2 = sqlite_db.log_and_analyze("Stress", 0.90, sublabel="Overload")
    assert (risk2, loop2) == ("Low", False)

    risk3, loop3 = sqlite_db.log_and_analyze(
        "Stress",
        0.92,
        title="Box Breathing",
        task="Inhale 4s, hold 4s, exhale 4s",
        sublabel="Overload",
        intervention_type="breathing",
    )
    assert (risk3, loop3) == ("High", True)

    sqlite_db.resolve_intervention(True, {"hydration": False, "rest": True})

    insight = sqlite_db.get_ai_insight()
    assert insight is not None
    assert insight["top_loop"] == "Stress"
    assert insight["count"] == 1
    assert insight["success_rate"] == 100.0
    assert insight["missing_need"] == "hydration"

    # Loop should be broken now for subsequent entries
    _, loop4 = sqlite_db.log_and_analyze("Stress", 0.8)
    assert loop4 is False


def test_sqlite_stale_intervention_cleanup(sqlite_db):
    old_ts = (datetime.now(timezone.utc) - timedelta(hours=2)).isoformat()
    with sqlite_db._lock:
        sqlite_db._conn.execute(
            """
            INSERT INTO entries (timestamp, state, confidence, intervention_title)
            VALUES (?, 'Anxiety', 0.85, 'Grounding')
            """,
            (old_ts,),
        )
        sqlite_db._conn.commit()

    sqlite_db.cleanup_stale_interventions(hours_old=1)
    insight = sqlite_db.get_ai_insight()
    assert insight is not None
    assert insight["top_loop"] == "Anxiety"
    assert "haven't completed many" in insight["coaching_message"]


def test_sqlite_seen_counts_history_summary_and_trends(sqlite_db):
    assert sqlite_db.get_intervention_seen_count("Box Breathing") == 0
    sqlite_db.increment_intervention_seen_count("Box Breathing")
    sqlite_db.increment_intervention_seen_count("Box Breathing")
    assert sqlite_db.get_intervention_seen_count("Box Breathing") == 2

    sqlite_db.log_and_analyze("Procrastination", 0.88)
    sqlite_db.log_and_analyze("Procrastination", 0.82)

    history = sqlite_db.get_history()
    assert len(history) == 2
    assert history[0]["state"] == "Procrastination"

    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    filtered = sqlite_db.get_history(start_date=today_str, end_date=today_str)
    assert len(filtered) == 2

    summary = sqlite_db.get_weekly_summary(today_str)
    assert summary["total_entries"] == 2
    assert summary["top_states"]["Procrastination"] == 2

    trends = sqlite_db.get_trend_stats()
    assert trends == {"Procrastination": 2}


def test_sqlite_daily_checks_and_correlations(sqlite_db):
    assert sqlite_db.create_daily_check(5.0, 3, 3, 20, 5) is True
    assert sqlite_db.create_daily_check(7.5, 4, 4, 30, 2) is True

    corr = sqlite_db.get_daily_check_correlation(days=30)
    assert corr["top_correlate"] in ("low_sleep", "high_stress")
    assert corr["correlates"]["low_sleep"] == 1.0


def test_sqlite_thought_records_and_shame_count(sqlite_db):
    assert sqlite_db.create_thought_record(
        "Missed deadline",
        "I always fail",
        "I missed one task",
        "I delivered 5 projects on time",
        "One delay does not define my work",
        linked_node="Shame",
    )
    records = sqlite_db.get_thought_records()
    assert len(records) == 1
    assert records[0]["linked_node"] == "Shame"

    sqlite_db.log_and_analyze("Shame", 0.9)
    sqlite_db.log_and_analyze("Shame", 0.9)
    assert sqlite_db.get_shame_count_24h() == 2


def test_sqlite_journal_entries_outcomes_and_effectiveness(sqlite_db):
    for i in range(3):
        eid = f"entry-{i}"
        assert sqlite_db.save_journal_entry(
            entry_id=eid,
            raw_text=f"Test entry {i}",
            detected_state="Procrastination",
            sublabel="Avoidance",
            confidence=0.9,
            reasoning="Delaying task",
            risk_level="Low",
            intervention_title="5-Minute Sprint",
            intervention_type="action",
        )
        assert sqlite_db.record_journal_outcome(eid, "helped" if i < 2 else "neutral", "notes")

    entries = sqlite_db.get_journal_entries()
    assert len(entries) == 3

    eff = sqlite_db.get_intervention_effectiveness("Procrastination", sublabel="Avoidance")
    assert eff["5-Minute Sprint"]["total"] == 3
    assert eff["5-Minute Sprint"]["percentage"] == 67

    activity = sqlite_db.get_weekly_activity()
    assert len(activity) == 7
    assert any(activity)


def test_sqlite_practice_profile_environment_and_patterns(sqlite_db):
    assert sqlite_db.create_practice_session("Stay focused", "Grateful for tea", 60)
    stats = sqlite_db.get_practice_stats()
    assert stats["total_sessions"] == 1
    assert stats["practice_streak"] >= 1

    assert sqlite_db.save_user_profile(["Clarity", "Health"], "I act with calm focus.")
    profile = sqlite_db.get_user_profile()
    assert profile["values"] == ["Clarity", "Health"]
    assert profile["identity_statement"] == "I act with calm focus."

    assert sqlite_db.save_environment_audit("Procrastination", ["phone_in_other_room"], "Block social apps")
    audit = sqlite_db.get_environment_audit()
    assert audit["target_loop"] == "Procrastination"
    assert audit["checked_items"] == ["phone_in_other_room"]

    sqlite_db.log_and_analyze("Stress", 0.85)
    sqlite_db.log_and_analyze("Stress", 0.85)
    sqlite_db.log_and_analyze("Stress", 0.9, title="Breathing", task="Breathe")

    loop_analysis = sqlite_db.analyze_loop_path()
    assert loop_analysis["most_common_entry"] == "Stress"

    patterns = sqlite_db.get_advanced_patterns()
    assert patterns["peak_time_window"] in ("morning", "afternoon", "evening", "late_night")
    assert patterns["pre_loop_signal"] == "Stress"

    assert sqlite_db.log_crisis_event("u1", ["help"], "Overwhelm", "127.0.0.1") is not None
    assert sqlite_db.reset_all_data() is True
    assert sqlite_db.get_history() == []


def test_sqlite_degraded_when_unavailable(sqlite_db):
    sqlite_db.is_available = False
    assert sqlite_db.log_and_analyze("Stress", 0.8) == ("Low", False)
    assert sqlite_db.get_history() == []
    assert sqlite_db.get_ai_insight() is None
    assert sqlite_db.get_weekly_summary("2026-11-12") == {}
    assert sqlite_db.get_daily_check_correlation() == {}
    assert sqlite_db.get_weekly_activity() == [False] * 7
    assert sqlite_db.get_trend_stats() == {}
    assert sqlite_db.get_thought_records() == []
    assert sqlite_db.get_shame_count_24h() == 0
    assert sqlite_db.reset_all_data() is False
    assert sqlite_db.get_loop_path() == []
    assert sqlite_db.analyze_loop_path() == {}
    assert sqlite_db.get_intervention_effectiveness("Stress") == {}
    assert sqlite_db.log_crisis_event(None, ["x"]) is None
    assert sqlite_db.save_journal_entry("1", "t", "Stress", "", 0.8, "r", "Low", "t", "a") is False
    assert sqlite_db.get_journal_entries() == []
    assert sqlite_db.record_journal_outcome("1", "helped") is False
    assert sqlite_db.create_practice_session("i", "g") is False
    assert sqlite_db.get_practice_stats()["total_sessions"] == 0
    assert sqlite_db.save_user_profile([], "") is False
    assert sqlite_db.get_user_profile() == {"values": [], "identity_statement": ""}
    assert sqlite_db.save_environment_audit("Stress", []) is False
    assert sqlite_db.get_environment_audit()["target_loop"] == ""
    assert sqlite_db.get_advanced_patterns() == {"peak_time_window": None, "pre_loop_signal": None}


def test_fastapi_integration_with_sqlite_backend(tmp_path, monkeypatch):
    db_file = tmp_path / "integration.db"
    monkeypatch.setenv("DB_BACKEND", "sqlite")
    monkeypatch.setenv("SQLITE_PATH", str(db_file))
    monkeypatch.setenv("GEMINI_API_KEY", "test-key")

    async def fake_ai(text: str, request_id: str = ""):
        return {
            "detected_node": "Procrastination",
            "emotion_sublabel": "Avoidance",
            "confidence": 0.92,
            "reasoning": "mocked",
        }

    with patch("app.main.query_local_ai", side_effect=fake_ai):
        with TestClient(app_main.app) as client:
            resp = client.post("/analyze", json={"user_text": "I keep delaying my report"})
            assert resp.status_code == 200
            data = resp.json()
            assert data["detected_node"] == "Procrastination"

            hist = client.get("/history")
            assert hist.status_code == 200
            assert len(hist.json()) == 1
