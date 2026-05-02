import logging
import os
import time
from typing import Tuple, List, Dict, Optional, Any
from neo4j import GraphDatabase
from neo4j.exceptions import ServiceUnavailable

from .interventions import INTERVENTIONS

logger = logging.getLogger(__name__)

class BehavioralStateManager:
    def __init__(self, uri: str, user: str, password: str, max_retries: int = 5) -> None:
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
        self.is_available = True
        
        # Retry logic for Neo4j connection
        for attempt in range(1, max_retries + 1):
            try:
                self._bootstrap_nodes()
                logger.info(f"Neo4j connection established on attempt {attempt}")
                break
            except ServiceUnavailable as e:
                if attempt < max_retries:
                    wait_time = min(2 ** attempt, 30)  # Exponential backoff, max 30s
                    logger.warning(
                        f"Neo4j unavailable (attempt {attempt}/{max_retries}). "
                        f"Retrying in {wait_time}s... Error: {e}"
                    )
                    time.sleep(wait_time)
                else:
                    self.is_available = False
                    logger.error(
                        f"Neo4j connection failed after {max_retries} attempts. "
                        "App will continue with degraded functionality.",
                        exc_info=True
                    )
            except Exception as e:
                self.is_available = False
                logger.error(f"Unexpected error during DB bootstrap: {e}", exc_info=True)
                break

    def close(self) -> None:
        self.driver.close()

    def _bootstrap_nodes(self) -> None:
        """Creates the foundation and warms up the schema."""
        nodes = list(INTERVENTIONS.keys())
        with self.driver.session() as session:
            for name in nodes:
                session.run("MERGE (n:Node {name: $name})", name=name)

            session.run("""
                MERGE (e:Entry {temp: true})
                MERGE (i:Intervention {title: 'Warmup'})
                MERGE (e)-[:HAS_INTERVENTION]->(i)
                WITH e, i DETACH DELETE e, i
            """)

    def log_and_analyze(
        self,
        node_name: str,
        confidence: float,
        title: str = "",
        task: str = "",
        sublabel: Optional[str] = None,
    ) -> Tuple[str, bool]:
        if not self.is_available:
            logger.warning("Neo4j unavailable, returning default risk assessment")
            # Return Low risk, no loop for degraded mode
            return "Low", False
            
        try:
            with self.driver.session() as session:
                # 1. Record Entry
                session.run("""
                    MATCH (n:Node {name: $name})
                    CREATE (e:Entry {timestamp: datetime(), confidence: $conf, emotion_sublabel: $sublabel, loop_broken: false})
                    CREATE (e)-[:RECORDS_STATE]->(n)
                """, name=node_name, conf=confidence, sublabel=sublabel)

                # 2. Check for Loop
                result = session.run("""
                    MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                    WHERE NOT (COALESCE(e.loop_broken, false) = true)
                    RETURN n.name as name
                    ORDER BY e.timestamp DESC LIMIT 3
                """)
                history = [record["name"] for record in result]
                is_loop = len(history) >= 3 and all(h == history[0] for h in history)
                high_risk_sublabels = {"Overwhelmed", "Burnout", "Burnt-out"}
                risk = "High" if (is_loop or (sublabel in high_risk_sublabels)) else "Low"

                # 3. Link Intervention
                if is_loop and title:
                    session.run("""
                        MATCH (e:Entry) 
                        WITH e ORDER BY e.timestamp DESC LIMIT 1
                        CREATE (i:Intervention {title: $title, task: $task, timestamp: datetime()})
                        CREATE (e)-[:HAS_INTERVENTION]->(i)
                    """, title=title, task=task)

                self.is_available = True
                return risk, is_loop
        except Exception:
            self.is_available = False
            logger.error("DB log_and_analyze error", exc_info=True)
            return "Low", False

    def cleanup_stale_interventions(self, hours_old: int = 1) -> None:
        """Marks old, unresolved interventions as skipped."""
        if not self.is_available:
            return

        try:
            with self.driver.session() as session:
                result = session.run("""
                    MATCH (i:Intervention)
                    WHERE NOT (i)-[:HAS_OUTCOME]->()
                    AND i.timestamp < datetime() - duration({hours: $hours})
                    CREATE (o:Outcome {
                        success: false,
                        skipped: true,
                        timestamp: datetime(),
                        notes: "System auto-resolved stale intervention"
                    })
                    CREATE (i)-[:HAS_OUTCOME]->(o)
                    RETURN count(i) as cleaned
                """, hours=hours_old)
                record = result.single()
                count = record["cleaned"] if record else 0
                if count > 0:
                    logger.info(f"Cleaned up {count} stale intervention(s) older than {hours_old}h")
            self.is_available = True
        except Exception as e:
            logger.error(f"Cleanup error: {e}", exc_info=True)

    def resolve_intervention(
        self,
        was_successful: bool,
        needs_check: Optional[Dict[str, bool]] = None,
    ) -> None:
        if not self.is_available:
            logger.warning("Neo4j unavailable, skipping intervention resolution")
            return
        
        # Clean up stale interventions before resolving the current one
        self.cleanup_stale_interventions()
            
        needs = needs_check or {}
        try:
            with self.driver.session() as session:
                session.run("""
                    MATCH (e:Entry)-[:HAS_INTERVENTION]->(i:Intervention)
                    WHERE NOT (i)-[:HAS_OUTCOME]->()
                    WITH i ORDER BY i.timestamp DESC LIMIT 1
                    CREATE (o:Outcome {
                        success: $success,
                        skipped: false,
                        timestamp: datetime(),
                        hydration: $hydration,
                        fuel: $fuel,
                        rest: $rest,
                        movement: $movement
                    })
                    CREATE (i)-[:HAS_OUTCOME]->(o)
                """,
                success=was_successful,
                hydration=needs.get("hydration"),
                fuel=needs.get("fuel"),
                rest=needs.get("rest"),
                movement=needs.get("movement"),
                )
                
                # If intervention was successful, reset the loop history
                # to allow fresh start and prevent overaggressively tagging recurring patterns
                if was_successful:
                    session.run("""
                        MATCH (e:Entry)
                        WHERE NOT (e)-[:HAS_INTERVENTION]->()
                        WITH e ORDER BY e.timestamp DESC LIMIT 10
                        SET e.loop_broken = true
                    """)
                    logger.info("Loop history marked as reset after successful intervention")
            self.is_available = True
        except Exception:
            self.is_available = False
            logger.error("DB resolve_intervention error", exc_info=True)

    def get_history(self) -> List[Dict[str, Any]]:
        """Fetches the last 20 entries for the Dashboard."""
        if not self.is_available:
            logger.warning("Neo4j unavailable, returning empty history")
            return []
            
        try:
            with self.driver.session() as session:
                result = session.run("""
                    MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                    OPTIONAL MATCH (e)-[:HAS_INTERVENTION]->(i:Intervention)
                    OPTIONAL MATCH (i)-[:HAS_OUTCOME]->(o:Outcome)
                    RETURN 
                        e.timestamp as time, 
                        n.name as state, 
                        i.title as intervention,
                        e.confidence as confidence,
                        o.success as was_successful
                    ORDER BY e.timestamp DESC LIMIT 20
                """)
                
                history_data = []
                for record in result:
                    clean = record.data()
                    clean["time"] = str(clean["time"]) if clean.get("time") else ""
                    clean["was_successful"] = True if clean.get("was_successful") is True else False
                    history_data.append(clean)
                return history_data
        except Exception:
            logger.error("DB history error", exc_info=True)
            return []

    def get_ai_insight(self) -> Optional[Dict[str, Any]]:
        """Calculates patterns and resilience scores."""
        if not self.is_available:
            logger.warning("Neo4j unavailable, returning empty insight")
            return None
            
        try:
            with self.driver.session() as session:
                result = session.run("""
                    MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                    OPTIONAL MATCH (e)-[:HAS_INTERVENTION]->(i:Intervention)
                    OPTIONAL MATCH (i)-[:HAS_OUTCOME]->(o:Outcome)
                    WITH n.name AS state,
                         count(i) AS loop_count,
                         sum(CASE WHEN o.success = true THEN 1 ELSE 0 END) AS successes,
                         sum(CASE WHEN COALESCE(o.skipped, false) = true THEN 1 ELSE 0 END) AS skipped
                    RETURN state, loop_count, successes, skipped
                    ORDER BY loop_count DESC LIMIT 1
                """)
                record = result.single()
                self.is_available = True
                if record and record["loop_count"] > 0:
                    total_outcomes = record["successes"] + record.get("skipped", 0)
                    # Calculate success rate only from engaged interventions (exclude skipped)
                    engaged_interventions = record["loop_count"] - record.get("skipped", 0)
                    success_rate = (record["successes"] / engaged_interventions * 100) if engaged_interventions > 0 else 0
                    
                    trigger_result = session.run(
                        """
                        MATCH (prev:Entry)-[:HAS_INTERVENTION]->(pi:Intervention)-[:HAS_OUTCOME]->(o:Outcome)
                        MATCH (curr:Entry)-[:HAS_INTERVENTION]->(:Intervention)
                        WHERE prev.timestamp < curr.timestamp
                          AND (o.hydration = false OR o.rest = false)
                          AND NOT EXISTS {
                            MATCH (mid:Entry)
                            WHERE mid.timestamp > prev.timestamp AND mid.timestamp < curr.timestamp
                          }
                        RETURN
                          sum(CASE WHEN o.hydration = false THEN 1 ELSE 0 END) AS hydration_misses,
                          sum(CASE WHEN o.rest = false THEN 1 ELSE 0 END) AS rest_misses
                        """
                    ).single()

                    hydration_misses = int((trigger_result or {}).get("hydration_misses") or 0)
                    rest_misses = int((trigger_result or {}).get("rest_misses") or 0)
                    trigger_count = hydration_misses + rest_misses

                    missing_need = None
                    coaching_message = (
                        f"You've disrupted {record['loop_count']} patterns in your top loop. Keep going!"
                    )
                    
                    # Adjust message if user is skipping interventions frequently
                    skipped_count = record.get("skipped", 0)
                    if skipped_count > 0 and skipped_count >= engaged_interventions:
                        coaching_message = (
                            f"You've triggered {record['loop_count']} interventions but haven't completed many. "
                            "Try engaging with the next circuit breaker to build disruption momentum."
                        )
                    elif trigger_count > 0:
                        missing_need = "hydration" if hydration_misses >= rest_misses else "rest"
                        coaching_message = (
                            f"Pattern insight: unmet {missing_need} often appears before repeat high-risk stress loops. "
                            "Address this first to shift back into executive control."
                        )

                    return {
                        "top_loop": record["state"],
                        "count": record["loop_count"],
                        "success_rate": success_rate,
                        "trend": "improving" if success_rate >= 70 else "stable",
                        "streak": int(record["successes"]),
                        "missing_need": missing_need,
                        "trigger_count": trigger_count,
                        "coaching_message": coaching_message,
                    }
                return None
        except Exception:
            self.is_available = False
            logger.error("DB insight error", exc_info=True)
            return None

    def get_trend_stats(self) -> Dict[str, int]:
        """Returns count of entries per emotional state."""
        if not self.is_available:
            logger.warning("Neo4j unavailable, returning empty trend stats")
            return {}
            
        try:
            with self.driver.session() as session:
                result = session.run("""
                    MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                    RETURN n.name as state, count(e) as count
                    ORDER BY count DESC
                """)
                return {record["state"]: record["count"] for record in result}
        except Exception:
            logger.error("DB trend stats error", exc_info=True)
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
        """Creates a thought record (cognitive restructuring exercise)."""
        if not self.is_available:
            logger.warning("Neo4j unavailable, cannot create thought record")
            return False

        try:
            with self.driver.session() as session:
                session.run(
                    """
                    CREATE (t:ThoughtRecord {
                        timestamp: datetime(),
                        situation: $situation,
                        automatic_thought: $automatic_thought,
                        evidence_for: $evidence_for,
                        evidence_against: $evidence_against,
                        balanced_thought: $balanced_thought,
                        linked_node: $linked_node
                    })
                    """,
                    situation=situation,
                    automatic_thought=automatic_thought,
                    evidence_for=evidence_for,
                    evidence_against=evidence_against,
                    balanced_thought=balanced_thought,
                    linked_node=linked_node,
                )
            self.is_available = True
            return True
        except Exception:
            self.is_available = False
            logger.error("DB thought record creation error", exc_info=True)
            return False

    def get_thought_records(self, limit: int = 20, offset: int = 0) -> list:
        """Retrieves thought records with optional pagination."""
        if not self.is_available:
            logger.warning("Neo4j unavailable, returning empty thought records")
            return []

        try:
            with self.driver.session() as session:
                result = session.run(
                    """
                    MATCH (t:ThoughtRecord)
                    RETURN
                        t.timestamp as timestamp,
                        t.situation as situation,
                        t.automatic_thought as automatic_thought,
                        t.evidence_for as evidence_for,
                        t.evidence_against as evidence_against,
                        t.balanced_thought as balanced_thought,
                        t.linked_node as linked_node
                    ORDER BY t.timestamp DESC
                    SKIP $offset LIMIT $limit
                    """,
                    offset=offset,
                    limit=limit,
                )

                records = []
                for record in result:
                    clean = record.data()
                    clean["timestamp"] = str(clean.get("timestamp", ""))
                    records.append(clean)
                return records
        except Exception:
            logger.error("DB thought records retrieval error", exc_info=True)
            return []

    def get_shame_count_24h(self) -> int:
        """Returns number of Shame entries in the last 24 hours."""
        if not self.is_available:
            return 0
        try:
            with self.driver.session() as session:
                result = session.run("""
                    MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node {name: 'Shame'})
                    WHERE e.timestamp > datetime() - duration({hours: 24})
                    RETURN count(e) as count
                """)
                record = result.single()
                return int(record["count"]) if record else 0
        except Exception:
            logger.error("DB shame count error", exc_info=True)
            return 0

    def reset_all_data(self) -> bool:
        """Wipes user data while keeping Node labels."""
        if not self.is_available:
            logger.warning("Neo4j unavailable, cannot reset data")
            return False

        try:
            with self.driver.session() as session:
                session.run("MATCH (n) WHERE n:Entry OR n:Intervention OR n:Outcome DETACH DELETE n")
            self.is_available = True
            return True
        except Exception:
            self.is_available = False
            logger.error("DB reset error", exc_info=True)
            return False

def create_db_manager() -> BehavioralStateManager:
    uri = os.getenv("NEO4J_URI", "bolt://localhost:7687")
    user = os.getenv("NEO4J_USER", "neo4j")
    password = os.getenv("NEO4J_PASSWORD")
    if not password:
        raise RuntimeError(
            "NEO4J_PASSWORD env var is required. "
            "Set it before starting the server (e.g. export NEO4J_PASSWORD=yourpassword)"
        )
    return BehavioralStateManager(uri, user, password)