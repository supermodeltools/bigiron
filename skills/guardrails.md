# Skill: Architectural Guardrails

**Category:** sdlc
**Phase:** All phases
**Requires:** Supermodel API (scripts/supermodel.sh)
**System:** Big Iron — AI-Native SDLC

## Purpose

Define the architectural constraints for this project. All other phase skills load this skill to validate their work. This is the single source of truth for what is and isn't permitted in the codebase structure.

---

## Domain Layer Map

The factory uses a layered domain architecture. Calls may only flow **downward** through the layers. No upward or lateral cross-layer calls are permitted unless explicitly listed in the exceptions section.

```
┌─────────────────────────────────────┐  ← Layer 0 (top)
│           Orchestration             │  agents, workflows, SDLC runners
└───────────────────┬─────────────────┘
                    │ may call ↓
┌───────────────────▼─────────────────┐  ← Layer 1
│           Application               │  business logic, use cases
└───────────────────┬─────────────────┘
                    │ may call ↓
┌───────────────────▼─────────────────┐  ← Layer 2
│             Domain                  │  entities, domain services
└───────────────────┬─────────────────┘
                    │ may call ↓
┌───────────────────▼─────────────────┐  ← Layer 3
│           Infrastructure            │  MCP clients, APIs, storage, I/O
└─────────────────────────────────────┘  ← Layer 4 (bottom)
```

**Permitted call directions:**
- Layer N may call Layer N+1 (downward)
- Layer N may call Layer N (same layer, within reason)
- Layer N must NOT call Layer N-1 or above (upward)

---

## Coupling Thresholds

| Metric | Warning | Critical |
|---|---|---|
| Module in-degree (dependents) | > 8 | > 15 |
| Module out-degree (dependencies) | > 12 | > 20 |
| Dependency chain depth | > 5 | > 8 |
| Cross-domain caller count per symbol | > 5 | > 10 |
| Circular dependency count | > 0 | > 0 |

Circular dependencies are always CRITICAL. There is no acceptable count above 0.

---

## Protected Interfaces

These symbols form public contracts. Their signatures must not change without an explicit decision and a major version consideration:

```
# Add protected symbols here as the project grows
# Format: <fully qualified name> | <reason>
# Example:
# factory.sdlc.run_phase | Public SDLC runner API
# factory.graph.query    | Primary graph query interface
```

---

## Prohibited Call Patterns

1. **Infrastructure → Application**: No infrastructure module may call application logic. Infrastructure provides capabilities; application logic consumes them.
2. **Infrastructure → Orchestration**: Infrastructure must not know orchestration exists.
3. **Domain → Orchestration**: Domain services must not call workflow coordinators.
4. **Circular calls of any kind**: A → B → ... → A is always prohibited.
5. **Direct cross-agent calls without a message bus**: Agents must not call each other's internals directly.

---

## Exceptions Register

Document any approved violations of the above rules here. Each exception requires a rationale and an expiry plan.

```
# Format:
# Exception: <description>
# Approved: <date>
# Rationale: <why>
# Expiry: <what needs to happen for this to be resolved>
```

---

## Graph Health Baselines

Initial baselines (update as the project grows):

```yaml
max_circular_deps: 0
max_dead_code_nodes: 5         # some stubs acceptable during early build
max_module_in_degree: 8
max_dep_chain_depth: 5
max_edge_growth_per_week: 0.10  # 10% week-over-week
```

---

## How to Update This Skill

Guardrails evolve with the project. Update this file when:
- A new domain layer is introduced
- A new protected interface is established
- A threshold is deliberately relaxed with rationale
- A prohibited pattern is added based on a real violation caught in review

Always record the date and rationale for any change to this file. Guardrails weakened without explanation are not guardrails.

---

## Enforcement Points

| Phase | What guardrails enforces |
|---|---|
| Phase 2 — Arch Review | Domain layering, prohibited patterns, circular deps |
| Phase 4 — Quality Gates | New edge validation, coupling thresholds |
| Phase 6 — Code Review | Arch violation scan on diff |
| Phase 7 — Refactoring | Protected interface checks, prioritization scoring |
| Phase 8 — Health Cron | All thresholds, drift detection |
