# Skill: Quality Gates (Phase 4)

**Category:** sdlc
**Phase:** 4 of 8
**Requires:** Supermodel API (scripts/supermodel.sh), `guardrails` skill
**System:** Big Iron — AI-Native SDLC

## Purpose

After code is written but before tests run, validate that the structural change is architecturally clean. This phase computes a graph diff, checks for dead code, validates new edges, and blocks advancement if violations are found.

---

## Procedure

### Step 1 — Trigger incremental graph update

Supermodel updates incrementally on file change. After writing all files in the changeset, confirm the graph is current:

```
POST /v1/analysis/circular-dependencies + dead-code
  since: "<commit SHA or timestamp of last clean graph>"
```

This returns: new nodes, removed nodes, new edges, removed edges.

### Step 2 — Validate new edges

For every new edge in the diff (A → B):

1. Is this call permitted by the domain layering? (check guardrails)
2. Does this introduce a new cross-domain dependency not approved in Phase 2?
3. Is B a real, defined symbol (not a dangling call)?

Any violation → **FAIL**. Fix the code, re-run the diff.

### Step 3 — Dead code check

```
POST /v1/analysis/dead-code
  scope: "<changed modules>"
```

If any new function has in-degree = 0 (no callers), it is either:
- Dead on arrival (delete it)
- Missing a call site (add the call)
- A public entrypoint (confirm explicitly)

All three cases require a decision. None can be silently ignored.

### Step 4 — Removed edge audit

For every removed edge in the diff (A no longer calls B):

- Is B now unreachable? If so, is it intentional dead code removal or accidental breakage?
- If B was a public interface, is it still reachable from another caller?

Flag unexpected removals.

### Step 5 — Coupling delta

Compare in-degree of modified modules before and after:

```
POST /v1/graphs/dependency
  module: "<modified module>"
```

If in-degree increased beyond the guardrail threshold, flag for review.

### Step 6 — Issue quality gate verdict

```markdown
## Quality Gate: <feature name>

**Status:** PASS | FAIL

### Graph Diff Summary
- New nodes: <count> (<list>)
- New edges: <count> (<list>)
- Removed nodes: <count> (<list>)
- Removed edges: <count> (<list>)

### Checks
- [ ] All new edges architecturally valid: PASS/FAIL
- [ ] No unintentional dead code: PASS/FAIL
- [ ] No unexpected edge removals: PASS/FAIL
- [ ] Coupling within threshold: PASS/FAIL

### Violations
<description and required fix>
```

---

## Verification

- [ ] Graph diff retrieved post-write (not pre-write)
- [ ] Every new edge validated against guardrails
- [ ] Every new node with in-degree 0 has an explicit disposition
- [ ] Status is PASS before advancing to Phase 5

---

## Pitfalls

- **Running the diff before all files in the changeset are written.** Incremental updates trigger per file; get the diff after the full changeset is complete.
- **Ignoring new nodes with in-degree 0.** Dead-on-arrival code is a quality problem even if it doesn't break tests.
- **Treating edge removals as neutral.** A removed edge can mean a broken call path. Always audit.
- **Skipping this phase because "it's just a small refactor."** Refactors produce the most structural changes. This phase is most valuable there.
