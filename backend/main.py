import os
import requests
import json
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from neo4j import GraphDatabase

# --- CONFIGURATION ---
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "behavioral-agent"
NEO4J_URI = "bolt://localhost:7687"
NEO4J_USER = "neo4j"
NEO4J_PASSWORD = "password123" # <--- Update this!

app = FastAPI(title="LoopBreaker Analysis Engine")

# --- DATA MODELS ---
class AnalysisRequest(BaseModel):
    user_text: str

class AnalysisResponse(BaseModel):
    detected_node: str
    confidence: float
    reasoning: str
    risk_level: str # Added: "Low", "Medium", "High"
    loop_detected: bool # Added
    circuit_breaker_recommended: bool

# --- STATE MANAGER LOGIC ---
class BehavioralStateManager:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))

    def log_and_analyze(self, node_name: str, confidence: float):
        """Logs current state and checks for cycles in the history."""
        with self.driver.session() as session:
            # 1. Log the new entry
            session.run("""
                MATCH (n:Node {name: $name})
                CREATE (e:Entry {timestamp: datetime(), confidence: $conf})
                CREATE (e)-[:RECORDS_STATE]->(n)
            """, name=node_name.title(), conf=confidence)

            # 2. Analyze the last 5 entries to detect a 'Loop'
            result = session.run("""
                MATCH (e:Entry)-[:RECORDS_STATE]->(n:Node)
                WITH n, e ORDER BY e.timestamp DESC LIMIT 5
                RETURN collect(n.name) as history
            """)
            history = result.single()["history"]
            
            return self.calculate_risk(history)

    def calculate_risk(self, history):
        """Logic to determine if the user is stuck or cycling."""
        if len(history) < 3:
            return "Low", False
        
        # Rule A: Stagnation (Stuck in one spot)
        if history[0] == history[1] == history[2]:
            return "High", True
            
        # Rule B: Momentum (Moving through the cycle)
        # We check if the last 3 nodes follow the 8-node 'LEADS_TO' path
        # For simplicity in this dev version, we check for 'Unique' progression
        if len(set(history[:3])) == 3:
             return "Medium", True
             
        return "Low", False

db_manager = BehavioralStateManager(NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD)

# --- AI & API ENDPOINTS ---
@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_behavior(request: AnalysisRequest):
    # Call Ollama
    payload = {"model": MODEL_NAME, "prompt": request.user_text, "stream": False, "format": "json"}
    ai_raw = requests.post(OLLAMA_URL, json=payload).json()
    prediction = json.loads(ai_raw.get("response", "{}"))
    
    # Run through State Manager
    risk, is_loop = db_manager.log_and_analyze(
        prediction["detected_node"], 
        prediction["confidence"]
    )

    return AnalysisResponse(
        detected_node=prediction["detected_node"],
        confidence=prediction["confidence"],
        reasoning=prediction["reasoning"],
        risk_level=risk,
        loop_detected=is_loop,
        circuit_breaker_recommended=is_loop or (risk == "High")
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)