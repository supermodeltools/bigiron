# Skill: Architecture Review (Phase 2)

**Category:** sdlc
**Phase:** 2 of 8
**Requires:** Supermodel API (scripts/supermodel.sh), `guardrails` skill
**System:** Big Iron — AI-Native SDLC

## Purpose

Validate proposed structural changes against the existing architecture before any code is written. This phase catches domain violations, circular dependencies, and prohibited call patterns at design time — when they are cheapest to fix.

---

## Procedure

### Step 1 — Load guardrails

Load the `guardrails` skill to retrieve the project's architectural constraints:

```
skill_view("guardrails")
```

Extract:
- Permitted domain call directions (e.g., "domain A may call domain B, never the reverse")
- Prohibited cross-domain patterns
- Coupling thresholds (max allowed in-degree per module, max dependency depth)
- Protected interfaces (symbols that must not change signatures)

### Step 2 — Check for circular dependencies

```
POST /v1/graphs/dependency
  include_cycles: true
```

If any cycles are present in the proposed design path, **this phase fails**. Do not proceed to code generation. Report the cycle and propose a fix (typically: extract an interface, invert a dependency, or introduce an intermediary module).

### Step 3 — Validate domain layering

For each proposed new call edge (A calls B):

```
POST /v1/graphs/domain
```

Check:
1. Is A's domain permitted to call B's domain? (per guardrails)
2. Does this introduce a new cross-domain dependency not present in the current graph?
3. Does this violate the layering direction (e.g., infrastructure calling application logic)?

Flag violations. Do not proceed until resolved.

### Step 4 — Check protected interfaces

If the plan includes modifying a function that is marked as a protected interface in guardrails:

```
POST /v1/analysis/impact?targets=file:fn
  symbol: "<protected symbol>"
```

If blast radius includes external callers (outside the domain), escalate. A signature change here affects a public contract.

### Step 5 — Coupling check

```
POST /v1/graphs/dependency
  module: "<target module>"
```

Count in-degree (how many modules depend on this one). If it exceeds the guardrail threshold, flag for discussion before adding more dependents.

### Step 6 — Issue the arch review verdict

```markdown
## Architecture Review: <feature name>

**Status:** PASS | FAIL | CONDITIONAL

### Checks
- [ ] No circular dependencies: PASS/FAIL
- [ ] Domain layering respected: PASS/FAIL (<violations if any>)
- [ ] Protected interfaces unchanged: PASS/FAIL
- [ ] Coupling within threshold: PASS/FAIL

### Violations (if any)
<description and proposed resolution>

### Conditional Approvals
<any constraints that must hold during implementation>
```

---

## Verification

- [ ] All four checks completed with explicit PASS/FAIL
- [ ] Any FAIL has a proposed resolution documented
- [ ] Status is PASS or CONDITIONAL before advancing to Phase 3

---

## Pitfalls

- **Approving a CONDITIONAL without recording the condition.** Write the condition into the implementation plan (Phase 1 output) so it's visible during code generation.
- **Missing transitive cycles.** Direct dependency is cycle-free doesn't mean transitive closure is. Use `include_cycles: true` in the query.
- **Not checking domain graph after a "small" structural change.** Domain violations often come from one-line changes. Always run the check.
- **Treating the arch review as optional for refactors.** Refactors are the most common source of domain violations. Never skip.
