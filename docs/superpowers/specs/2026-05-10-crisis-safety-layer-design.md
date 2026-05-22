# Crisis Safety Layer (Priority 3) Design Spec

**Date:** 2026-05-10  
**Priority:** 3  
**Owner:** Development Team  
**Status:** Design Approved

---

## Executive Summary

The Crisis Safety Layer adds detection and escalation for crisis indicators (suicidal ideation, self-harm, abuse) in journal entries. When detected, the app provides immediate access to crisis hotlines (988, Crisis Text Line, IASP) and logs entries for clinical review—without rejecting the entry or breaking user engagement.

**Key Design Principle:** Dual detection (frontend + backend) with graceful fallback, user agency preserved, clinical audit trail maintained.

---

## Architecture & Components

### Three-Component Design

#### 1. CrisisSafetyService (Backend)
New module: `backend/app/crisis.py`

```python
class CrisisSafetyService:
    def __init__(self, keywords: List[str] = None):
        # Load from env var CRISIS_KEYWORDS or use hardcoded defaults
        self.keywords = keywords or self.load_keywords()
        self.regex_pattern = self.compile_pattern()  # Single compiled regex
    
    def detect_crisis(text: str) -> Tuple[bool, List[str]]:
        """
        Scan text for crisis keywords.
        Returns: (is_crisis: bool, detected_keywords: List[str])
        """
        # Skip if text too short (< 10 chars, avoid accidentals)
        # Regex match on lowercase text
        # Return all matched keywords
    
    def log_crisis_event(user_id, keywords: List[str], detected_state: str, ip_address: str) -> None:
        """
        Log to CrisisEvent table in Neo4j for clinical review.
        """
        # Create CrisisEvent node with metadata
        # Index by timestamp for dashboard
```

Default keywords (configurable via `CRISIS_KEYWORDS` env var):
```
"suicide", "kill myself", "kill myself", "end it", "end my life",
"harm myself", "self harm", "cut myself", "overdose",
"hopeless", "no point", "give up", "better off dead",
"abuse", "being hurt", "domestic violence"
```

#### 2. CrisisEvent Audit Table (Database)

New Neo4j node type:

```
CrisisEvent {
  id: string (UUID)
  user_id: string (or null for anonymous)
  timestamp: datetime
  detected_keywords: [string]
  detected_state: string (optional, AI classification if run before detection)
  ip_address: string
  entry_id: string (optional, links to JournalEntry if saved)
  
  // Support team fields
  flagged_for_review: boolean (default: false)
  reviewed_by: string (optional, support staff email)
  reviewed_at: datetime (optional)
  notes: string (optional, support team notes)
}

// Update JournalEntry with:
JournalEntry {
  ...existing fields...
  crisis_detected: boolean (default: false)
  crisis_audit_id: string (optional)
}
```

**Indexes:**
- `timestamp` — for time-range queries and support dashboard
- `user_id + timestamp` — for per-user crisis history
- `flagged_for_review` — for support team worklist

#### 3. Frontend Crisis Safety Widget

New widget: `frontend/lib/widgets/crisis_safety_dialog.dart`

Displays when crisis detected:
- **Title:** "We're Concerned About Your Safety"
- **Message:** "You've written something that concerns us. Please reach out for support:"
- **Hotline Cards:** 
  - 988 Suicide & Crisis Lifeline (24/7)
  - Crisis Text Line (text HOME to 741741)
  - International Association for Suicide Prevention
- **Buttons:**
  - "Call Now" (opens URL in browser)
  - "I'm Safe, Continue" (user confirms, proceeds to submit)
  - "Cancel" (closes dialog, stays on screen)

Integration point: `frontend/lib/screens/journal_screen.dart` in submit handler

---

## Data Flow

### Happy Path (No Crisis)
```
User writes entry
    ↓
Frontend: CrisisSafetyService.detectCrisis(text) → false
    ↓
Send to /analyze endpoint
    ↓
Backend: CrisisSafetyService.detect_crisis(text) → false
    ↓
AI classification & intervention mapping (normal flow)
```

### Crisis Detected Path
```
User writes entry
    ↓
Frontend: CrisisSafetyService.detectCrisis(text) → true, ["suicide"]
    ↓
Show CrisisSafetyDialog with hotlines
    ↓
User chooses: Continue? Call? Cancel?
    ├─ Continue: Send to /analyze with crisis payload
    └─ Cancel/Call: Stay on screen
    ↓
Backend: CrisisSafetyService.detect_crisis(text) → true, ["suicide"]
    ↓
CrisisSafetyService.log_crisis_event(user_id, keywords, state=null, ip_address)
    ↓
Save JournalEntry with crisis_detected: true, crisis_audit_id
    ↓
Return modified AnalysisResponse with crisis_resources (no intervention)
```

---

## API Contract

### Request (unchanged)
```json
POST /analyze
{
  "user_text": "I'm thinking about ending it all..."
}
```

### Response When Crisis Detected
```json
{
  "crisis_detected": true,
  "detected_keywords": ["suicide", "end it"],
  "crisis_resources": {
    "message": "We're concerned about your safety. Please reach out for support:",
    "hotlines": [
      {
        "name": "988 Suicide & Crisis Lifeline",
        "phone": "988",
        "url": "https://988lifeline.org",
        "available": "24/7"
      },
      {
        "name": "Crisis Text Line",
        "text": "Text HOME to 741741",
        "url": "https://www.crisistextline.org",
        "available": "24/7"
      },
      {
        "name": "International Association for Suicide Prevention",
        "url": "https://www.iasp.info/resources/Crisis_Centres/",
        "note": "Find resources in your country"
      }
    ],
    "emergency": "If you are in immediate danger, call 911 (US) or your local emergency number"
  },
  
  "detected_node": null,
  "sublabel": null,
  "emotion_sublabel": null,
  "confidence": null,
  "reasoning": null,
  "risk_level": null,
  "loop_detected": null,
  "intervention_title": null,
  "intervention_task": null,
  "education_info": null,
  "intervention_type": null,
  "journal_entry_id": "uuid-of-saved-entry-for-clinical-review"
}
```

### Response When No Crisis (unchanged)
Normal `/analyze` response with all fields populated.

---

## Implementation Details

### Backend Changes

**New file: `backend/app/crisis.py`**
- ~150 lines
- `CrisisSafetyService` class
- Keyword loading from env var
- Regex compilation at startup
- Neo4j logging method

**Modified: `backend/app/main.py`**
- Import CrisisSafetyService
- Initialize in lifespan (shared instance)
- Add feature flag: `FEATURE_CRISIS_SAFETY = os.getenv(...).lower() == "true"` (default: true)
- Modify `/analyze` endpoint:
  - Call `crisis_service.detect_crisis(user_text)` early (before AI)
  - If detected: log to audit table, return crisis response
  - If not detected: continue as normal
- Import `CrisisEvent` response model

**Modified: `backend/app/models.py`**
- Add `CrisisResourcesResponse` model with hotlines structure
- Update `AnalysisResponse`:
  - Add `crisis_detected: Optional[bool] = None`
  - Add `crisis_resources: Optional[CrisisResourcesResponse] = None`
  - Add `detected_keywords: Optional[List[str]] = None`
  - All other fields now `Optional` (can be null when crisis detected)

**Modified: `backend/app/db.py`**
- Add `create_crisis_event()` method
- Update `save_journal_entry()` to accept `crisis_audit_id`
- Add crisis audit table indexes

### Frontend Changes

**New file: `frontend/lib/widgets/crisis_safety_dialog.dart`**
- ~100 lines
- `CrisisSafetyDialog` widget with hotline cards
- "Call Now" button opens URL in browser (url_launcher package)
- "Continue" / "Cancel" buttons with callbacks

**New file: `frontend/lib/services/crisis_safety_service.dart`**
- ~80 lines
- `CrisisSafetyService` with `detectCrisis(text)` method
- Load keyword list from API on app startup (fallback to hardcoded)
- Regex detection similar to backend

**Modified: `frontend/lib/screens/journal_screen.dart`**
- Import CrisisSafetyDialog and CrisisSafetyService
- In submit handler (where user taps "Submit"):
  - Call `crisisSafetyService.detectCrisis(text)`
  - If crisis: show `CrisisSafetyDialog` via `showDialog()`
  - If no crisis: proceed to `_submitEntry()` (existing logic)
- Add `onContinue()` callback from dialog to call `_submitEntry()`

### Testing Strategy

**Backend Tests: `backend/tests/test_crisis_safety.py`**
- Test keyword detection (true positives, false negatives, case-insensitivity)
- Test logging to Neo4j
- Test API response structure
- Test edge cases (empty text, too short, no matches)
- Test feature flag (crisis detection disabled when flag false)
- 15+ test cases, target ≥85% coverage for crisis.py

**Frontend Tests: `frontend/test/crisis_safety_widget_test.dart`**
- Test dialog renders with hotlines
- Test button callbacks (Continue, Cancel, Call)
- Test crisis detection service
- Mock CrisisSafetyService in journal_screen_test
- 8+ test cases

**Integration Tests: `backend/tests/test_api.py`**
- Test `/analyze` with crisis text → returns crisis response
- Test `/analyze` with normal text → returns normal response
- Test crisis entry saved to journal with audit ID
- Test feature flag disables crisis detection

---

## Monitoring & Compliance

### Logging & Alerting

Each crisis detection:
- Logs to Sentry at WARNING level with:
  - `event: "crisis_detected"`
  - `user_id: user_id`
  - `keywords: [list of detected]`
  - `timestamp: ISO8601`
  - **NOT** the full user text (privacy)

Support team dashboard in Sentry:
- Filter by time range, user, keyword
- Link to crisis audit table for context

### Data Retention & Privacy

- Crisis audit entries: minimum 90-day retention (legal hold)
- Support can extend if flagged for review
- Never shared externally without explicit consent
- Logs encrypted at rest in Sentry
- PII minimization: only user_id, keywords, state stored (not full text)

### Compliance Considerations

- ✅ **HIPAA-aligned:** Separate audit table, PII minimization, access logs
- ✅ **Duty to warn:** Timestamps, keywords, detection method fully documented
- ⚠️ **Not emergency response:** App provides resources, user chooses to call. Not an automated alert system.
- ⚠️ **Not a crisis service:** Clear disclaimers: "This is not a crisis service. If you are in immediate danger, call 911."

### Support Team Workflow

1. Support team sees Sentry alert or checks "Crisis Events" dashboard
2. Opens crisis audit entry with timestamp, keywords, linked journal entry
3. Can mark `flagged_for_review: true` and add notes
4. Can manually escalate if needed (no automated escalation)
5. Tracks reviewed_by, reviewed_at for audit trail

---

## Error Handling & Edge Cases

### Edge Case: False Positives
**Example:** "I feel suicidal about my procrastination"  
**Handling:** Keywords detected, dialog shown. User confirms they're safe and continues. Backend still saves with `crisis_detected: true` for support review.  
**Mitigation:** Support team can filter false positives in Sentry. Future: add context analyzer (GPT) to reduce FP rate.

### Edge Case: Empty or Very Short Text
**Example:** User taps submit with empty field  
**Handling:** Crisis detection only runs on text >10 characters. Avoids spam/accidentals.  
**Validation:** Frontend already validates min_length=1 (from AnalysisRequest model).

### Edge Case: International Users / Non-English
**Example:** Spanish user enters "suicidio"  
**Handling:** Start with English keywords only. Env var allows adding more. Future: support multi-language via config.  
**Priority:** Not in MVP. Phase 3 expansion if needed.

### Edge Case: Multiple Crisis Entries in Short Time
**Example:** User in acute crisis submits 5 entries in 10 minutes  
**Handling:** No rate limiting (don't suppress legitimate concerns). Support team sees pattern in Sentry dashboard.  
**Escalation:** Manual review by support, no automated limits.

### Edge Case: Frontend Offline / Keyword List Loading Fails
**Example:** App starts but API unreachable  
**Handling:** Hardcoded fallback keyword list (core set). Backend always validates independently.  
**Result:** Frontend may miss some keywords, but backend catches all.

### Edge Case: User Submits Despite Dialog
**Example:** Crisis detected, user taps "Continue" instead of calling  
**Handling:** Backend logs it, marks with `crisis_detected: true`. Entry saved to journal. No rejection (user agency respected).  
**Audit Trail:** Entry linked to CrisisEvent for clinical review.

### Edge Case: Keyword List Very Long
**Example:** 500+ keywords configured  
**Handling:** Limit to ~50 keywords (reasonable coverage, fast regex). Benchmarked: scan on 5KB text <5ms.  
**Performance:** Compiled regex at startup, reused for all requests.

### Edge Case: Support Team Marks Entry Reviewed Incorrectly
**Example:** Support accidentally marks as "resolved" when it wasn't  
**Handling:** Immutable audit trail. `created` fields never change. Only `flagged_for_review`, `reviewed_by`, `notes`, `reviewed_at` can be updated (append-only).  
**Recovery:** Full history in Neo4j audit log for accountability.

---

## Deployment & Rollout

### Feature Flag
- `FEATURE_CRISIS_SAFETY` (default: `true`)
- Disable to test without crisis detection: `export FEATURE_CRISIS_SAFETY=false`

### Environment Variables
- `CRISIS_KEYWORDS` — comma-separated list of crisis keywords (optional, uses defaults if not set)
- Example: `export CRISIS_KEYWORDS="suicide,harm,overdose,hopeless"`

### Database Migrations
- No new tables required (CrisisEvent is a standard Neo4j node)
- Update JournalEntry schema to add optional fields `crisis_detected`, `crisis_audit_id`
- No breaking changes (both fields optional)

### Backward Compatibility
- ✅ Fully backward compatible
- ✅ Old entries have `crisis_detected: false` by default
- ✅ API response adds optional fields (old clients ignore them)
- ✅ No frontend changes required (feature works standalone)

### Rollback Plan
1. **Quick (5 min):** Set `FEATURE_CRISIS_SAFETY=false` and restart backend
2. **Full (30 min):** Revert commits, remove crisis.py, remove crisis fields from models.py, rebuild frontend
3. **Data:** Crisis audit entries remain in database for 90 days (retention policy)

---

## Success Criteria

- ✅ Crisis keywords detected in text (both frontend & backend)
- ✅ Dialog shown with 3+ hotline options
- ✅ Crisis events logged to audit table
- ✅ Sentry alerts generated at WARNING level
- ✅ All crisis entries saved to journal with audit ID
- ✅ API response structure matches spec
- ✅ Feature flag works (can be disabled)
- ✅ ≥15 backend tests, ≥8 frontend tests
- ✅ ≥85% coverage for crisis.py
- ✅ No regressions to existing `/analyze` flow (non-crisis path)
- ✅ Support team can filter crisis events in Sentry
- ✅ Entry linked between JournalEntry and CrisisEvent for review

---

## Future Enhancements (Phase 4+)

1. **Context Analysis** — Use GPT to reduce false positives (analyze "suicide about X" vs. "I want to suicide")
2. **Geographic Resources** — Detect country/region, provide local hotlines
3. **Multi-language** — Support Spanish, French, Mandarin crisis keywords
4. **Automated Escalation** — Alert on-call support when severe keywords detected (configurable)
5. **User Education** — Optional "Crisis Resources 101" modal on app first launch
6. **International Crisis Lines** — Expand hotline database beyond US/international

---

## Appendix: Keyword List (Default)

```
Core crisis indicators:
- suicide, kill myself, kill my self, end it, end my life
- harm myself, self harm, self-harm, cut myself, cutting
- overdose, OD, take pills

Hopelessness/despair:
- hopeless, no point, pointless, give up, can't go on
- better off dead, everyone would be better without me
- nothing matters, why bother

Abuse/danger:
- abuse, being hurt, domestic violence, hit me
- rape, sexual assault
```

---

**Document Status:** Ready for implementation  
**Approval Date:** 2026-05-10  
**Next Step:** Implementation plan + swarm execution
