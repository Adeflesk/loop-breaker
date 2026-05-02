from pydantic import BaseModel, Field
from typing import Optional, List, Dict

class AnalysisRequest(BaseModel):
    user_text: str = Field(..., min_length=1, max_length=5000)

class FeedbackRequest(BaseModel):
    success: bool
    needs_check: Optional[Dict[str, bool]] = None
    halt_results: Optional[Dict[str, bool]] = None
    chosen_variant: Optional[str] = None  # Tracks which intervention variant was selected

class InterventionOption(BaseModel):
    """A single intervention option for user selection."""
    title: str
    task: str
    education: str
    type: str


class MscStep(BaseModel):
    """A single step in the Mindful Self-Compassion protocol."""
    step: int
    name: str
    task: str
    education: str


class ThoughtRecordRequest(BaseModel):
    """Request to create a thought record."""
    situation: str = Field(..., min_length=1, max_length=2000)
    automatic_thought: str = Field(..., min_length=1, max_length=2000)
    evidence_for: str = Field(..., min_length=1, max_length=2000)
    evidence_against: str = Field(..., min_length=1, max_length=2000)
    balanced_thought: str = Field(..., min_length=1, max_length=2000)
    linked_node: Optional[str] = None


class ThoughtRecordResponse(BaseModel):
    """Thought record response."""
    timestamp: str
    situation: str
    automatic_thought: str
    evidence_for: str
    evidence_against: str
    balanced_thought: str
    linked_node: Optional[str] = None

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
    intervention_type: Optional[str] = None
    node_arc_position: Optional[int] = None  # 1-8, position in the Rewire loop
    node_arc_label: Optional[str] = None  # e.g., "Node 3 of 8 — Procrastination"
    intervention_variants: Optional[List[InterventionOption]] = None  # Alternative approaches for this state/sublabel
    msc_steps: Optional[List[MscStep]] = None  # Mindful Self-Compassion steps for Shame interventions
    shame_safety_alert: Optional[bool] = None  # True if Shame detected 3+ times in 24 hours

class InsightResponse(BaseModel):
    """For the Dashboard summary card."""
    message: str
    top_loop: Optional[str] = None
    success_rate: Optional[float] = None
    trend: Optional[str] = None
    streak: Optional[int] = None
    missing_need: Optional[str] = None
    trigger_count: Optional[int] = None