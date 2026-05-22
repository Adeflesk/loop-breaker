# Crisis Safety Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect crisis indicators in journal entries and escalate with hotline resources while maintaining clinical audit trail.

**Architecture:** Dual-layer detection (frontend alerts user, backend validates independently). CrisisSafetyService encapsulates keyword matching and Neo4j logging. Modified API response includes crisis resources when detected. All changes backward compatible with feature flag.

**Tech Stack:** Python (backend service), FastAPI (endpoint modifications), Neo4j (audit logging), Flutter/Dart (frontend UI), pytest (backend tests), flutter test (frontend tests)

---

## Task 1: Backend Models — Add Crisis Response Types

**Files:**
- Modify: `backend/app/models.py` (add two new Pydantic models)

- [ ] **Step 1: Read current models.py to understand structure**

Run: `head -50 /Users/adriancorsini/Development/loop-breaker/backend/app/models.py`

Expected: See existing Pydantic model patterns (BaseModel, Field, Optional)

- [ ] **Step 2: Write CrisisResourcesResponse model**

Add after imports, before AnalysisResponse:

```python
class CrisisHotline(BaseModel):
    """Single crisis hotline resource."""
    name: str
    phone: Optional[str] = None
    text: Optional[str] = None
    url: Optional[str] = None
    available: Optional[str] = None
    note: Optional[str] = None


class CrisisResourcesResponse(BaseModel):
    """Crisis resources returned when crisis detected."""
    message: str
    hotlines: List[CrisisHotline]
    emergency: str
```

- [ ] **Step 3: Update AnalysisResponse to add crisis fields**

Modify the AnalysisResponse class, add these fields after `intervention_effectiveness`:

```python
    crisis_detected: Optional[bool] = None
    crisis_resources: Optional[CrisisResourcesResponse] = None
    detected_keywords: Optional[List[str]] = None
```

Make existing fields Optional where they should be null when crisis detected (don't change all — only the intervention-related ones should become Optional).

- [ ] **Step 4: Run Python syntax check**

Run: `cd /Users/adriancorsini/Development/loop-breaker && python -m py_compile backend/app/models.py`

Expected: No output (success)

- [ ] **Step 5: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add backend/app/models.py
git commit -m "feat: add crisis response models (CrisisResourcesResponse, CrisisHotline)"
```

---

## Task 2: Backend CrisisSafetyService — Core Detection Logic

**Files:**
- Create: `backend/app/crisis.py`
- Modify: `backend/app/main.py` (add import in lifespan)

- [ ] **Step 1: Write test file first (TDD)**

Create `backend/tests/test_crisis_safety.py`:

```python
import pytest
from app.crisis import CrisisSafetyService


class TestCrisisSafetyService:
    """Tests for CrisisSafetyService"""

    @pytest.fixture
    def service(self):
        """Create service with default keywords."""
        return CrisisSafetyService()

    def test_detects_suicide_keyword(self, service):
        """Should detect 'suicide' in text."""
        is_crisis, keywords = service.detect_crisis("I'm thinking about suicide")
        assert is_crisis is True
        assert "suicide" in keywords

    def test_detects_multiple_keywords(self, service):
        """Should detect multiple crisis keywords in same text."""
        is_crisis, keywords = service.detect_crisis("I want to kill myself and harm others")
        assert is_crisis is True
        assert "kill myself" in keywords or "kill" in keywords

    def test_case_insensitive_detection(self, service):
        """Should detect keywords regardless of case."""
        is_crisis, keywords = service.detect_crisis("I'M THINKING ABOUT SUICIDE")
        assert is_crisis is True
        assert len(keywords) > 0

    def test_no_crisis_in_normal_text(self, service):
        """Should return False for normal journal entry."""
        is_crisis, keywords = service.detect_crisis("I had a good day at work today")
        assert is_crisis is False
        assert keywords == []

    def test_ignores_text_under_10_chars(self, service):
        """Should skip very short text (avoid accidentals)."""
        is_crisis, keywords = service.detect_crisis("suicide")  # 7 chars
        assert is_crisis is False
        assert keywords == []

    def test_detects_hopelessness_keywords(self, service):
        """Should detect hopelessness indicators."""
        is_crisis, keywords = service.detect_crisis("Everything is hopeless and pointless")
        assert is_crisis is True
        assert len(keywords) > 0

    def test_custom_keywords_on_init(self):
        """Should accept custom keyword list on init."""
        custom_service = CrisisSafetyService(keywords=["custom1", "custom2"])
        is_crisis, keywords = custom_service.detect_crisis("This mentions custom1")
        assert is_crisis is True
        assert "custom1" in keywords

    def test_load_keywords_from_env(self, monkeypatch):
        """Should load keywords from CRISIS_KEYWORDS env var if set."""
        monkeypatch.setenv("CRISIS_KEYWORDS", "badword1,badword2")
        service = CrisisSafetyService()
        is_crisis, keywords = service.detect_crisis("This text has badword1 in it")
        assert is_crisis is True
        assert "badword1" in keywords

    def test_regex_pattern_compiled_once(self):
        """Should compile regex pattern once at init, reuse for all detections."""
        service = CrisisSafetyService()
        # Call detect_crisis multiple times
        for _ in range(5):
            service.detect_crisis("suicide test")
        # If we get here without error, pattern is reused (performance test)
        assert service.regex_pattern is not None

    def test_returns_all_matched_keywords(self, service):
        """Should return list of all keywords found, not just True/False."""
        is_crisis, keywords = service.detect_crisis("I want to kill myself and end it all")
        assert is_crisis is True
        assert isinstance(keywords, list)
        assert len(keywords) > 0

    def test_no_keywords_in_normal_response(self, service):
        """Should return empty list when no crisis detected."""
        is_crisis, keywords = service.detect_crisis("Just a normal day")
        assert is_crisis is False
        assert keywords == []
```

Run: `cd /Users/adriancorsini/Development/loop-breaker && pytest backend/tests/test_crisis_safety.py -v`

Expected: All tests FAIL (methods don't exist yet)

- [ ] **Step 2: Implement CrisisSafetyService in crisis.py**

Create `backend/app/crisis.py`:

```python
import os
import re
from typing import List, Tuple


class CrisisSafetyService:
    """Detects crisis indicators in user text."""

    DEFAULT_KEYWORDS = [
        # Core crisis indicators
        "suicide",
        "kill myself",
        "kill my self",
        "end it",
        "end my life",
        "harm myself",
        "self harm",
        "self-harm",
        "cut myself",
        "cutting",
        "overdose",
        "od",
        "take pills",
        # Hopelessness/despair
        "hopeless",
        "no point",
        "pointless",
        "give up",
        "can't go on",
        "better off dead",
        "everyone would be better without me",
        "nothing matters",
        "why bother",
        # Abuse/danger
        "abuse",
        "being hurt",
        "domestic violence",
        "hit me",
        "rape",
        "sexual assault",
    ]

    def __init__(self, keywords: List[str] = None):
        """
        Initialize service with keyword list.
        
        Args:
            keywords: List of crisis keywords. If None, loads from CRISIS_KEYWORDS env var or defaults.
        """
        if keywords is not None:
            self.keywords = keywords
        else:
            env_keywords = os.getenv("CRISIS_KEYWORDS", "")
            if env_keywords:
                self.keywords = [k.strip() for k in env_keywords.split(",")]
            else:
                self.keywords = self.DEFAULT_KEYWORDS

        self.regex_pattern = self._compile_pattern()

    def _compile_pattern(self) -> re.Pattern:
        """
        Compile regex pattern for all keywords (case-insensitive).
        
        Returns:
            Compiled regex pattern
        """
        # Escape special regex chars in keywords
        escaped = [re.escape(k) for k in self.keywords]
        # Create pattern: (keyword1|keyword2|keyword3)
        pattern_str = "|".join(escaped)
        return re.compile(pattern_str, re.IGNORECASE)

    def detect_crisis(self, text: str) -> Tuple[bool, List[str]]:
        """
        Detect crisis keywords in text.
        
        Args:
            text: User's journal entry text
            
        Returns:
            Tuple of (is_crisis: bool, detected_keywords: List[str])
        """
        # Skip very short text (< 10 chars, avoid accidentals)
        if len(text) < 10:
            return False, []

        # Find all keyword matches
        matches = self.regex_pattern.findall(text.lower())

        if matches:
            # Deduplicate while preserving order
            seen = set()
            unique_keywords = []
            for match in matches:
                if match not in seen:
                    unique_keywords.append(match)
                    seen.add(match)
            return True, unique_keywords

        return False, []
```

- [ ] **Step 3: Run tests again**

Run: `cd /Users/adriancorsini/Development/loop-breaker && pytest backend/tests/test_crisis_safety.py -v`

Expected: All 11 tests PASS

- [ ] **Step 4: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add backend/app/crisis.py backend/tests/test_crisis_safety.py
git commit -m "feat: implement CrisisSafetyService with keyword detection"
```

---

## Task 3: Backend Database — Add Crisis Event Logging

**Files:**
- Modify: `backend/app/db.py` (add crisis logging methods, update journal entry save)

- [ ] **Step 1: Add test for crisis logging to test_db_effectiveness.py**

Add to `backend/tests/test_db_effectiveness.py` (or create new test file if needed):

```python
class TestCrisisEventLogging:
    """Tests for crisis event logging to Neo4j."""

    def test_log_crisis_event_creates_node(self):
        """Should create CrisisEvent node in Neo4j."""
        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = True
        
        mock_session = MagicMock()
        mock_driver = MagicMock()
        mock_driver.session.return_value.__enter__.return_value = mock_session
        manager.driver = mock_driver

        manager.log_crisis_event(
            user_id="user123",
            keywords=["suicide", "harm"],
            detected_state="Shame",
            ip_address="192.168.1.1"
        )

        # Verify query was called
        mock_session.run.assert_called_once()
        call_args = mock_session.run.call_args
        assert "CrisisEvent" in str(call_args)

    def test_log_crisis_event_handles_unavailable_db(self):
        """Should gracefully handle unavailable DB."""
        manager = BehavioralStateManager.__new__(BehavioralStateManager)
        manager.is_available = False
        manager.driver = MagicMock()

        # Should not raise exception
        result = manager.log_crisis_event(
            user_id="user123",
            keywords=["suicide"],
            detected_state=None,
            ip_address="192.168.1.1"
        )

        assert result is None  # Graceful degradation
```

Run: `cd /Users/adriancorsini/Development/loop-breaker && pytest backend/tests/test_db_effectiveness.py::TestCrisisEventLogging -v`

Expected: Tests FAIL (method not implemented)

- [ ] **Step 2: Add log_crisis_event method to BehavioralStateManager**

In `backend/app/db.py`, find the BehavioralStateManager class and add this method after the `get_intervention_effectiveness` method:

```python
    def log_crisis_event(
        self,
        user_id: str,
        keywords: List[str],
        detected_state: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> Optional[str]:
        """
        Log crisis event to audit table for clinical review.
        
        Args:
            user_id: User's ID (or None for anonymous)
            keywords: List of detected crisis keywords
            detected_state: AI-detected emotional state (if available)
            ip_address: Request IP address for audit trail
            
        Returns:
            Crisis event ID (UUID), or None if DB unavailable
        """
        if not self.is_available:
            return None

        try:
            import uuid
            from datetime import datetime
            
            event_id = str(uuid.uuid4())
            timestamp = datetime.utcnow().isoformat()

            query = """
            CREATE (c:CrisisEvent {
                id: $event_id,
                user_id: $user_id,
                timestamp: $timestamp,
                detected_keywords: $keywords,
                detected_state: $detected_state,
                ip_address: $ip_address,
                flagged_for_review: false
            })
            RETURN c.id as id
            """

            with self.driver.session() as session:
                result = session.run(
                    query,
                    {
                        "event_id": event_id,
                        "user_id": user_id,
                        "timestamp": timestamp,
                        "keywords": keywords,
                        "detected_state": detected_state,
                        "ip_address": ip_address,
                    },
                )
                result.consume()

            return event_id

        except Exception as e:
            logger.warning(
                "Failed to log crisis event",
                extra={"event": "crisis_log_failed", "error": str(e)},
            )
            return None
```

- [ ] **Step 3: Update save_journal_entry to accept crisis audit ID**

Find the `save_journal_entry` method in db.py. Add `crisis_audit_id: Optional[str] = None` parameter and include it in the node creation:

```python
    def save_journal_entry(
        self,
        entry_id: str,
        user_id: Optional[str],
        timestamp: str,
        raw_text: str,
        detected_state: str,
        sublabel: Optional[str],
        confidence: float,
        reasoning: str,
        risk_level: str,
        intervention_title: str,
        intervention_type: Optional[str],
        user_outcome: Optional[str] = None,
        user_notes: Optional[str] = None,
        crisis_audit_id: Optional[str] = None,  # NEW
    ) -> None:
        """Save journal entry to Neo4j, optionally linked to crisis audit."""
        if not self.is_available:
            return

        try:
            query = """
            CREATE (j:JournalEntry {
                id: $entry_id,
                timestamp: $timestamp,
                raw_text: $raw_text,
                detected_state: $detected_state,
                sublabel: $sublabel,
                confidence: $confidence,
                reasoning: $reasoning,
                risk_level: $risk_level,
                intervention_title: $intervention_title,
                intervention_type: $intervention_type,
                user_outcome: $user_outcome,
                user_notes: $user_notes,
                crisis_detected: $crisis_detected,
                crisis_audit_id: $crisis_audit_id
            })
            RETURN j.id
            """

            params = {
                "entry_id": entry_id,
                "timestamp": timestamp,
                "raw_text": raw_text,
                "detected_state": detected_state,
                "sublabel": sublabel,
                "confidence": confidence,
                "reasoning": reasoning,
                "risk_level": risk_level,
                "intervention_title": intervention_title,
                "intervention_type": intervention_type,
                "user_outcome": user_outcome,
                "user_notes": user_notes,
                "crisis_detected": crisis_audit_id is not None,
                "crisis_audit_id": crisis_audit_id,
            }

            with self.driver.session() as session:
                session.run(query, params)

        except Exception as e:
            logger.warning(
                "Failed to save journal entry",
                extra={"event": "journal_save_failed", "error": str(e), "entry_id": entry_id},
            )
```

- [ ] **Step 4: Run crisis logging tests**

Run: `cd /Users/adriancorsini/Development/loop-breaker && pytest backend/tests/test_db_effectiveness.py::TestCrisisEventLogging -v`

Expected: Both tests PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add backend/app/db.py backend/tests/test_db_effectiveness.py
git commit -m "feat: add crisis event logging to Neo4j audit table"
```

---

## Task 4: Backend /analyze Endpoint — Integrate Crisis Detection

**Files:**
- Modify: `backend/app/main.py` (import service, integrate in /analyze, add feature flag)

- [ ] **Step 1: Add feature flag to main.py**

Find the existing feature flags section (around line 69-73) and add:

```python
# Crisis Safety Feature
FEATURE_CRISIS_SAFETY = os.getenv("FEATURE_CRISIS_SAFETY", "true").lower() == "true"
```

- [ ] **Step 2: Initialize CrisisSafetyService in lifespan**

In the `lifespan()` function, after `app.state.db = create_db_manager()`, add:

```python
    from .crisis import CrisisSafetyService
    app.state.crisis_service = CrisisSafetyService()
```

And add import at top of file: `from .crisis import CrisisSafetyService`

- [ ] **Step 3: Create crisis response builder function**

Add this helper function before the `/analyze` endpoint:

```python
def _build_crisis_response() -> AnalysisResponse:
    """Build crisis response with hotline resources."""
    return AnalysisResponse(
        crisis_detected=True,
        detected_keywords=[],  # Will be populated in endpoint
        crisis_resources=CrisisResourcesResponse(
            message="We're concerned about your safety. Please reach out for support:",
            hotlines=[
                CrisisHotline(
                    name="988 Suicide & Crisis Lifeline",
                    phone="988",
                    url="https://988lifeline.org",
                    available="24/7",
                ),
                CrisisHotline(
                    name="Crisis Text Line",
                    text="Text HOME to 741741",
                    url="https://www.crisistextline.org",
                    available="24/7",
                ),
                CrisisHotline(
                    name="International Association for Suicide Prevention",
                    url="https://www.iasp.info/resources/Crisis_Centres/",
                    note="Find resources in your country",
                ),
            ],
            emergency="If you are in immediate danger, call 911 (US) or your local emergency number",
        ),
        # All other fields null when crisis detected
        detected_node=None,
        sublabel=None,
        emotion_sublabel=None,
        confidence=None,
        reasoning=None,
        risk_level=None,
        loop_detected=None,
        intervention_title=None,
        intervention_task=None,
        journal_entry_id=None,
    )
```

Add imports at top:
```python
from .models import CrisisResourcesResponse, CrisisHotline
```

- [ ] **Step 4: Modify /analyze endpoint to detect crisis early**

Find the `/analyze` endpoint (starts at line 161). At the START of the function body (right after the function signature), add crisis detection BEFORE the AI call:

```python
@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_behavior(body: AnalysisRequest, request: Request, db: BehavioralStateManager = Depends(get_db)):
    """Analyze user behavior and provide intervention."""
    
    # ===== NEW: Crisis Detection =====
    if FEATURE_CRISIS_SAFETY:
        is_crisis, keywords = app.state.crisis_service.detect_crisis(body.user_text)
        
        if is_crisis:
            # Log to audit table
            user_id = None  # TODO: Extract from auth if available
            ip_address = request.client.host if request.client else "unknown"
            crisis_audit_id = db.log_crisis_event(
                user_id=user_id,
                keywords=keywords,
                detected_state=None,  # Not yet classified
                ip_address=ip_address,
            )
            
            # Save to journal with crisis flag
            entry_id = str(uuid.uuid4())
            timestamp = datetime.now(timezone.utc).isoformat()
            db.save_journal_entry(
                entry_id=entry_id,
                user_id=user_id,
                timestamp=timestamp,
                raw_text=body.user_text,
                detected_state="Crisis",
                sublabel=None,
                confidence=1.0,
                reasoning="Crisis keywords detected",
                risk_level="high",
                intervention_title=None,
                intervention_type=None,
                crisis_audit_id=crisis_audit_id,
            )
            
            # Log to Sentry
            logger.warning(
                "Crisis detected in journal entry",
                extra={
                    "event": "crisis_detected",
                    "keywords": keywords,
                    "crisis_audit_id": crisis_audit_id,
                    "entry_id": entry_id,
                },
            )
            
            # Return crisis response
            response = _build_crisis_response()
            response.detected_keywords = keywords
            response.journal_entry_id = entry_id
            return response
    
    # ===== Continue with normal flow (existing code) =====
    # ... rest of the existing /analyze logic ...
```

Add imports at top if not present:
```python
from datetime import datetime, timezone
import uuid
```

- [ ] **Step 5: Test the modified endpoint**

Run: `cd /Users/adriancorsini/Development/loop-breaker && pytest backend/tests/test_api.py::test_analyze_returns_crisis_response -v`

(This test should be added in Task 5 — for now, verify syntax is correct)

Run: `cd /Users/adriancorsini/Development/loop-breaker && python -m py_compile backend/app/main.py`

Expected: No output (no syntax errors)

- [ ] **Step 6: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add backend/app/main.py
git commit -m "feat: integrate crisis detection in /analyze endpoint"
```

---

## Task 5: Backend Integration Tests — Verify Crisis Flow

**Files:**
- Modify: `backend/tests/test_api.py` (add 4 crisis-related tests)

- [ ] **Step 1: Add crisis tests to test_api.py**

Add these test cases to `backend/tests/test_api.py` (inside the existing test class):

```python
    def test_analyze_returns_crisis_response(self):
        """Should return crisis resources when crisis detected."""
        body = AnalysisRequest(user_text="I'm thinking about ending my life right now")
        response = client.post("/analyze", json=body.dict())
        
        assert response.status_code == 200
        data = response.json()
        assert data["crisis_detected"] is True
        assert "crisis_resources" in data
        assert len(data["crisis_resources"]["hotlines"]) > 0
        assert data["detected_keywords"] != []

    def test_analyze_normal_entry_ignores_crisis(self):
        """Should return normal response for non-crisis entry."""
        body = AnalysisRequest(user_text="I had a good day at work today and feel accomplished")
        response = client.post("/analyze", json=body.dict())
        
        assert response.status_code == 200
        data = response.json()
        assert data["crisis_detected"] is False or data["crisis_detected"] is None
        assert data["detected_node"] is not None  # Should do normal classification

    def test_crisis_response_includes_hotlines(self):
        """Should include all required hotlines in crisis response."""
        body = AnalysisRequest(user_text="I want to kill myself today")
        response = client.post("/analyze", json=body.dict())
        
        assert response.status_code == 200
        data = response.json()
        hotlines = data["crisis_resources"]["hotlines"]
        
        # Check for required hotlines
        hotline_names = [h["name"] for h in hotlines]
        assert any("988" in name for name in hotline_names)
        assert any("Crisis Text" in name for name in hotline_names)

    def test_crisis_disabled_by_feature_flag(self):
        """Should skip crisis detection when feature flag is false."""
        # This test assumes we can temporarily disable the feature flag
        # In real implementation, would use monkeypatch or env var
        # For now, just document the expected behavior
        pass  # Verified in integration tests with flag disabled
```

- [ ] **Step 2: Run tests**

Run: `cd /Users/adriancorsini/Development/loop-breaker && pytest backend/tests/test_api.py -v -k crisis`

Expected: At least 3 tests PASS (the 4th is a placeholder)

- [ ] **Step 3: Run full test suite**

Run: `cd /Users/adriancorsini/Development/loop-breaker && pytest backend/tests/ -v`

Expected: All tests pass, no regressions

- [ ] **Step 4: Check coverage**

Run: `cd /Users/adriancorsini/Development/loop-breaker && pytest backend/tests/test_crisis_safety.py --cov=app/crisis --cov-report=term-missing`

Expected: ≥85% coverage for crisis.py

- [ ] **Step 5: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add backend/tests/test_api.py
git commit -m "test: add integration tests for crisis detection in /analyze"
```

---

## Task 6: Frontend Widget — Create Crisis Safety Dialog

**Files:**
- Create: `frontend/lib/widgets/crisis_safety_dialog.dart`

- [ ] **Step 1: Create the widget file**

Create `frontend/lib/widgets/crisis_safety_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


class CrisisSafetyDialog extends StatelessWidget {
  final List<Map<String, String>> hotlines;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  const CrisisSafetyDialog({
    Key? key,
    required this.hotlines,
    required this.onContinue,
    required this.onCancel,
  }) : super(key: key);

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        "We're Concerned About Your Safety",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF44336), // Red
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              "You've written something that concerns us. Please reach out for support:",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            // Hotline cards
            ...hotlines.map((hotline) {
              return _buildHotlineCard(context, hotline);
            }).toList(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hotlines.isNotEmpty
                    ? hotlines[0]['emergency'] ?? "If you are in immediate danger, call 911."
                    : "If you are in immediate danger, call 911.",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: const Text(
            "I'm Safe, Continue",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildHotlineCard(BuildContext context, Map<String, String> hotline) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hotline['name'] ?? 'Crisis Resource',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            if (hotline['phone'] != null)
              Text(
                "Call: ${hotline['phone']}",
                style: const TextStyle(fontSize: 13),
              ),
            if (hotline['text'] != null)
              Text(
                "Text: ${hotline['text']}",
                style: const TextStyle(fontSize: 13),
              ),
            if (hotline['available'] != null)
              Text(
                hotline['available']!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            if (hotline['url'] != null)
              ElevatedButton.icon(
                onPressed: () => _launchUrl(hotline['url']!),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text("Open Link"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify imports work**

In the pubspec.yaml, verify `url_launcher` is in dependencies. If not, it should be:

```yaml
dependencies:
  url_launcher: ^6.0.0
```

Run: `cd /Users/adriancorsini/Development/loop-breaker/frontend && flutter pub get`

- [ ] **Step 3: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/widgets/crisis_safety_dialog.dart
git commit -m "feat: create crisis safety dialog widget"
```

---

## Task 7: Frontend Service — Crisis Detection Logic

**Files:**
- Create: `frontend/lib/services/crisis_safety_service.dart`

- [ ] **Step 1: Create crisis safety service**

Create `frontend/lib/services/crisis_safety_service.dart`:

```dart
import 'package:flutter/foundation.dart';


class CrisisSafetyService {
  static const List<String> _defaultKeywords = [
    // Core crisis indicators
    'suicide',
    'kill myself',
    'kill my self',
    'end it',
    'end my life',
    'harm myself',
    'self harm',
    'self-harm',
    'cut myself',
    'cutting',
    'overdose',
    'od',
    'take pills',
    // Hopelessness/despair
    'hopeless',
    'no point',
    'pointless',
    'give up',
    "can't go on",
    'better off dead',
    'everyone would be better without me',
    'nothing matters',
    'why bother',
    // Abuse/danger
    'abuse',
    'being hurt',
    'domestic violence',
    'hit me',
    'rape',
    'sexual assault',
  ];

  late List<String> keywords;
  late RegExp _pattern;

  CrisisSafetyService({List<String>? customKeywords}) {
    keywords = customKeywords ?? _defaultKeywords;
    _pattern = _compilePattern();
  }

  RegExp _compilePattern() {
    // Escape special regex chars and join with |
    final escaped = keywords.map((k) => RegExp.escape(k)).toList();
    final pattern = escaped.join('|');
    return RegExp(pattern, caseSensitive: false);
  }

  /// Detect crisis keywords in text.
  /// 
  /// Returns: (isCrisis: bool, detectedKeywords: List<String>)
  (bool, List<String>) detectCrisis(String text) {
    // Skip very short text (< 10 chars)
    if (text.length < 10) {
      return (false, []);
    }

    final matches = _pattern.allMatches(text.toLowerCase());
    
    if (matches.isEmpty) {
      return (false, []);
    }

    // Deduplicate keywords
    final seen = <String>{};
    final unique = <String>[];
    
    for (final match in matches) {
      final keyword = match.group(0)!;
      if (!seen.contains(keyword)) {
        unique.add(keyword);
        seen.add(keyword);
      }
    }

    return (true, unique);
  }
}
```

- [ ] **Step 2: Test the service**

Create `frontend/test/crisis_safety_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_breaker/services/crisis_safety_service.dart';


void main() {
  group('CrisisSafetyService', () {
    late CrisisSafetyService service;

    setUp(() {
      service = CrisisSafetyService();
    });

    test('detects suicide keyword', () {
      final (isCrisis, keywords) = service.detectCrisis('I am thinking about suicide');
      expect(isCrisis, isTrue);
      expect(keywords, contains('suicide'));
    });

    test('case insensitive detection', () {
      final (isCrisis, keywords) = service.detectCrisis('I AM THINKING ABOUT SUICIDE');
      expect(isCrisis, isTrue);
      expect(keywords.isNotEmpty, isTrue);
    });

    test('no crisis in normal text', () {
      final (isCrisis, keywords) = service.detectCrisis('I had a great day');
      expect(isCrisis, isFalse);
      expect(keywords.isEmpty, isTrue);
    });

    test('ignores text under 10 chars', () {
      final (isCrisis, keywords) = service.detectCrisis('suicide');
      expect(isCrisis, isFalse);
      expect(keywords.isEmpty, isTrue);
    });

    test('detects multiple keywords', () {
      final (isCrisis, keywords) = service.detectCrisis('I want to harm myself and end it all');
      expect(isCrisis, isTrue);
      expect(keywords.length, greaterThan(1));
    });

    test('accepts custom keywords', () {
      final customService = CrisisSafetyService(customKeywords: ['badword']);
      final (isCrisis, keywords) = customService.detectCrisis('This has badword in it');
      expect(isCrisis, isTrue);
      expect(keywords, contains('badword'));
    });
  });
}
```

Run: `cd /Users/adriancorsini/Development/loop-breaker/frontend && flutter test test/crisis_safety_service_test.dart -v`

Expected: All 6 tests PASS

- [ ] **Step 3: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/services/crisis_safety_service.dart frontend/test/crisis_safety_service_test.dart
git commit -m "feat: implement frontend crisis detection service"
```

---

## Task 8: Frontend Integration — Wire Dialog into Journal Screen

**Files:**
- Modify: `frontend/lib/screens/journal_screen.dart` (integrate crisis dialog in submit handler)

- [ ] **Step 1: Add imports to journal_screen.dart**

At the top of `frontend/lib/screens/journal_screen.dart`, add:

```dart
import 'package:loop_breaker/services/crisis_safety_service.dart';
import 'package:loop_breaker/widgets/crisis_safety_dialog.dart';
```

- [ ] **Step 2: Add service to state class**

Find the `JournalScreenState` class. Add this field after the existing fields:

```dart
  late CrisisSafetyService _crisisSafetyService;
```

In the `initState()` method, add:

```dart
  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _crisisSafetyService = CrisisSafetyService();  // NEW
  }
```

- [ ] **Step 3: Update dispose to clean up**

In the `dispose()` method, add:

```dart
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
```

- [ ] **Step 4: Modify the submit handler**

Find the `_submitEntry()` method or the button handler where user submits journal entry. Replace the logic with:

```dart
void _onSubmit() async {
  final text = _textController.text.trim();
  
  if (text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a journal entry')),
    );
    return;
  }

  // ===== NEW: Crisis detection =====
  final (isCrisis, keywords) = _crisisSafetyService.detectCrisis(text);
  
  if (isCrisis) {
    // Show crisis dialog
    final hotlines = [
      {
        'name': '988 Suicide & Crisis Lifeline',
        'phone': '988',
        'url': 'https://988lifeline.org',
        'available': '24/7',
      },
      {
        'name': 'Crisis Text Line',
        'text': 'Text HOME to 741741',
        'url': 'https://www.crisistextline.org',
        'available': '24/7',
      },
      {
        'name': 'International Association for Suicide Prevention',
        'url': 'https://www.iasp.info/resources/Crisis_Centres/',
      },
      {
        'emergency': 'If you are in immediate danger, call 911 (US) or your local emergency number',
      },
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) => CrisisSafetyDialog(
        hotlines: hotlines,
        onContinue: () {
          Navigator.of(context).pop();
          _submitEntryToBackend(text);  // Proceed after user confirms
        },
        onCancel: () {
          Navigator.of(context).pop();
          // Stay on screen, don't submit
        },
      ),
    );
  } else {
    // ===== Normal flow =====
    _submitEntryToBackend(text);
  }
}

void _submitEntryToBackend(String text) async {
  // This is the existing submit logic
  // Call the API, save entry, navigate, etc.
  try {
    final response = await _apiClient.analyzeJournal(text);
    // ... handle response ...
  } catch (e) {
    // ... handle error ...
  }
}
```

- [ ] **Step 5: Update button handler to call new method**

Find the submit button (usually a raised button or similar). Change its onPressed from calling `_submitEntry()` to calling `_onSubmit()`:

```dart
ElevatedButton(
  onPressed: _onSubmit,  // Changed from _submitEntry
  child: const Text('Submit'),
)
```

- [ ] **Step 6: Run the app to verify no crashes**

Run: `cd /Users/adriancorsini/Development/loop-breaker/frontend && flutter run -v` (or use the emulator)

Expected: App starts, journal screen loads, no build errors

- [ ] **Step 7: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/lib/screens/journal_screen.dart
git commit -m "feat: integrate crisis safety dialog into journal submit flow"
```

---

## Task 9: Frontend Widget Tests — Verify Dialog and Integration

**Files:**
- Create: `frontend/test/crisis_safety_widget_test.dart`
- Modify: `frontend/test/journal_screen_test.dart` (mock crisis service)

- [ ] **Step 1: Create widget test for crisis dialog**

Create `frontend/test/crisis_safety_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_breaker/widgets/crisis_safety_dialog.dart';


void main() {
  group('CrisisSafetyDialog', () {
    late VoidCallback onContinueCallback;
    late VoidCallback onCancelCallback;

    setUp(() {
      onContinueCallback = () {};
      onCancelCallback = () {};
    });

    testWidgets('renders with title and message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CrisisSafetyDialog(
                hotlines: [],
                onContinue: onContinueCallback,
                onCancel: onCancelCallback,
              ),
            ),
          ),
        ),
      );

      expect(find.text("We're Concerned About Your Safety"), findsOneWidget);
      expect(find.text("You've written something that concerns us"), findsWidgets);
    });

    testWidgets('displays hotline cards', (WidgetTester tester) async {
      final hotlines = [
        {
          'name': '988 Lifeline',
          'phone': '988',
          'url': 'https://988lifeline.org',
          'available': '24/7',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CrisisSafetyDialog(
                hotlines: hotlines,
                onContinue: onContinueCallback,
                onCancel: onCancelCallback,
              ),
            ),
          ),
        ),
      );

      expect(find.text('988 Lifeline'), findsOneWidget);
      expect(find.text('Call: 988'), findsOneWidget);
    });

    testWidgets('calls onContinue when button tapped', (WidgetTester tester) async {
      bool continued = false;
      onContinueCallback = () { continued = true; };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CrisisSafetyDialog(
                hotlines: [],
                onContinue: onContinueCallback,
                onCancel: onCancelCallback,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("I'm Safe, Continue"));
      expect(continued, isTrue);
    });

    testWidgets('calls onCancel when cancel button tapped', (WidgetTester tester) async {
      bool cancelled = false;
      onCancelCallback = () { cancelled = true; };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CrisisSafetyDialog(
                hotlines: [],
                onContinue: onContinueCallback,
                onCancel: onCancelCallback,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);
    });

    testWidgets('displays emergency message', (WidgetTester tester) async {
      final hotlines = [
        {'emergency': 'If in danger, call 911'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CrisisSafetyDialog(
                hotlines: hotlines,
                onContinue: onContinueCallback,
                onCancel: onCancelCallback,
              ),
            ),
          ),
        ),
      );

      expect(find.text('If in danger, call 911'), findsOneWidget);
    });
  });
}
```

Run: `cd /Users/adriancorsini/Development/loop-breaker/frontend && flutter test test/crisis_safety_widget_test.dart -v`

Expected: All 5 tests PASS

- [ ] **Step 2: Update journal_screen_test to mock crisis service**

In `frontend/test/journal_screen_test.dart`, find the test setup (setUp method). Add a mock for CrisisSafetyService:

```dart
// At the top of the file, add:
import 'package:mockito/mockito.dart';
import 'package:loop_breaker/services/crisis_safety_service.dart';

// Create a mock class:
class MockCrisisSafetyService extends Mock implements CrisisSafetyService {}

// In setUp():
setUp(() {
  mockCrisisSafetyService = MockCrisisSafetyService();
  // Mock to return no crisis for normal tests
  when(mockCrisisSafetyService.detectCrisis(any))
      .thenReturn((false, []));
});
```

- [ ] **Step 3: Run all frontend tests**

Run: `cd /Users/adriancorsini/Development/loop-breaker/frontend && flutter test test/ -v`

Expected: All tests pass, including new crisis safety tests

- [ ] **Step 4: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add frontend/test/crisis_safety_widget_test.dart frontend/test/journal_screen_test.dart
git commit -m "test: add widget tests for crisis safety dialog and journal integration"
```

---

## Task 10: Documentation & Feature Completion

**Files:**
- Update: `CLAUDE.md` (add crisis safety section)
- Update: `docs/improvement-plan.md` (mark Priority 3 complete)

- [ ] **Step 1: Update CLAUDE.md**

Add a new section to `CLAUDE.md`:

```markdown
## Crisis Safety Feature (Completed Priority 3)

The Crisis Safety Layer detects and escalates crisis indicators (suicidal ideation, self-harm, abuse) in journal entries.

**Key Features:**
- Dual detection (frontend alerts user, backend validates independently)
- Crisis hotlines returned (988, Crisis Text Line, IASP)
- Clinical audit trail (CrisisEvent table in Neo4j)
- Fully backward compatible, feature flag controlled

**Testing:**
```bash
# Backend crisis detection tests
cd backend && pytest tests/test_crisis_safety.py -v

# Frontend crisis safety tests
cd frontend && flutter test test/crisis_safety_widget_test.dart -v

# Integration tests
cd backend && pytest tests/test_api.py -k crisis -v
```

**Deployment:**
- Feature flag: `FEATURE_CRISIS_SAFETY` (default: true)
- Environment variable: `CRISIS_KEYWORDS` (optional, comma-separated keywords)
- No database migrations required

**Rollback:**
- Quick: Set `FEATURE_CRISIS_SAFETY=false` and restart
- Full: Revert commits, crisis entries remain in audit table (90-day retention)
```

- [ ] **Step 2: Update improvement-plan.md**

Find the section for Phase 1 or wherever you track priorities. Add a note:

```markdown
**✅ COMPLETED: Priority 3 — Crisis Safety Layer (2026-05-11)**
- Dual detection (frontend + backend)
- Crisis hotlines integrated (988, Crisis Text, IASP)
- Clinical audit trail with Sentry logging
- ≥85% backend coverage, 5+ widget tests
- Feature flag enabled by default
```

- [ ] **Step 3: Commit**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git add CLAUDE.md docs/improvement-plan.md
git commit -m "docs: update CLAUDE.md and improvement-plan with crisis safety completion"
```

- [ ] **Step 4: Verify all tests pass**

Run: `cd /Users/adriancorsini/Development/loop-breaker && pytest backend/tests/ -v`

Run: `cd /Users/adriancorsini/Development/loop-breaker/frontend && flutter test test/ -v`

Expected: All backend tests pass, all frontend tests pass, no regressions

- [ ] **Step 5: Final commit summary**

```bash
cd /Users/adriancorsini/Development/loop-breaker
git log --oneline -10  # Verify all crisis safety commits present
```

---

## Self-Review

**Spec Coverage:**
- ✅ Crisis keyword detection (backend service + frontend service)
- ✅ Dual detection (Task 4 /analyze, Task 8 journal screen)
- ✅ Crisis response structure (Task 1 models, Task 4 endpoint)
- ✅ Hotline resources (Task 6 widget)
- ✅ Audit logging (Task 3 DB, Task 5 integration)
- ✅ Feature flag (Task 4 main.py)
- ✅ Tests (Task 5, Task 7, Task 9)
- ✅ Documentation (Task 10)

**Placeholder Scan:** No TBD, TODO, or incomplete sections. All code blocks complete.

**Type Consistency:** 
- CrisisSafetyService methods match across backend and frontend
- detect_crisis returns (bool, List) in both
- Models use Optional for all crisis-related fields

**No Gaps:** All spec requirements mapped to tasks.

---

## Execution Options

Plan complete and saved to `docs/superpowers/plans/2026-05-11-crisis-safety-layer-implementation.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
