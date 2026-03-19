# Skill: Code Review (Phase 6)

**Category:** sdlc
**Phase:** 6 of 8
**Requires:** Supermodel API (scripts/supermodel.sh), `guardrails` skill
**System:** Big Iron — AI-Native SDLC

## Purpose

Produce a graph-enriched code review that gives reviewers structural context — caller counts, domain impact, new dependencies — without requiring them to load the codebase in their head. Catch architectural violations in the review layer before they merge.

---

## Procedure

### Step 1 — Get the diff

Retrieve the changeset (git diff, PR diff, or file list). For each changed file, record the symbols added, modified, or removed.

### Step 2 — Annotate each changed symbol with graph data

For every modified or added function:

```
POST /v1/graphs/call  (search nodes)
  name: "<symbol>"
  include_callers: true
  include_callees: true
```

Produce an annotation:

```
<function name>
  Callers: <N> (<list top 3 by domain>)
  Callees: <list>
  Domain: <subdomain>
  Cross-domain callers: <list or "none">
  Is public interface: yes/no
```

### Step 3 — Diff the graph

```
POST /v1/analysis/circular-dependencies + dead-code
  since: "<base commit SHA>"
```

List structural changes introduced by this PR:
- New call edges
- Removed call edges
- New module dependencies
- Domain boundary crossings (new or removed)

### Step 4 — Run arch violation scan

For every new edge in the diff:

```
POST /v1/graphs/domain
```

Check against guardrails. Flag any domain layering violations or prohibited call patterns.

### Step 5 — Produce the review document

```markdown
## Code Review: <PR or feature name>

### Structural Impact Summary
- Files changed: <N>
- Symbols modified: <list>
- New call edges: <N>
- New module dependencies: <N>
- Domain boundary crossings: <N (detail below)>

### Symbol Annotations

**<function name>** (`<file>:<line>`)
> <what it does in one line>
- Callers: <N> total | <cross-domain callers if any>
- Callees added: <list>
- Public interface: yes/no
- Risk: LOW | MEDIUM | HIGH
  - Rationale: <e.g., "3 cross-domain callers; signature unchanged">

[repeat per symbol]

### Architectural Checks
- [ ] No new circular dependencies: PASS/FAIL
- [ ] Domain layering respected: PASS/FAIL
- [ ] Protected interfaces unchanged: PASS/FAIL
- [ ] No unintentional dead code: PASS/FAIL

### Violations
<detail and resolution required>

### Reviewer Focus Areas
<where to spend review time, based on risk annotations>
```

---

## Verification

- [ ] Every modified symbol has a graph annotation
- [ ] Graph diff included in review document
- [ ] All four architectural checks completed
- [ ] Risk level assigned to each symbol
- [ ] Review document produced before requesting human review

---

## Pitfalls

- **Producing a review summary from the diff alone without graph data.** Line-level review misses structural impact. Always include the graph annotation layer.
- **Skipping the arch violation scan because Phase 2 passed.** Implementation can deviate from the design. Run the scan again at review time.
- **Marking all symbols as LOW risk by default.** Risk should be derived from caller count, cross-domain exposure, and public interface status — not assumed.
- **Not flagging cross-domain callers.** These are the highest-impact call sites. Always surface them explicitly for reviewers.
