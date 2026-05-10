# Phase Implementation Skill

This skill standardizes the workflow for executing multi-task implementation phases with subagent coordination and verification.

## Workflow

1. **Read the spec** for the requested phase from docs/ or the conversation context
2. **Dispatch subagents** with explicit working directory (`/Users/adriancorsini/Development/loop-breaker`); record task IDs
3. **Verify each completion** before moving on:
   - Use `Read` or `ls` to confirm claimed files exist
   - Run the relevant test suite (backend: `pytest`, frontend: `flutter analyze`)
   - Check coverage thresholds match the phase acceptance criteria
4. **Run full test suite** after all tasks complete; report coverage
5. **Only commit** when all tests pass and coverage meets phase requirements

## Usage Pattern

```
/phase Phase X.Y

This will:
- Parse the phase spec
- Identify all tasks
- Dispatch implementers in parallel with explicit cwd
- Verify each task immediately after subagent reports done
- Maintain a TodoWrite checklist (impl/verify/commit status)
- Auto-commit when all tasks + tests pass
```

## Verification Checklist (per task)

- [ ] Subagent reported completion
- [ ] Files exist (Read/ls confirms)
- [ ] Relevant test file changed (git diff)
- [ ] Test suite passes (pytest/flutter analyze output)
- [ ] No regressions in other tests

## Anti-Pattern to Avoid

❌ Trust subagent completion claims without verifying files exist  
❌ Assume test pass if subagent didn't explicitly show output  
❌ Skip full suite run thinking "only touched this module"

## Success Criteria

Phase complete when:
- All tasks have verified file creation
- Full test suite passes (all tests passing count reported)
- Coverage meets phase acceptance criteria
- Single commit created with all changes
