import json
import logging
import os
import sqlite3
import threading
import uuid
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class SQLiteStateManager:
    """Lightweight SQLite implementation of BehavioralStateManager for low-RAM devices (e.g. Raspberry Pi 3)."""

    def __init__(self, db_path: str = "loopbreaker.db") -> None:
        self.db_path = db_path
        self._lock = threading.Lock()
        self.is_available = True

        if db_path != ":memory:":
            parent = Path(db_path).parent
            if str(parent) and str(parent) != ".":
                parent.mkdir(parents=True, exist_ok=True)

        self._conn = sqlite3.connect(db_path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        with self._lock:
            self._conn.execute("PRAGMA journal_mode=WAL;")
            self._init_schema()
        logger.info("SQLite database initialized at %s", db_path)

    def _init_schema(self) -> None:
        self._conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                state TEXT NOT NULL,
                confidence REAL NOT NULL,
                emotion_sublabel TEXT,
                loop_broken INTEGER NOT NULL DEFAULT 0,
                intervention_title TEXT,
                intervention_task TEXT,
                intervention_type TEXT,
                outcome_success INTEGER,
                outcome_skipped INTEGER DEFAULT 0,
                outcome_timestamp TEXT,
                hydration INTEGER,
                fuel INTEGER,
                rest INTEGER,
                movement INTEGER
            );

            CREATE TABLE IF NOT EXISTS intervention_stats (
                title TEXT PRIMARY KEY,
                seen_count INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS daily_checks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                sleep_hours REAL NOT NULL,
                hydration_rating INTEGER NOT NULL,
                food_quality INTEGER NOT NULL,
                movement_minutes INTEGER NOT NULL,
                stress_level INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS thought_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                situation TEXT NOT NULL,
                automatic_thought TEXT NOT NULL,
                evidence_for TEXT NOT NULL,
                evidence_against TEXT NOT NULL,
                balanced_thought TEXT NOT NULL,
                linked_node TEXT
            );

            CREATE TABLE IF NOT EXISTS crisis_events (
                id TEXT PRIMARY KEY,
                user_id TEXT,
                timestamp TEXT NOT NULL,
                detected_keywords TEXT NOT NULL,
                detected_state TEXT,
                ip_address TEXT
            );

            CREATE TABLE IF NOT EXISTS journal_entries (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                raw_text TEXT NOT NULL,
                detected_state TEXT NOT NULL,
                sublabel TEXT NOT NULL DEFAULT '',
                confidence REAL NOT NULL,
                reasoning TEXT NOT NULL,
                risk_level TEXT NOT NULL,
                intervention_title TEXT NOT NULL,
                intervention_type TEXT NOT NULL DEFAULT '',
                crisis_detected INTEGER NOT NULL DEFAULT 0,
                crisis_audit_id TEXT,
                user_outcome TEXT,
                user_notes TEXT
            );

            CREATE TABLE IF NOT EXISTS practice_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                intention TEXT NOT NULL,
                gratitude TEXT NOT NULL,
                breathing_seconds INTEGER NOT NULL DEFAULT 60
            );

            CREATE TABLE IF NOT EXISTS user_profile (
                id TEXT PRIMARY KEY,
                values_json TEXT NOT NULL,
                identity_statement TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS environment_audit (
                id TEXT PRIMARY KEY,
                target_loop TEXT NOT NULL,
                checked_items_json TEXT NOT NULL,
                custom_friction_step TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        self._conn.commit()

    def close(self) -> None:
        with self._lock:
            self._conn.close()

    def ping(self) -> bool:
        """Runs a lightweight query to verify SQLite connectivity."""
        try:
            with self._lock:
                self._conn.execute("SELECT 1").fetchone()
            self.is_available = True
            return True
        except Exception:
            logger.warning("SQLite ping failed", exc_info=True)
            return False

    def log_and_analyze(
        self,
        node_name: str,
        confidence: float,
        title: str = "",
        task: str = "",
        sublabel: Optional[str] = None,
        intervention_type: Optional[str] = None,
    ) -> Tuple[str, bool]:
        if not self.is_available:
            return "Low", False

        try:
            now_iso = _utc_now_iso()
            with self._lock:
                cur = self._conn.execute(
                    """
                    INSERT INTO entries (timestamp, state, confidence, emotion_sublabel, loop_broken)
                    VALUES (?, ?, ?, ?, 0)
                    """,
                    (now_iso, node_name, confidence, sublabel),
                )
                entry_id = cur.lastrowid

                rows = self._conn.execute(
                    """
                    SELECT state FROM entries
                    WHERE loop_broken = 0
                    ORDER BY timestamp DESC, id DESC
                    LIMIT 3
                    """
                ).fetchall()
                history = [r["state"] for r in rows]
                is_loop = len(history) >= 3 and all(h == history[0] for h in history)
                high_risk_sublabels = {"Overwhelmed", "Burnout", "Burnt-out"}
                risk = "High" if (is_loop or (sublabel in high_risk_sublabels)) else "Low"

                if is_loop and title:
                    self._conn.execute(
                        """
                        UPDATE entries
                        SET intervention_title = ?, intervention_task = ?, intervention_type = ?
                        WHERE id = ?
                        """,
                        (title, task, intervention_type or "other", entry_id),
                    )
                self._conn.commit()
            return risk, is_loop
        except Exception:
            logger.error("SQLite log_and_analyze error", exc_info=True)
            return "Low", False

    def cleanup_stale_interventions(self, hours_old: int = 1) -> None:
        if not self.is_available:
            return
        try:
            cutoff = (datetime.now(timezone.utc) - timedelta(hours=hours_old)).isoformat()
            with self._lock:
                self._conn.execute(
                    """
                    UPDATE entries
                    SET outcome_success = 0, outcome_skipped = 1, outcome_timestamp = ?
                    WHERE intervention_title IS NOT NULL
                      AND outcome_success IS NULL
                      AND timestamp < ?
                    """,
                    (_utc_now_iso(), cutoff),
                )
                self._conn.commit()
        except Exception:
            logger.error("SQLite cleanup_stale_interventions error", exc_info=True)

    def resolve_intervention(
        self,
        was_successful: bool,
        needs_check: Optional[Dict[str, bool]] = None,
    ) -> None:
        if not self.is_available:
            return

        self.cleanup_stale_interventions()
        needs = needs_check or {}

        def _bool_to_int(val: Any) -> Optional[int]:
            if val is None:
                return None
            return 1 if val else 0

        try:
            with self._lock:
                row = self._conn.execute(
                    """
                    SELECT id FROM entries
                    WHERE intervention_title IS NOT NULL AND outcome_success IS NULL
                    ORDER BY timestamp DESC, id DESC
                    LIMIT 1
                    """
                ).fetchone()
                if row:
                    self._conn.execute(
                        """
                        UPDATE entries
                        SET outcome_success = ?,
                            outcome_skipped = 0,
                            outcome_timestamp = ?,
                            hydration = ?,
                            fuel = ?,
                            rest = ?,
                            movement = ?
                        WHERE id = ?
                        """,
                        (
                            1 if was_successful else 0,
                            _utc_now_iso(),
                            _bool_to_int(needs.get("hydration")),
                            _bool_to_int(needs.get("fuel")),
                            _bool_to_int(needs.get("rest")),
                            _bool_to_int(needs.get("movement")),
                            row["id"],
                        ),
                    )

                if was_successful:
                    self._conn.execute(
                        """
                        UPDATE entries
                        SET loop_broken = 1
                        WHERE id IN (
                            SELECT id FROM entries
                            WHERE intervention_title IS NULL
                            ORDER BY timestamp DESC, id DESC
                            LIMIT 10
                        )
                        """
                    )
                self._conn.commit()
        except Exception:
            logger.error("SQLite resolve_intervention error", exc_info=True)

    def get_intervention_seen_count(self, intervention_title: str) -> int:
        if not self.is_available:
            return 0
        try:
            with self._lock:
                row = self._conn.execute(
                    "SELECT seen_count FROM intervention_stats WHERE title = ?",
                    (intervention_title,),
                ).fetchone()
                return int(row["seen_count"]) if row else 0
        except Exception:
            logger.error("SQLite get_intervention_seen_count error", exc_info=True)
            return 0

    def increment_intervention_seen_count(self, intervention_title: str) -> None:
        if not self.is_available:
            return
        try:
            with self._lock:
                self._conn.execute(
                    """
                    INSERT INTO intervention_stats (title, seen_count)
                    VALUES (?, 1)
                    ON CONFLICT(title) DO UPDATE SET seen_count = seen_count + 1
                    """,
                    (intervention_title,),
                )
                self._conn.commit()
        except Exception:
            logger.error("SQLite increment_intervention_seen_count error", exc_info=True)

    def get_history(
        self,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 500,
    ) -> List[Dict[str, Any]]:
        if not self.is_available:
            return []
        try:
            where_parts = []
            params: List[Any] = []
            if start_date:
                where_parts.append("substr(timestamp, 1, 10) >= ?")
                params.append(start_date)
            if end_date:
                where_parts.append("substr(timestamp, 1, 10) <= ?")
                params.append(end_date)

            where_clause = ("WHERE " + " AND ".join(where_parts)) if where_parts else ""
            params.append(limit)

            with self._lock:
                rows = self._conn.execute(
                    f"""
                    SELECT timestamp, state, intervention_title, confidence, outcome_success
                    FROM entries
                    {where_clause}
                    ORDER BY timestamp DESC, id DESC
                    LIMIT ?
                    """,
                    params,
                ).fetchall()

            return [
                {
                    "time": r["timestamp"],
                    "state": r["state"],
                    "intervention": r["intervention_title"],
                    "confidence": r["confidence"],
                    "was_successful": r["outcome_success"] == 1,
                }
                for r in rows
            ]
        except Exception:
            logger.error("SQLite get_history error", exc_info=True)
            return []

    def get_weekly_summary(self, week_start: str) -> Dict[str, Any]:
        if not self.is_available:
            return {}
        try:
            week_end = (datetime.fromisoformat(week_start) + timedelta(days=7)).strftime("%Y-%m-%d")
            with self._lock:
                rows = self._conn.execute(
                    """
                    SELECT timestamp, state, confidence, outcome_success
                    FROM entries
                    WHERE substr(timestamp, 1, 10) >= ? AND substr(timestamp, 1, 10) < ?
                    """,
                    (week_start, week_end),
                ).fetchall()

            if not rows:
                return {}

            days = {r["timestamp"][:10] for r in rows}
            avg_conf = sum(float(r["confidence"]) for r in rows) / len(rows)
            outcomes = [r["outcome_success"] for r in rows if r["outcome_success"] is not None]
            succ_int = sum(1 for o in outcomes if o == 1)
            success_rate = round(succ_int / len(outcomes) * 100, 1) if outcomes else 0.0

            state_counts: Dict[str, int] = {}
            for r in rows:
                s = r["state"]
                state_counts[s] = state_counts.get(s, 0) + 1

            return {
                "week_start": week_start,
                "total_entries": len(rows),
                "days_with_entries": len(days),
                "avg_confidence": round(avg_conf, 2),
                "intervention_success_rate": success_rate,
                "top_states": state_counts,
            }
        except Exception:
            logger.error("SQLite get_weekly_summary error", exc_info=True)
            return {}

    def create_daily_check(
        self,
        sleep_hours: float,
        hydration_rating: int,
        food_quality: int,
        movement_minutes: int,
        stress_level: int,
    ) -> bool:
        if not self.is_available:
            return False
        try:
            with self._lock:
                self._conn.execute(
                    """
                    INSERT INTO daily_checks (
                        timestamp, sleep_hours, hydration_rating,
                        food_quality, movement_minutes, stress_level
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (_utc_now_iso(), sleep_hours, hydration_rating, food_quality, movement_minutes, stress_level),
                )
                self._conn.commit()
            return True
        except Exception:
            logger.error("SQLite create_daily_check error", exc_info=True)
            return False

    def get_daily_check_correlation(self, days: int = 30) -> Dict[str, Any]:
        if not self.is_available:
            return {}
        try:
            cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
            with self._lock:
                rows = self._conn.execute(
                    "SELECT sleep_hours, stress_level FROM daily_checks WHERE timestamp > ?",
                    (cutoff,),
                ).fetchall()

            sleep_counts = {"low": 0, "normal": 0, "high": 0}
            stress_counts = {"low": 0, "normal": 0, "high": 0}

            for r in rows:
                sleep = r["sleep_hours"]
                stress = r["stress_level"]
                if sleep < 6:
                    sleep_counts["low"] += 1
                elif sleep <= 8:
                    sleep_counts["normal"] += 1
                else:
                    sleep_counts["high"] += 1

                if stress <= 2:
                    stress_counts["low"] += 1
                elif stress <= 3:
                    stress_counts["normal"] += 1
                else:
                    stress_counts["high"] += 1

            correlates: Dict[str, float] = {}
            if sleep_counts["normal"] > 0:
                correlates["low_sleep"] = round(sleep_counts["low"] / sleep_counts["normal"], 2)
            if stress_counts["normal"] > 0:
                correlates["high_stress"] = round(stress_counts["high"] / stress_counts["normal"], 2)

            top = max(correlates, key=correlates.get) if correlates else None
            return {"top_correlate": top, "correlates": correlates}
        except Exception:
            logger.error("SQLite get_daily_check_correlation error", exc_info=True)
            return {}

    def get_ai_insight(self) -> Optional[Dict[str, Any]]:
        if not self.is_available:
            return None
        try:
            with self._lock:
                row = self._conn.execute(
                    """
                    SELECT
                        state,
                        COUNT(intervention_title) AS loop_count,
                        SUM(CASE WHEN outcome_success = 1 THEN 1 ELSE 0 END) AS successes,
                        SUM(CASE WHEN outcome_skipped = 1 THEN 1 ELSE 0 END) AS skipped
                    FROM entries
                    WHERE intervention_title IS NOT NULL
                    GROUP BY state
                    ORDER BY loop_count DESC
                    LIMIT 1
                    """
                ).fetchone()

                if not row or row["loop_count"] == 0:
                    return None

                misses = self._conn.execute(
                    """
                    SELECT
                        SUM(CASE WHEN hydration = 0 THEN 1 ELSE 0 END) AS hydration_misses,
                        SUM(CASE WHEN rest = 0 THEN 1 ELSE 0 END) AS rest_misses
                    FROM entries
                    WHERE outcome_success IS NOT NULL
                    """
                ).fetchone()

            loop_count = int(row["loop_count"])
            successes = int(row["successes"] or 0)
            skipped_count = int(row["skipped"] or 0)
            engaged = loop_count - skipped_count
            success_rate = (successes / engaged * 100) if engaged > 0 else 0

            hydration_misses = int((misses["hydration_misses"] if misses else 0) or 0)
            rest_misses = int((misses["rest_misses"] if misses else 0) or 0)
            trigger_count = hydration_misses + rest_misses

            missing_need = None
            coaching_message = f"You've disrupted {loop_count} patterns in your top loop. Keep going!"
            if skipped_count > 0 and skipped_count >= engaged:
                coaching_message = (
                    f"You've triggered {loop_count} interventions but haven't completed many. "
                    "Try engaging with the next circuit breaker to build disruption momentum."
                )
            elif trigger_count > 0:
                missing_need = "hydration" if hydration_misses >= rest_misses else "rest"
                coaching_message = (
                    f"Pattern insight: unmet {missing_need} often appears before repeat high-risk stress loops. "
                    "Address this first to shift back into executive control."
                )

            if missing_need is None:
                correlation = self.get_daily_check_correlation()
                if correlation.get("top_correlate"):
                    missing_need = correlation["top_correlate"]

            return {
                "top_loop": row["state"],
                "count": loop_count,
                "success_rate": success_rate,
                "trend": "improving" if success_rate >= 70 else "stable",
                "streak": successes,
                "missing_need": missing_need,
                "trigger_count": trigger_count,
                "coaching_message": coaching_message,
            }
        except Exception:
            logger.error("SQLite get_ai_insight error", exc_info=True)
            return None

    def get_weekly_activity(self) -> List[bool]:
        if not self.is_available:
            return [False] * 7
        try:
            today = date.today()
            monday = today - timedelta(days=today.weekday())
            with self._lock:
                rows = self._conn.execute(
                    """
                    SELECT DISTINCT substr(timestamp, 1, 10) AS active_date
                    FROM journal_entries
                    WHERE substr(timestamp, 1, 10) >= ? AND user_outcome = 'helped'
                    """,
                    (monday.isoformat(),),
                ).fetchall()
            active_dates = {r["active_date"] for r in rows}
            return [(monday + timedelta(days=i)).isoformat() in active_dates for i in range(7)]
        except Exception:
            logger.error("SQLite get_weekly_activity error", exc_info=True)
            return [False] * 7

    def get_trend_stats(self) -> Dict[str, int]:
        if not self.is_available:
            return {}
        try:
            with self._lock:
                rows = self._conn.execute(
                    "SELECT state, COUNT(*) AS cnt FROM entries GROUP BY state ORDER BY cnt DESC"
                ).fetchall()
            return {r["state"]: int(r["cnt"]) for r in rows}
        except Exception:
            logger.error("SQLite get_trend_stats error", exc_info=True)
            return {}

    def create_thought_record(
        self,
        situation: str,
        automatic_thought: str,
        evidence_for: str,
        evidence_against: str,
        balanced_thought: str,
        linked_node: Optional[str] = None,
    ) -> bool:
        if not self.is_available:
            return False
        try:
            with self._lock:
                self._conn.execute(
                    """
                    INSERT INTO thought_records (
                        timestamp, situation, automatic_thought, evidence_for,
                        evidence_against, balanced_thought, linked_node
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (_utc_now_iso(), situation, automatic_thought, evidence_for, evidence_against, balanced_thought, linked_node),
                )
                self._conn.commit()
            return True
        except Exception:
            logger.error("SQLite create_thought_record error", exc_info=True)
            return False

    def get_thought_records(self, limit: int = 20, offset: int = 0) -> list:
        if not self.is_available:
            return []
        try:
            with self._lock:
                rows = self._conn.execute(
                    """
                    SELECT timestamp, situation, automatic_thought, evidence_for,
                           evidence_against, balanced_thought, linked_node
                    FROM thought_records
                    ORDER BY timestamp DESC, id DESC
                    LIMIT ? OFFSET ?
                    """,
                    (limit, offset),
                ).fetchall()
            return [dict(r) for r in rows]
        except Exception:
            logger.error("SQLite get_thought_records error", exc_info=True)
            return []

    def get_shame_count_24h(self) -> int:
        if not self.is_available:
            return 0
        try:
            cutoff = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
            with self._lock:
                row = self._conn.execute(
                    "SELECT COUNT(*) AS cnt FROM entries WHERE state = 'Shame' AND timestamp > ?",
                    (cutoff,),
                ).fetchone()
            return int(row["cnt"]) if row else 0
        except Exception:
            logger.error("SQLite get_shame_count_24h error", exc_info=True)
            return 0

    def reset_all_data(self) -> bool:
        if not self.is_available:
            return False
        try:
            with self._lock:
                for table in (
                    "entries",
                    "intervention_stats",
                    "daily_checks",
                    "thought_records",
                    "crisis_events",
                    "journal_entries",
                    "practice_sessions",
                    "user_profile",
                    "environment_audit",
                ):
                    self._conn.execute(f"DELETE FROM {table}")
                self._conn.commit()
            return True
        except Exception:
            logger.error("SQLite reset_all_data error", exc_info=True)
            return False

    def get_loop_path(self, days: int = 30) -> List[Dict[str, Any]]:
        if not self.is_available:
            return []
        try:
            cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
            with self._lock:
                rows = self._conn.execute(
                    """
                    SELECT timestamp, state, confidence,
                           CASE WHEN intervention_title IS NOT NULL THEN 1 ELSE 0 END AS has_intervention
                    FROM entries
                    WHERE timestamp > ?
                    ORDER BY timestamp ASC, id ASC
                    """,
                    (cutoff,),
                ).fetchall()
            return [
                {
                    "timestamp": r["timestamp"],
                    "state": r["state"],
                    "confidence": float(r["confidence"] or 0.0),
                    "has_intervention": bool(r["has_intervention"]),
                }
                for r in rows
            ]
        except Exception:
            logger.error("SQLite get_loop_path error", exc_info=True)
            return []

    def analyze_loop_path(self, days: int = 30) -> Dict[str, Any]:
        if not self.is_available:
            return {}
        path = self.get_loop_path(days=days)
        if not path:
            return {}

        entry_counts: Dict[str, int] = {}
        current_cycle_start = None
        last_timestamp = None

        for entry in path:
            ts = entry["timestamp"]
            if last_timestamp:
                time_diff = (datetime.fromisoformat(ts) - datetime.fromisoformat(last_timestamp)).total_seconds() / 3600
                if time_diff > 6:
                    current_cycle_start = entry["state"]
            else:
                current_cycle_start = entry["state"]

            if current_cycle_start:
                entry_counts[current_cycle_start] = entry_counts.get(current_cycle_start, 0) + 1
            last_timestamp = ts

        most_common_entry = max(entry_counts, key=entry_counts.get) if entry_counts else None
        avg_cycle_length = None
        if most_common_entry:
            timestamps_of_state = [e["timestamp"] for e in path if e["state"] == most_common_entry]
            if len(timestamps_of_state) > 1:
                diffs = [
                    (datetime.fromisoformat(timestamps_of_state[i]) - datetime.fromisoformat(timestamps_of_state[i - 1])).total_seconds() / 3600
                    for i in range(1, len(timestamps_of_state))
                ]
                avg_cycle_length = sum(diffs) / len(diffs) if diffs else None

        return {
            "most_common_entry": most_common_entry,
            "cycle_length_hours": round(avg_cycle_length, 2) if avg_cycle_length else None,
            "total_cycles": len(entry_counts),
        }

    def get_intervention_effectiveness(
        self,
        state: str,
        sublabel: Optional[str] = None,
        limit: int = 10,
        min_threshold: int = 3,
    ) -> Dict[str, Dict[str, Any]]:
        if not self.is_available:
            return {}
        try:
            where = "WHERE detected_state = ? AND user_outcome IS NOT NULL"
            params: List[Any] = [state]
            if sublabel:
                where += " AND sublabel = ?"
                params.append(sublabel)
            params.append(limit)

            with self._lock:
                rows = self._conn.execute(
                    f"""
                    SELECT intervention_title, user_outcome
                    FROM journal_entries
                    {where}
                    ORDER BY timestamp DESC
                    LIMIT ?
                    """,
                    params,
                ).fetchall()

            intervention_stats: Dict[str, Dict[str, int]] = {}
            for r in rows:
                title = r["intervention_title"]
                outcome = r["user_outcome"]
                if title not in intervention_stats:
                    intervention_stats[title] = {"helped": 0, "neutral": 0, "didn_help": 0, "total": 0}
                if outcome in ("helped", "didn't help", "neutral"):
                    key = "didn_help" if outcome == "didn't help" else outcome
                    intervention_stats[title][key] += 1
                    intervention_stats[title]["total"] += 1

            return {
                title: {**s, "percentage": round(100 * s["helped"] / s["total"])}
                for title, s in intervention_stats.items()
                if s["total"] >= min_threshold
            }
        except Exception:
            logger.error("SQLite get_intervention_effectiveness error", exc_info=True)
            return {}

    def log_crisis_event(
        self,
        user_id: Optional[str],
        keywords: List[str],
        detected_state: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> Optional[str]:
        if not self.is_available:
            return None
        try:
            event_id = str(uuid.uuid4())
            with self._lock:
                self._conn.execute(
                    """
                    INSERT INTO crisis_events (id, user_id, timestamp, detected_keywords, detected_state, ip_address)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (event_id, user_id, _utc_now_iso(), json.dumps(keywords), detected_state, ip_address),
                )
                self._conn.commit()
            return event_id
        except Exception:
            logger.error("SQLite log_crisis_event error", exc_info=True)
            return None

    def save_journal_entry(
        self,
        entry_id: str,
        raw_text: str,
        detected_state: str,
        sublabel: str,
        confidence: float,
        reasoning: str,
        risk_level: str,
        intervention_title: str,
        intervention_type: str,
        crisis_audit_id: Optional[str] = None,
    ) -> bool:
        if not self.is_available:
            return False
        try:
            with self._lock:
                self._conn.execute(
                    """
                    INSERT INTO journal_entries (
                        id, timestamp, raw_text, detected_state, sublabel, confidence,
                        reasoning, risk_level, intervention_title, intervention_type,
                        crisis_detected, crisis_audit_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        entry_id,
                        _utc_now_iso(),
                        raw_text,
                        detected_state,
                        sublabel or "",
                        confidence,
                        reasoning,
                        risk_level,
                        intervention_title,
                        intervention_type or "",
                        1 if crisis_audit_id is not None else 0,
                        crisis_audit_id,
                    ),
                )
                self._conn.commit()
            return True
        except Exception:
            logger.error("SQLite save_journal_entry error", exc_info=True)
            return False

    def get_journal_entries(self, limit: int = 50) -> List[Dict[str, Any]]:
        if not self.is_available:
            return []
        try:
            with self._lock:
                rows = self._conn.execute(
                    """
                    SELECT id, timestamp, raw_text, detected_state, sublabel, confidence,
                           reasoning, risk_level, intervention_title, intervention_type,
                           user_outcome, user_notes
                    FROM journal_entries
                    ORDER BY timestamp DESC
                    LIMIT ?
                    """,
                    (min(limit, 500),),
                ).fetchall()
            return [dict(r) for r in rows]
        except Exception:
            logger.error("SQLite get_journal_entries error", exc_info=True)
            return []

    def record_journal_outcome(
        self,
        entry_id: str,
        outcome: str,
        notes: Optional[str] = None,
    ) -> bool:
        if not self.is_available:
            return False
        try:
            with self._lock:
                self._conn.execute(
                    "UPDATE journal_entries SET user_outcome = ?, user_notes = ? WHERE id = ?",
                    (outcome, notes or "", entry_id),
                )
                self._conn.commit()
            return True
        except Exception:
            logger.error("SQLite record_journal_outcome error", exc_info=True)
            return False

    def create_practice_session(
        self,
        intention: str,
        gratitude: str,
        breathing_seconds: int = 60,
    ) -> bool:
        if not self.is_available:
            return False
        try:
            with self._lock:
                self._conn.execute(
                    """
                    INSERT INTO practice_sessions (timestamp, intention, gratitude, breathing_seconds)
                    VALUES (?, ?, ?, ?)
                    """,
                    (_utc_now_iso(), intention, gratitude, breathing_seconds),
                )
                self._conn.commit()
            return True
        except Exception:
            logger.error("SQLite create_practice_session error", exc_info=True)
            return False

    def get_practice_stats(self, limit: int = 10) -> Dict[str, Any]:
        default_stats: Dict[str, Any] = {
            "practice_streak": 0,
            "days_practiced_this_week": 0,
            "total_sessions": 0,
            "recent_sessions": [],
        }
        if not self.is_available:
            return default_stats
        try:
            today = date.today()
            monday = today - timedelta(days=today.weekday())
            with self._lock:
                rows = self._conn.execute(
                    """
                    SELECT timestamp, intention, gratitude, breathing_seconds
                    FROM practice_sessions
                    ORDER BY timestamp DESC, id DESC
                    """
                ).fetchall()

            all_dates = {r["timestamp"][:10] for r in rows if r["timestamp"]}
            recent_sessions = [
                {
                    "timestamp": r["timestamp"],
                    "intention": r["intention"] or "",
                    "gratitude": r["gratitude"] or "",
                    "breathing_seconds": int(r["breathing_seconds"] or 60),
                }
                for r in rows[:limit]
            ]
            days_this_week = sum(1 for i in range(7) if (monday + timedelta(days=i)).isoformat() in all_dates)

            streak = 0
            cursor: Optional[date] = today
            if cursor.isoformat() not in all_dates:
                yesterday = today - timedelta(days=1)
                cursor = yesterday if yesterday.isoformat() in all_dates else None

            while cursor is not None and cursor.isoformat() in all_dates:
                streak += 1
                cursor = cursor - timedelta(days=1)

            return {
                "practice_streak": streak,
                "days_practiced_this_week": days_this_week,
                "total_sessions": len(rows),
                "recent_sessions": recent_sessions,
            }
        except Exception:
            logger.error("SQLite get_practice_stats error", exc_info=True)
            return default_stats

    def save_user_profile(self, values: List[str], identity_statement: str) -> bool:
        if not self.is_available:
            return False
        try:
            with self._lock:
                self._conn.execute(
                    """
                    INSERT INTO user_profile (id, values_json, identity_statement, updated_at)
                    VALUES ('default', ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        values_json = excluded.values_json,
                        identity_statement = excluded.identity_statement,
                        updated_at = excluded.updated_at
                    """,
                    (json.dumps(values), identity_statement, _utc_now_iso()),
                )
                self._conn.commit()
            return True
        except Exception:
            logger.error("SQLite save_user_profile error", exc_info=True)
            return False

    def get_user_profile(self) -> Dict[str, Any]:
        default_profile: Dict[str, Any] = {"values": [], "identity_statement": ""}
        if not self.is_available:
            return default_profile
        try:
            with self._lock:
                row = self._conn.execute(
                    "SELECT values_json, identity_statement FROM user_profile WHERE id = 'default'"
                ).fetchone()
            if not row:
                return default_profile
            return {
                "values": json.loads(row["values_json"] or "[]"),
                "identity_statement": str(row["identity_statement"] or ""),
            }
        except Exception:
            logger.error("SQLite get_user_profile error", exc_info=True)
            return default_profile

    def save_environment_audit(
        self,
        target_loop: str,
        checked_items: List[str],
        custom_friction_step: str = "",
    ) -> bool:
        if not self.is_available:
            return False
        try:
            with self._lock:
                self._conn.execute(
                    """
                    INSERT INTO environment_audit (id, target_loop, checked_items_json, custom_friction_step, updated_at)
                    VALUES ('default', ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        target_loop = excluded.target_loop,
                        checked_items_json = excluded.checked_items_json,
                        custom_friction_step = excluded.custom_friction_step,
                        updated_at = excluded.updated_at
                    """,
                    (target_loop, json.dumps(checked_items), custom_friction_step, _utc_now_iso()),
                )
                self._conn.commit()
            return True
        except Exception:
            logger.error("SQLite save_environment_audit error", exc_info=True)
            return False

    def get_environment_audit(self) -> Dict[str, Any]:
        default_audit: Dict[str, Any] = {
            "target_loop": "",
            "checked_items": [],
            "custom_friction_step": "",
            "updated_at": None,
        }
        if not self.is_available:
            return default_audit
        try:
            with self._lock:
                row = self._conn.execute(
                    "SELECT target_loop, checked_items_json, custom_friction_step, updated_at FROM environment_audit WHERE id = 'default'"
                ).fetchone()
            if not row:
                return default_audit
            return {
                "target_loop": str(row["target_loop"] or ""),
                "checked_items": json.loads(row["checked_items_json"] or "[]"),
                "custom_friction_step": str(row["custom_friction_step"] or ""),
                "updated_at": row["updated_at"],
            }
        except Exception:
            logger.error("SQLite get_environment_audit error", exc_info=True)
            return default_audit

    def get_advanced_patterns(self, days: int = 30) -> Dict[str, Any]:
        default_patterns: Dict[str, Any] = {
            "peak_time_window": None,
            "pre_loop_signal": None,
        }
        if not self.is_available:
            return default_patterns

        path = self.get_loop_path(days=days)
        if not path:
            return default_patterns

        buckets = {"morning": 0, "afternoon": 0, "evening": 0, "late_night": 0}
        precursor_counts: Dict[str, int] = {}

        for idx, entry in enumerate(path):
            raw_ts = str(entry.get("timestamp") or "")
            try:
                dt = datetime.fromisoformat(raw_ts.replace("Z", "+00:00"))
                hour = dt.hour
                if 5 <= hour < 12:
                    buckets["morning"] += 1
                elif 12 <= hour < 17:
                    buckets["afternoon"] += 1
                elif 17 <= hour < 22:
                    buckets["evening"] += 1
                else:
                    buckets["late_night"] += 1
            except ValueError:
                pass

            if idx > 0 and entry.get("has_intervention") is True:
                prev_state = path[idx - 1].get("state")
                if prev_state:
                    precursor_counts[prev_state] = precursor_counts.get(prev_state, 0) + 1

        active_buckets = {k: v for k, v in buckets.items() if v > 0}
        return {
            "peak_time_window": max(active_buckets, key=active_buckets.get) if active_buckets else None,
            "pre_loop_signal": max(precursor_counts, key=precursor_counts.get) if precursor_counts else None,
        }
