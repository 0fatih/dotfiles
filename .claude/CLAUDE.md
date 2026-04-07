# Development Guidelines

## Process

### 1. Planning

For multi-file changes: use plan mode, break into 3-5 stages, document in `IMPLEMENTATION_PLAN.md`:

```markdown
## Stage N: [Name]
**Goal**: [Specific deliverable]
**Success Criteria**: [Testable outcomes]
**Tests**: [Specific test cases]
**Status**: [Not Started|In Progress|Complete]
```

Update status as you progress. Remove file when all stages are done.
For single-file or trivial changes: skip the plan, implement directly.

### 2. Implementation Flow

1. **Understand** — Study existing patterns in codebase
2. **Test** — Write test first (red)
3. **Implement** — Minimal code to pass (green)
4. **Refactor** — Clean up with tests passing
5. **Verify** — Run tests and linter; confirm passing before committing
6. **Commit** — Clear message linking to plan stage

### 3. When Stuck

**CRITICAL — maximum 3 attempts per issue, then STOP and report.**

After 3 failures: document what you tried, the exact error, and why it failed. Present findings and ask for direction. Do not loop.

## Standards

- Every commit must compile and pass all existing tests
- Never disable tests — fix them
- Tests cover behavior, not implementation details
- No `--no-verify` — ever
- Scope strictly: no unrequested features, refactors, or "improvements"
- Boring, obvious solution over clever tricks

## Context Management

- Use `/clear` between unrelated tasks to prevent context bleed
- For broad investigation (many files, multiple hypotheses): launch subagents; each gets a narrow, well-scoped question
- When compacting, preserve: list of modified files, current plan stage, and test commands

## Tools

### Context7
Use `resolve-library-id` then `query-docs` for library/framework/SDK/API/CLI questions. Prefer over web search for library docs. Do not use for refactoring, business logic, or general programming concepts.

### Skills
Load domain-specific skills on demand:
- `test-driven-development` — TDD workflow detail
- `context7-mcp` — full Context7 usage guide
