# Development Guidelines

## Process

### 1. Planning & Staging

Break complex work into 3-5 stages. Document in `IMPLEMENTATION_PLAN.md`:

```markdown
## Stage N: [Name]
**Goal**: [Specific deliverable]
**Success Criteria**: [Testable outcomes]
**Tests**: [Specific test cases]
**Status**: [Not Started|In Progress|Complete]
```
- Update status as you progress
- Remove file when all stages are done

<important if="you are implementing a feature or fixing a bug">

### 2. Implementation Flow

1. **Understand** - Study existing patterns in codebase
2. **Test** - Write test first (red)
3. **Implement** - Minimal code to pass (green)
4. **Refactor** - Clean up with tests passing
5. **Commit** - With clear message linking to plan

</important>

### 3. When Stuck (After 3 Attempts)

**CRITICAL**: Maximum 3 attempts per issue, then STOP.

1. **Document what failed**: What you tried, specific error messages, why it failed
2. **Research alternatives**: Find 2-3 similar implementations, note different approaches
3. **Question fundamentals**: Is this the right abstraction level? Can this be split into smaller problems?
4. **Try different angle**: Different library feature? Different pattern? Remove abstraction instead of adding?

## Technical Standards

- Every commit must compile and pass all existing tests
- Never disable tests — fix them
- Include tests for new functionality
- Fail fast with descriptive messages; include context for debugging
- Handle errors at the appropriate level; never silently swallow exceptions
- Choose the boring, obvious solution over clever tricks

## Important Reminders

**NEVER**:
- Use `--no-verify` to bypass commit hooks
- Disable tests instead of fixing them
- Commit code that doesn't compile
- Make assumptions — verify with existing code
- Add features, refactors, or "improvements" beyond what was asked

**ALWAYS**:
- Commit working code incrementally
- Update plan documentation as you go
- Stop after 3 failed attempts and reassess
- Test behavior, not implementation

## Tools

### Context7
Use `resolve-library-id` then `query-docs` for any library/framework/SDK/API/CLI questions (React, Next.js, Prisma, etc.). Prefer over web search for library docs. Do not use for refactoring, business logic debugging, or general programming concepts.
