"""Unit tests for Phase 6 db.py methods.

Exercises the actual Neo4j query paths via mocked sessions to bring
db.py coverage back above the 60% threshold after new code was added.

Covers:
- get_intervention_seen_count(): record found, no record, exception
- increment_intervention_seen_count(): success and exception paths
- get_history(): with/without date params, record parsing, exception
- get_weekly_summary(): data present, total_entries=0, exception
- create_daily_check(): success and exception paths
- get_daily_check_correlation(): various sleep/stress combinations, exception
"""

import pytest
from unittest.mock import MagicMock
from app.db import BehavioralStateManager


# ---------------------------------------------------------------------------
# Shared mock helpers
# ---------------------------------------------------------------------------

class FakeRecord:
    def __init__(self, data):
        self._data = data

    def __getitem__(self, key):
        return self._data[key]

    def get(self, key, default=None):
        return self._data.get(key, default)

    def data(self):
        return self._data


class FakeResult:
    """Iterable result that also supports .single()."""
    def __init__(self, records):
        self._records = records

    def __iter__(self):
        return iter(self._records)

    def single(self):
        return self._records[0] if self._records else None


class FakeSession:
    def __init__(self, result=None):
        self._result = result if result is not None else FakeResult([])
        self.ran = []

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def run(self, query, *args, **kwargs):
        self.ran.append(query)
        return self._result


class FakeDriver:
    def __init__(self, result=None):
        self._result = result
        self._session = FakeSession(result)

    def session(self):
        return self._session

    def close(self):
        pass


def _make_db(result=None) -> BehavioralStateManager:
    """Return an available BehavioralStateManager with a mocked driver."""
    db = BehavioralStateManager.__new__(BehavioralStateManager)
    db.is_available = True
    db.driver = FakeDriver(result)
    return db


# ---------------------------------------------------------------------------
# get_intervention_seen_count
# ---------------------------------------------------------------------------

class TestGetInterventionSeenCount:

    def test_returns_count_when_record_found(self):
        record = FakeRecord({"cnt": 5})
        db = _make_db(FakeResult([record]))
        assert db.get_intervention_seen_count("Physiological Sigh") == 5

    def test_returns_zero_when_no_record(self):
        db = _make_db(FakeResult([]))
        assert db.get_intervention_seen_count("Unknown Intervention") == 0

    def test_returns_zero_on_db_exception(self):
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = True
        db.driver = MagicMock()
        db.driver.session.side_effect = Exception("connection lost")
        assert db.get_intervention_seen_count("Sigh") == 0


# ---------------------------------------------------------------------------
# increment_intervention_seen_count
# ---------------------------------------------------------------------------

class TestIncrementInterventionSeenCount:

    def test_runs_update_query_when_available(self):
        db = _make_db(FakeResult([]))
        db.increment_intervention_seen_count("Physiological Sigh")
        assert len(db.driver._session.ran) == 1

    def test_does_not_raise_on_exception(self):
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = True
        db.driver = MagicMock()
        db.driver.session.side_effect = Exception("network error")
        db.increment_intervention_seen_count("Sigh")  # should not raise


# ---------------------------------------------------------------------------
# get_history (with date range params)
# ---------------------------------------------------------------------------

class TestGetHistoryDateRange:

    def _history_record(self, time="2026-05-01T10:00:00", state="Stress"):
        return FakeRecord({
            "time": time,
            "state": state,
            "intervention": "Physiological Sigh",
            "confidence": 0.9,
            "was_successful": True,
        })

    def test_returns_list_of_records(self):
        records = [self._history_record(), self._history_record("2026-05-02T10:00:00", "Anxiety")]
        db = _make_db(FakeResult(records))
        result = db.get_history()
        assert len(result) == 2

    def test_record_time_is_string(self):
        db = _make_db(FakeResult([self._history_record()]))
        result = db.get_history()
        assert isinstance(result[0]["time"], str)

    def test_was_successful_true_preserved(self):
        db = _make_db(FakeResult([self._history_record()]))
        result = db.get_history()
        assert result[0]["was_successful"] is True

    def test_was_successful_none_becomes_false(self):
        record = FakeRecord({
            "time": "2026-05-01T10:00:00",
            "state": "Stress",
            "intervention": None,
            "confidence": 0.7,
            "was_successful": None,
        })
        db = _make_db(FakeResult([record]))
        result = db.get_history()
        assert result[0]["was_successful"] is False

    def test_empty_time_field_becomes_empty_string(self):
        record = FakeRecord({
            "time": None,
            "state": "Stress",
            "intervention": None,
            "confidence": 0.7,
            "was_successful": None,
        })
        db = _make_db(FakeResult([record]))
        result = db.get_history()
        assert result[0]["time"] == ""

    def test_accepts_start_and_end_date(self):
        db = _make_db(FakeResult([]))
        result = db.get_history(start_date="2026-05-01", end_date="2026-05-07", limit=100)
        assert result == []

    def test_returns_empty_list_on_exception(self):
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = True
        db.driver = MagicMock()
        db.driver.session.side_effect = Exception("db error")
        assert db.get_history() == []


# ---------------------------------------------------------------------------
# get_weekly_summary
# ---------------------------------------------------------------------------

class TestGetWeeklySummary:

    def _summary_record(self, total=5, days=4, avg_conf=0.8, succ=3, total_int=5, states=None):
        return FakeRecord({
            "total_entries": total,
            "days_with_entries": days,
            "avg_confidence": avg_conf,
            "successful_interventions": succ,
            "total_interventions": total_int,
            "states": states or ["Stress", "Stress", "Anxiety"],
        })

    def test_returns_aggregated_stats(self):
        db = _make_db(FakeResult([self._summary_record()]))
        result = db.get_weekly_summary("2026-05-01")
        assert result["week_start"] == "2026-05-01"
        assert result["total_entries"] == 5
        assert result["days_with_entries"] == 4
        assert "top_states" in result

    def test_success_rate_computed_correctly(self):
        db = _make_db(FakeResult([self._summary_record(succ=4, total_int=5)]))
        result = db.get_weekly_summary("2026-05-01")
        assert result["intervention_success_rate"] == 80.0

    def test_top_states_counted(self):
        db = _make_db(FakeResult([self._summary_record(states=["Stress", "Stress", "Anxiety"])]))
        result = db.get_weekly_summary("2026-05-01")
        assert result["top_states"]["Stress"] == 2
        assert result["top_states"]["Anxiety"] == 1

    def test_returns_empty_dict_when_total_entries_zero(self):
        record = FakeRecord({
            "total_entries": 0,
            "days_with_entries": 0,
            "avg_confidence": None,
            "successful_interventions": 0,
            "total_interventions": 0,
            "states": [],
        })
        db = _make_db(FakeResult([record]))
        assert db.get_weekly_summary("2026-05-01") == {}

    def test_returns_empty_dict_when_no_record(self):
        db = _make_db(FakeResult([]))
        assert db.get_weekly_summary("2026-05-01") == {}

    def test_zero_total_interventions_gives_zero_success_rate(self):
        db = _make_db(FakeResult([self._summary_record(succ=0, total_int=0)]))
        result = db.get_weekly_summary("2026-05-01")
        assert result["intervention_success_rate"] == 0.0

    def test_returns_empty_dict_on_exception(self):
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = True
        db.driver = MagicMock()
        db.driver.session.side_effect = Exception("query error")
        assert db.get_weekly_summary("2026-05-01") == {}


# ---------------------------------------------------------------------------
# create_daily_check
# ---------------------------------------------------------------------------

class TestCreateDailyCheck:

    def test_returns_true_on_success(self):
        db = _make_db(FakeResult([]))
        result = db.create_daily_check(
            sleep_hours=7.5,
            hydration_rating=4,
            food_quality=3,
            movement_minutes=45,
            stress_level=3,
        )
        assert result is True

    def test_sets_is_available_true_on_success(self):
        db = _make_db(FakeResult([]))
        db.create_daily_check(7.5, 4, 3, 45, 3)
        assert db.is_available is True

    def test_returns_false_on_exception(self):
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = True
        db.driver = MagicMock()
        db.driver.session.side_effect = Exception("write failed")
        result = db.create_daily_check(7.5, 4, 3, 45, 3)
        assert result is False

    def test_sets_is_available_false_on_exception(self):
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = True
        db.driver = MagicMock()
        db.driver.session.side_effect = Exception("write failed")
        db.create_daily_check(7.5, 4, 3, 45, 3)
        assert db.is_available is False


# ---------------------------------------------------------------------------
# get_daily_check_correlation
# ---------------------------------------------------------------------------

class TestGetDailyCheckCorrelation:

    def _checks(self, rows):
        """rows: list of (sleep_hours, stress_level) tuples."""
        return FakeResult([FakeRecord({"sleep_hours": s, "stress_level": st}) for s, st in rows])

    def test_returns_low_sleep_correlate(self):
        # 2 low-sleep days, 1 normal-sleep day → low_sleep ratio = 2.0
        rows = [(5, 3), (5, 3), (7, 3)]
        db = _make_db(self._checks(rows))
        result = db.get_daily_check_correlation()
        assert "low_sleep" in result["correlates"]
        assert result["correlates"]["low_sleep"] == 2.0

    def test_returns_high_stress_correlate(self):
        # 2 high-stress days, 1 normal-stress day → high_stress ratio = 2.0
        rows = [(7, 5), (7, 4), (7, 3)]
        db = _make_db(self._checks(rows))
        result = db.get_daily_check_correlation()
        assert "high_stress" in result["correlates"]
        assert result["correlates"]["high_stress"] == 2.0

    def test_top_correlate_is_highest_ratio(self):
        # low_sleep ratio=3.0, high_stress ratio=1.0 → top=low_sleep
        rows = [(5, 3), (5, 3), (5, 3), (7, 3)]  # 3 low, 1 normal sleep; 1 high, 0 normal stress (ratio undefined)
        # Let's construct a clearer example:
        rows = [
            (5, 3), (5, 3), (5, 3),  # low sleep, normal stress × 3
            (7, 3),                    # normal sleep, normal stress × 1  → low_sleep = 3.0
            (7, 5), (7, 3),           # normal sleep, high stress + normal × 1 each → high_stress = 1.0
        ]
        db = _make_db(self._checks(rows))
        result = db.get_daily_check_correlation()
        assert result["top_correlate"] == "low_sleep"

    def test_no_normal_sleep_days_excludes_low_sleep_correlate(self):
        # Only low-sleep and high-sleep days, no normal-sleep → no low_sleep ratio
        rows = [(5, 3), (9, 3)]
        db = _make_db(self._checks(rows))
        result = db.get_daily_check_correlation()
        assert "low_sleep" not in result["correlates"]

    def test_high_sleep_categorised_correctly(self):
        rows = [(9.0, 3)]  # high sleep > 8, normal stress
        db = _make_db(self._checks(rows))
        result = db.get_daily_check_correlation()
        # No normal sleep days → no low_sleep ratio computed
        assert "low_sleep" not in result["correlates"]

    def test_empty_records_returns_empty_correlates(self):
        db = _make_db(FakeResult([]))
        result = db.get_daily_check_correlation()
        assert result["correlates"] == {}
        assert result["top_correlate"] is None

    def test_returns_empty_dict_on_exception(self):
        db = BehavioralStateManager.__new__(BehavioralStateManager)
        db.is_available = True
        db.driver = MagicMock()
        db.driver.session.side_effect = Exception("query error")
        assert db.get_daily_check_correlation() == {}
