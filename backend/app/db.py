import logging
import os
from typing import Tuple, List, Dict, Optional, Any
from neo4j import GraphDatabase

from .interventions import INTERVENTIONS

logger = logging.getLogger(__name__)

class BehavioralStateManager:
    def __init__(self, uri: str, user: str, password: str) -> None:
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
        self.is_available = True
        try:
            self._bootstrap_nodes()
        except Exception:
            self.is_available = False
            logger.error("DB bootstrap unavailable", exc_info=True)

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
        try:
            with self.driver.session() as session:
                # 1. Record Entry
                session.run("""
                    MATCH (n:Node {name: $name})
                    CREATE (e:Entry {timestamp: datetime(), confidence: $conf})
                    CREATE (e)-[:RECORDS_STATE]->(n)
                """, name=node_name, conf=confidence)

                # 2. Check for Loop
                result = session.run("""
                    MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
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

    def resolve_intervention(
        self,
        was_successful: bool,
        needs_check: Optional[Dict[str, bool]] = None,
    ) -> None:
        needs = needs_check or {}
        try:
            with self.driver.session() as session:
                session.run("""
                    MATCH (e:Entry)-[:HAS_INTERVENTION]->(i:Intervention)
                    WHERE NOT (i)-[:HAS_OUTCOME]->()
                    WITH i ORDER BY i.timestamp DESC LIMIT 1
                    CREATE (o:Outcome {
                        success: $success,
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
            self.is_available = True
        except Exception:
            self.is_available = False
            logger.error("DB resolve_intervention error", exc_info=True)

    def get_history(self) -> List[Dict[str, Any]]:
        """Fetches the last 20 entries for the Dashboard."""
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
        try:
            with self.driver.session() as session:
                result = session.run("""
                    MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                    OPTIONAL MATCH (e)-[:HAS_INTERVENTION]->(i:Intervention)
                    OPTIONAL MATCH (i)-[:HAS_OUTCOME]->(o:Outcome)
                    WITH n.name AS state, 
                         count(i) AS loop_count, 
                         sum(CASE WHEN o.success = true THEN 1 ELSE 0 END) AS successes
                    RETURN state, loop_count, successes
                    ORDER BY loop_count DESC LIMIT 1
                """)
                record = result.single()
                self.is_available = True
                if record and record["loop_count"] > 0:
                    success_rate = (record["successes"] / record["loop_count"]) * 100
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
                    if trigger_count > 0:
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

    def reset_all_data(self) -> bool:
        """Wipes user data while keeping Node labels."""
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