# Skill: Refactoring & Debt Reduction (Phase 7)

**Category:** sdlc
**Phase:** 7 of 8
**Requires:** Supermodel API (scripts/supermodel.sh), `guardrails` skill
**System:** Big Iron — AI-Native SDLC

## Purpose

Plan and execute refactors safely using graph-derived sequencing. Touch leaves first, propagate up the call chain. Use graph metrics to identify the highest-value and highest-risk targets. Capture successful patterns as skill updates.

---

## Procedure

### Step 1 — Identify refactor candidates

Run one or more of these queries depending on the refactor type:

**Dead code removal:**
```
POST /v1/analysis/dead-code
  scope: "<module or full codebase>"
```

**High-coupling modules (over-depended-upon):**
```
POST /v1/graphs/dependency
  sort_by: "in_degree"
  limit: 10
```

**Deep dependency chains (fragile paths):**
```
POST /v1/graphs/dependency
  sort_by: "depth"
  limit: 10
```

**Circular dependencies:**
```
POST /v1/graphs/dependency
  include_cycles: true
```

### Step 2 — Prioritize targets

Score each candidate:

| Score | Criteria |
|---|---|
| +2 | Circular dependency (must fix) |
| +2 | In-degree above guardrail threshold |
| +1 | Dead code |
| +1 | Depth > 5 in dependency chain |
| −1 | Protected interface (higher risk) |
| −1 | Cross-domain callers > 5 (higher blast radius) |

Work highest score first.

### Step 3 — Plan the refactor sequence

For each target, derive execution order from the call graph:

```
POST /v1/graphs/call
  symbol: "<target symbol>"
  direction: "bottom-up"
```

Topological sort gives the correct refactor order:
1. Leaf symbols first (no callers in the subgraph)
2. Their callers next
3. Continue up until the root

**Never touch a caller before its callees are refactored.** Doing so produces a window where the code is broken.

### Step 4 — Execute in sequence

For each symbol in order:
1. Run Phase 2 (arch check) on the proposed change
2. Write the refactored code (Phase 3)
3. Run the quality gate (Phase 4)
4. Run blast-radius tests (Phase 5)
5. Advance to next symbol in sequence

If any phase fails, stop. Fix the failure before continuing. Do not proceed with a broken intermediate state.

### Step 5 — Dead code sweep (end of refactor)

After all refactors complete:

```
POST /v1/analysis/dead-code
  scope: "<affected modules>"
```

Any newly unreachable functions should be deleted. Re-run the quality gate after deletion.

### Step 6 — Update the refactor skill

After a successful refactor, record what worked:

```
skill_manage patch "refactor"
  add: |
    ## Pattern: <refactor type> in <domain/module>
    Sequence: <what order worked>
    Pitfall avoided: <what would have broken>
    Token cost: <low/medium/high>
```

---

## Verification

- [ ] Refactor targets prioritized by score (not arbitrary)
- [ ] Execution sequence derived from topological sort (not guessed)
- [ ] Phase 2, 3, 4, 5 run for each symbol in sequence
- [ ] Dead code sweep run after all refactors complete
- [ ] Skill updated with pattern and outcome

---

## Pitfalls

- **Refactoring callers before callees.** This is the most common sequencing mistake. Always work bottom-up.
- **Doing a large refactor in one changeset.** Break it into per-symbol commits. Each should pass the quality gate independently.
- **Skipping dead code cleanup after a refactor.** Refactors commonly orphan functions. Always run the dead code sweep at the end.
- **Refactoring a protected interface without an explicit decision.** Check guardrails before touching anything marked as a public contract.
