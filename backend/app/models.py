from pydantic import BaseModel, Field
from typing import Optional, List, Dict

class AnalysisRequest(BaseModel):
    user_text: str = Field(..., min_length=1, max_length=5000)

class FeedbackRequest(BaseModel):
    success: bool
    needs_check: Optional[Dict[str, bool]] = None
    halt_results: Optional[Dict[str, bool]] = None

class AnalysisResponse(BaseModel):
    """The structured output sent back to the Flutter app."""
    detected_node: str
    sublabel: Optional[str] = None
    emotion_sublabel: Optional[str] = None
    confidence: float
    reasoning: str
    risk_level: str
    loop_detected: bool
    intervention_title: str
    intervention_task: str
    education_info: Optional[str] = None

class InsightResponse(BaseModel):
    """For the Dashboard summary card."""
    message: str
    top_loop: Optional[str] = None
    success_rate: Optional[float] = None
    trend: Optional[str] = None
    streak: Optional[int] = None
    missing_need: Optional[str] = None
    trigger_count: Optional[int] = None