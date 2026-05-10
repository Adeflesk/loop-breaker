# Personalized Education Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform generic interventions into personalized teaching by adding personal loop context and intervention effectiveness tracking to the `/analyze` endpoint.

**Architecture:** Add three new Pydantic models (`PersonalLoopContext`, `InterventionStats`) to the data layer, update `AnalysisResponse` with optional fields, then implement backend DB methods to fetch data, and finally render personalized UI sections in the frontend.

**Tech Stack:** Python/Pydantic (backend models), FastAPI (endpoint), Neo4j (data source), Dart/Flutter (frontend rendering)

---

## Overview

This plan implements the Personalized Education feature in phases:
1. **Phase 1 (Models & DB):** Add Pydantic models, implement `get_intervention_effectiveness()`, wire into `/analyze`
2. **Phase 2 (Frontend):** Render personal loop context, effectiveness track record, personalized education
3. **Phase 3 (Testing & Polish):** Unit tests, integration tests, manual QA

This document focuses on **Phase 1, Task 1: Add Pydantic Models** as the foundation for all downstream work.

---

## Task 1: Add Pydantic Models to backend/app/models.py

**Files:**
- Modify: `backend/app/models.py` (lines 71-70, insert new models, update AnalysisResponse)
- Verify: No other files changed in this task

**Purpose:** Add `PersonalLoopContext` and `InterventionStats` models, then extend `AnalysisResponse` with two new optional fields.

---

### Step 1: Add PersonalLoopContext Model

**What:** Insert the `PersonalLoopContext` model after `class InsightResponse` (line 80) and before `class JournalEntryResponse` (line 82).

**File:** `/Users/adriancorsini/Development/loop-breaker/backend/app/models.py`

**Action:** Edit the file to add this model. The exact location is after line 80 (the blank line after InsightResponse closes).

Insert these lines:

```python
class PersonalLoopContext(BaseModel):
    """User's personal behavioral loop pattern."""
    most_common_entry: Optional[str] = None  # e.g., "Stress"
    cycle_length_hours: Optional[float] = None  # e.g., 4.5
    where_in_cycle: Optional[str] = None  # e.g., "procrastination_phase"
```

**After insertion, the file structure should be:**
- Line 71-80: InsightResponse
- Line 81: blank
- Line 82-85: **PersonalLoopContext (NEW)**
- Line 86: blank
- Line 87-95: JournalEntryResponse (shifted down)

**Exact edit string to replace:**
Old (line 80-82):
```
    missing_need: Optional[str] = None
    trigger_count: Optional[int] = None


class JournalEntryResponse(BaseModel):
```

New:
```
    missing_need: Optional[str] = None
    trigger_count: Optional[int] = None


class PersonalLoopContext(BaseModel):
    """User's personal behavioral loop pattern."""
    most_common_entry: Optional[str] = None  # e.g., "Stress"
    cycle_length_hours: Optional[float] = None  # e.g., 4.5
    where_in_cycle: Optional[str] = None  # e.g., "procrastination_phase"


class JournalEntryResponse(BaseModel):
```

---

### Step 2: Verify Syntax with py_compile

**What:** Ensure the file is syntactically valid Python after Step 1.

**Command:**
```bash
python3 -m py_compile /Users/adriancorsini/Development/loop-breaker/backend/app/models.py
```

**Expected output:** No output (success) or a SyntaxError if something is wrong.

**If it succeeds:** Move to Step 3.
**If it fails:** Check the error message, fix the indentation or syntax, and retry.

---

### Step 3: Add InterventionStats Model and Update AnalysisResponse

**What:** 
1. Add the `InterventionStats` model after `PersonalLoopContext` (before `JournalEntryResponse`)
2. Add two new fields to `AnalysisResponse`: `personal_loop` and `intervention_effectiveness`

**File:** `/Users/adriancorsini/Development/loop-breaker/backend/app/models.py`

**Part A: Insert InterventionStats after PersonalLoopContext**

Exact location: After line 85 (`where_in_cycle: Optional[str] = None`), before the blank line and `JournalEntryResponse`.

Insert these lines:

```python

class InterventionStats(BaseModel):
    """Effectiveness stats for a single intervention."""
    helped: int
    neutral: int
    didn_help: int
    total: int
    percentage: int  # 0-100
```

After this insertion, the file structure should be:
- PersonalLoopContext (lines 82-85)
- **InterventionStats (NEW, lines 87-91)**
- Blank line
- JournalEntryResponse (shifted further down)

**Part B: Update AnalysisResponse class**

Locate `class AnalysisResponse(BaseModel):` (currently line 49). At the end of this class definition (after line 69: `journal_entry_id: Optional[str] = None`), add these two new fields:

```python
    personal_loop: Optional[PersonalLoopContext] = None
    intervention_effectiveness: Optional[Dict[str, InterventionStats]] = None
```

The end of `AnalysisResponse` should now look like:
```python
    movement_protocol: Optional[Dict[str, Any]] = None  # Movement-based intervention variant (when flag enabled)
    journal_entry_id: Optional[str] = None  # UUID of saved journal entry, for outcome tracking
    personal_loop: Optional[PersonalLoopContext] = None
    intervention_effectiveness: Optional[Dict[str, InterventionStats]] = None
```

**Exact replacement text (Part B):**

Old (lines 68-69):
```python
    movement_protocol: Optional[Dict[str, Any]] = None  # Movement-based intervention variant (when flag enabled)
    journal_entry_id: Optional[str] = None  # UUID of saved journal entry, for outcome tracking
```

New:
```python
    movement_protocol: Optional[Dict[str, Any]] = None  # Movement-based intervention variant (when flag enabled)
    journal_entry_id: Optional[str] = None  # UUID of saved journal entry, for outcome tracking
    personal_loop: Optional[PersonalLoopContext] = None
    intervention_effectiveness: Optional[Dict[str, InterventionStats]] = None
```

---

### Step 4: Verify Dict is Imported

**What:** Ensure `Dict` is available in the imports at the top of the file.

**File:** `/Users/adriancorsini/Development/loop-breaker/backend/app/models.py`

**Check:** Look at line 2:
```python
from typing import Optional, List, Dict, Any
```

**Expected:** `Dict` should already be imported (it is, as of your current file state).

**If not present:** Add it to the import statement on line 2:
```python
from typing import Optional, List, Dict, Any
```

---

### Step 5: Verify Syntax Again

**What:** Ensure the entire file is syntactically valid after all changes.

**Command:**
```bash
python3 -m py_compile /Users/adriancorsini/Development/loop-breaker/backend/app/models.py
```

**Expected output:** No output (success).

**If it fails:** Check the error message and fix any issues. Common issues:
- Missing closing parenthesis or quote
- Incorrect indentation
- Typo in class or field names

---

### Step 6: Commit Changes

**What:** Create a git commit with the new models.

**Command:**
```bash
cd /Users/adriancorsini/Development/loop-breaker && git add backend/app/models.py && git commit -m "feat: add PersonalLoopContext and InterventionStats models"
```

**Expected output:**
```
[master <hash>] feat: add PersonalLoopContext and InterventionStats models
 1 file changed, 11 insertions(+)
```

**Verify:** Run `git log --oneline -1` to confirm the commit was created.

---

## Final Verification (After Task 1 Complete)

After completing all 6 steps, verify:

1. **File structure:** Run this to check the models are in place:
```bash
python3 -c "from backend.app.models import PersonalLoopContext, InterventionStats, AnalysisResponse; print('✓ All models imported successfully')"
```

2. **AnalysisResponse has new fields:** Run this Python snippet in the repo:
```bash
cd /Users/adriancorsini/Development/loop-breaker && python3 << 'EOF'
from backend.app.models import AnalysisResponse
import inspect

# Get the fields of AnalysisResponse
sig = AnalysisResponse.model_fields
print(f"personal_loop in fields: {'personal_loop' in sig}")
print(f"intervention_effectiveness in fields: {'intervention_effectiveness' in sig}")
EOF
```

Expected output:
```
personal_loop in fields: True
intervention_effectiveness in fields: True
```

3. **Git commit created:** Verify with:
```bash
cd /Users/adriancorsini/Development/loop-breaker && git log --oneline -1
```

Should show: `feat: add PersonalLoopContext and InterventionStats models`

---

## Task 1 Success Criteria

- ✅ `PersonalLoopContext` model added with 3 fields (most_common_entry, cycle_length_hours, where_in_cycle)
- ✅ `InterventionStats` model added with 5 fields (helped, neutral, didn_help, total, percentage)
- ✅ `AnalysisResponse` class updated with 2 new optional fields (personal_loop, intervention_effectiveness)
- ✅ File passes py_compile check (Step 2 and Step 5)
- ✅ Dict is imported from typing
- ✅ Commit created with message "feat: add PersonalLoopContext and InterventionStats models"

---

## What Comes Next (Task 2+)

After Task 1 is complete and committed, subsequent tasks will:

- **Task 2:** Implement `get_intervention_effectiveness()` method in `backend/app/db.py`
- **Task 3:** Update `/analyze` endpoint in `backend/app/main.py` to fetch and return new fields
- **Task 4:** Add frontend parsing and conditional rendering in `frontend/lib/screens/journal_screen.dart`
- **Task 5+:** Integration tests, manual QA, deployment

Task 1 is the foundation — without these models, Task 2+ cannot reference them.

---

**Document Status:** Ready for execution  
**Date:** 2026-05-09  
**Last Updated:** 2026-05-09
