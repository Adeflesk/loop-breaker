from typing import Any, Dict, List, Optional, Protocol, Tuple, runtime_checkable


@runtime_checkable
class Repository(Protocol):
    """Structural storage protocol shared by BehavioralStateManager (Neo4j)
    and SQLiteStateManager (SQLite).
    """

    is_available: bool

    def analyze_loop_path(self, days: int = 30) -> Dict[str, Any]: ...

    def cleanup_stale_interventions(self, hours_old: int = 1) -> None: ...

    def close(self) -> None: ...

    def create_daily_check(
        self,
        sleep_hours: float,
        hydration_rating: int,
        food_quality: int,
        movement_minutes: int,
        stress_level: int,
    ) -> bool: ...

    def create_practice_session(
        self,
        intention: str,
        gratitude: str,
        breathing_seconds: int = 60,
    ) -> bool: ...

    def create_thought_record(
        self,
        situation: str,
        automatic_thought: str,
        evidence_for: str,
        evidence_against: str,
        balanced_thought: str,
        linked_node: Optional[str] = None,
    ) -> bool: ...

    def get_advanced_patterns(self, days: int = 30) -> Dict[str, Any]: ...

    def get_ai_insight(self) -> Optional[Dict[str, Any]]: ...

    def get_daily_check_correlation(self, days: int = 30) -> Dict[str, Any]: ...

    def get_environment_audit(self) -> Dict[str, Any]: ...

    def get_history(
        self,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 500,
    ) -> List[Dict[str, Any]]: ...

    def get_intervention_effectiveness(
        self,
        state: str,
        sublabel: Optional[str] = None,
        limit: int = 10,
        min_threshold: int = 3,
    ) -> Dict[str, Dict[str, Any]]: ...

    def get_intervention_seen_count(self, intervention_title: str) -> int: ...

    def get_journal_entries(self, limit: int = 50) -> List[Dict[str, Any]]: ...

    def get_loop_path(self, days: int = 30) -> List[Dict[str, Any]]: ...

    def get_practice_stats(self, limit: int = 10) -> Dict[str, Any]: ...

    def get_shame_count_24h(self) -> int: ...

    def get_thought_records(self, limit: int = 20, offset: int = 0) -> list: ...

    def get_trend_stats(self) -> Dict[str, int]: ...

    def get_user_profile(self) -> Dict[str, Any]: ...

    def get_weekly_activity(self) -> List[bool]: ...

    def get_weekly_summary(self, week_start: str) -> Dict[str, Any]: ...

    def increment_intervention_seen_count(self, intervention_title: str) -> None: ...

    def log_and_analyze(
        self,
        node_name: str,
        confidence: float,
        title: str = "",
        task: str = "",
        sublabel: Optional[str] = None,
        intervention_type: Optional[str] = None,
    ) -> Tuple[str, bool]: ...

    def log_crisis_event(
        self,
        user_id: str,
        keywords: List[str],
        detected_state: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> Optional[str]: ...

    def ping(self) -> bool: ...

    def record_journal_outcome(
        self,
        entry_id: str,
        outcome: str,
        notes: Optional[str] = None,
    ) -> bool: ...

    def reset_all_data(self) -> bool: ...

    def resolve_intervention(
        self,
        was_successful: bool,
        needs_check: Optional[Dict[str, bool]] = None,
        outcome_type: Optional[str] = None,
    ) -> None: ...

    def save_environment_audit(
        self,
        target_loop: str,
        checked_items: List[str],
        custom_friction_step: str = "",
    ) -> bool: ...

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
    ) -> bool: ...

    def save_user_profile(
        self,
        values: List[str],
        identity_statement: str,
    ) -> bool: ...
