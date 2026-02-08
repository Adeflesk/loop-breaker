import os
import requests
from typing import List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from neo4j import GraphDatabase

# --- 1. CONFIGURATION & DATA MODELS ---
app = FastAPI(title="LoopBreaker AI Analysis Engine")

# CORS allows your Flutter Web app (127.0.0.1:xxxx) to talk to this backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class AnalysisRequest(BaseModel):
    user_text: str

class FeedbackRequest(BaseModel):
    success: bool

class AnalysisResponse(BaseModel):
    detected_node: str
    confidence: float
    reasoning: str
    risk_level: str
    loop_detected: bool
    circuit_breaker_recommended: bool
    intervention_title: str = ""
    intervention_task: str = ""

# Psychological Interventions Library
IINTERVENTIONS = {
    "Procrastination": {
        "title": "The 5-Minute Sprint",
        "task": "The app will now wait. Set a timer for 5 minutes and work on JUST ONE thing. No tab switching allowed.",
        "type": "timer"
    },
    "Stress": {
        "title": "Box Breathing",
        "task": "Inhale for 4, Hold for 4, Exhale for 4, Hold for 4. Repeat 4 times.",
        "type": "biofeedback"
    },
    "Neglecting Needs": {
        "title": "Bio-Sync Check",
        "task": "Stand up, stretch your neck, and drink a full glass of water before typing your next entry.",
        "type": "physical"
    }
}


# --- 2. GRAPH DATABASE MANAGER ---
class BehavioralStateManager:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
        self._bootstrap_nodes()

    def close(self):
        self.driver.close()

    def _bootstrap_nodes(self):
        """Creates the foundation nodes if they don't exist."""
        nodes = ["Stress", "Procrastination", "Anxiety", "Shame", "Overwhelm", "Numbness", "Isolation"]
        with self.driver.session() as session:
            for name in nodes:
                session.run("MERGE (n:Node {name: $name})", name=name)
        print("✅ Database Bootstrapped.")

    def log_and_analyze(self, node_name: str, confidence: float, title: str = "", task: str = ""):
        """Saves entry, calculates risk, and links interventions."""
        with self.driver.session() as session:
            # A. Create Entry and link to Node
            session.run("""
                MATCH (n:Node {name: $name})
                CREATE (e:Entry {timestamp: datetime(), confidence: $conf})
                CREATE (e)-[:RECORDS_STATE]->(n)
            """, name=node_name.title(), conf=confidence)

            # B. Get History to check for Loops
            result = session.run("""
                MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                RETURN n.name as name
                ORDER BY e.timestamp DESC LIMIT 5
            """)
            history = [record["name"] for record in result]
            risk, is_loop = self.calculate_risk(history)

            # C. If a loop is found, record the intervention offered
            if is_loop and title:
                session.run("""
                    MATCH (e:Entry) 
                    WITH e ORDER BY e.timestamp DESC LIMIT 1
                    CREATE (i:Intervention {title: $title, task: $task, timestamp: datetime()})
                    CREATE (e)-[:HAS_INTERVENTION]->(i)
                """, title=title, task=task)
            
            return risk, is_loop

    def calculate_risk(self, history: List[str]):
        if len(history) < 3:
            return "Low", False
        # If the last 3 entries are the same state, it's a loop
        if history[0] == history[1] == history[2]:
            return "High", True
        return "Low", False

    def resolve_intervention(self, was_successful: bool):
        """Updates the graph with the user's feedback."""
        with self.driver.session() as session:
            session.run("""
                MATCH (e:Entry)-[:HAS_INTERVENTION]->(i:Intervention)
                WHERE NOT (i)-[:HAS_OUTCOME]->()
                WITH i ORDER BY i.timestamp DESC LIMIT 1
                CREATE (o:Outcome {success: $success, timestamp: datetime()})
                CREATE (i)-[:HAS_OUTCOME]->(o)
            """, success=was_successful)

# --- 3. HELPER: OLLAMA AI QUERY ---
def query_local_ai(text: str):
    # This assumes Ollama is running on your M3 (localhost:11434)
    prompt = f"""
    Analyze this journal entry: "{text}"
    Classify it into ONE of these: Stress, Procrastination, Anxiety, Shame.
    Return ONLY valid JSON like this:
    {{"detected_node": "Anxiety", "confidence": 0.9, "reasoning": "User mentions racing heart."}}
    """
    try:
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={"model": "llama3", "prompt": prompt, "stream": False, "format": "json"}
        )
        return response.json()["response"] # You might need json.loads() here depending on Ollama version
    except:
        return {"detected_node": "Stress", "confidence": 0.5, "reasoning": "AI Offline"}

# --- 4. API ENDPOINTS ---
# Initialize DB (Update credentials if yours are different)
db_manager = BehavioralStateManager("bolt://localhost:7687", "neo4j", "password123")

@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_behavior(request: AnalysisRequest):
    # 1. Ask AI for classification
    prediction = query_local_ai(request.user_text)
    node = prediction["detected_node"].title()
    
    # 2. Check for relevant intervention
    breaker = INTERVENTIONS.get(node, {"title": "Check-in", "task": "Take 3 deep breaths."})
    
    # 3. Log to Neo4j (Logic check happens here)
    risk, is_loop = db_manager.log_and_analyze(
        node, 
        prediction["confidence"],
        title=breaker["title"],
        task=breaker["task"]
    )

    return AnalysisResponse(
        detected_node=node,
        confidence=prediction["confidence"],
        reasoning=prediction["reasoning"],
        risk_level=risk,
        loop_detected=is_loop,
        circuit_breaker_recommended=is_loop,
        intervention_title=breaker["title"] if is_loop else "",
        intervention_task=breaker["task"] if is_loop else ""
    )

@app.post("/feedback")
async def receive_feedback(request: FeedbackRequest):
    db_manager.resolve_intervention(request.success)
    return {"status": "recorded"}

@app.get("/history")
async def get_history():
    with db_manager.driver.session() as session:
        result = session.run("""
            MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
            OPTIONAL MATCH (e)-[:HAS_INTERVENTION]->(i:Intervention)
            RETURN 
                e.timestamp as time, 
                n.name as state, 
                i.title as intervention,
                e.confidence as confidence
            ORDER BY e.timestamp DESC LIMIT 20
        """)
        history = []
        for record in result:
            # Clean up the Neo4j datetime object for JSON
            history.append({
                "time": str(record["time"]),
                "state": record["state"],
                "intervention": record["intervention"] or "None",
                "confidence": record["confidence"]
            })
        return history

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)