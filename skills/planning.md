# Skill: Planning & Scoping (Phase 1)

**Category:** sdlc
**Phase:** 1 of 8
**Requires:** Supermodel API (`api.supermodeltools.com`) or `scripts/graph_gate.sh`
**System:** Big Iron — AI-Native SDLC

## Purpose

Ground every feature or bugfix in graph data before a single line of code is written. This skill produces a structured implementation plan with blast radius, domain ownership, and affected callers pre-computed from the live code graph.

---

## Procedure

### Step 1 — Identify the target symbol(s)

ZIP the codebase and submit to the domain graph endpoint:

```bash
# POST /v1/graphs/domain  (multipart ZIP, X-Api-Key header)
./scripts/graph_gate.sh arch <codebase-path>
# or direct:
./scripts/supermodel.sh domain <codebase-path>
```

Returns domains (e.g. Orchestration, Application, Domain, Infrastructure) and subdomains.
Record: which domain/subdomain owns the affected file.

### Step 2 — Compute blast radius

Submit the codebase ZIP to the impact analysis endpoint:

```bash
# POST /v1/analysis/impact?targets=<file>:<function>
./scripts/graph_gate.sh impact <codebase-path> <file:function>
# or direct:
./scripts/supermodel.sh impact <codebase-path> <file:function>
```

Record:
- Direct dependents count
- Transitive dependents count
- Affected files count
- Risk score (low/medium/high/critical)
- Risk factors (fan-in, cross-domain boundaries)

### Step 3 — Map dependencies

```bash
# POST /v1/graphs/dependency
./scripts/supermodel.sh dependency <codebase-path>
```

Record:
- Modules this code depends on (in-edges)
- Modules that depend on this code (out-edges)
- Any third-party dependencies in the chain

### Step 4 — Produce the implementation plan

Structure:

```markdown
## Implementation Plan: <feature name>

**Domain:** <subdomain>
**Target symbol(s):** <list>
**Estimated blast radius:** <N direct, M transitive callers>
**Cross-domain callers:** <list or "none">
**Dependency surface:** <key deps in/out>

### Checklist
- [ ] Phase 2: Arch review (no circular deps, no domain violations)
- [ ] Phase 3: Implement <symbol> with graph-matching signatures
- [ ] Phase 3: Update <N callers> if signature changes
- [ ] Phase 4: Quality gate — graph diff clean
- [ ] Phase 5: Test blast radius (<list affected test suites>)
- [ ] Phase 6: Graph-annotated review ready
- [ ] Phase 7: Refactor opportunities noted: <list or "none">

### Risk Flags
<any cross-domain callers, high-betweenness symbols, or public API surfaces>
```

---

## Verification

- [ ] Every symbol in scope has a recorded domain classification
- [ ] Blast radius is non-zero for existing code changes (if zero, verify the symbol is real)
- [ ] Cross-domain callers are explicitly listed (not silently ignored)
- [ ] Implementation checklist covers all 8 phases

---

## Pitfalls

- **Scoping to a function when the real blast is at the module level.** Always check the module dependency graph, not just the function call graph.
- **Ignoring cross-domain callers.** These are the most likely sources of regression. Flag them explicitly.
- **Treating a zero blast radius as safe.** Zero callers may mean dead code. Use `POST /v1/analysis/dead-code` to confirm.
- **Skipping this phase for "small" changes.** The blast radius of small changes is often larger than expected. Always run it.

---

## Token Notes

This entire phase should use zero file reads. All data comes from graph queries. If you find yourself reading source files during planning, stop and find the graph query that answers your question instead.

---

*Big Iron — Ride the graph. Ship clean iron.*
