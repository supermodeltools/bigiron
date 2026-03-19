# AGENTS.md — Big Iron

This file provides operating instructions for AI agents working in this repository.

## What This Project Is

Big Iron is an AI-native SDLC system built on two tools:
- **Hermes Agent** — self-improving CLI agent with MCP support and a skills system
- **Supermodel** — Code Graph API (call, dependency, domain, AST graphs) exposed as an MCP server

The graph is the backbone of every phase of the development lifecycle. Agents working here are expected to query the graph before reading files, before writing code, and before advancing any phase of work.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full system design.

---

## Core Operating Rules

### 1. Graph Before Files
Before reading source files for context, query the Supermodel graph first.
- Use `POST /v1/graphs/call  (search nodes)` to locate a symbol
- Use `POST /v1/graphs/call` to understand callers/callees
- Use `POST /v1/graphs/dependency` to understand module relationships
- Only load file content when graph data is insufficient

This is the primary token-saving mechanism. Do not skip it.

### 2. Check Blast Radius Before Every Change
Before modifying any function or module, call `POST /v1/analysis/impact?targets=file:fn`.
The result tells you which callers and dependents are affected. Include this in your plan.

### 3. Validate Architecture Before Committing Code
After writing code but before finalizing, call `POST /v1/analysis/circular-dependencies + dead-code` to compute
the structural delta. New edges must be consistent with the domain graph layering.
If a violation is detected, fix the code — do not skip the check.

### 4. Use Skills for Phase Knowledge
Each SDLC phase has a corresponding skill file in `~/.hermes/skills/`. Load the relevant
skill before starting a phase. If a skill is missing, create it after completing the phase.
Skills encode project-specific patterns; they are more valuable than generic reasoning.

### 5. Advance Phases in Order
Big Iron defines 8 SDLC phases. Do not skip phases or advance without passing the
graph-based gate for each:

| Phase | Gate |
|---|---|
| 1. Planning | Blast radius and domain ownership computed |
| 2. Arch Review | No circular deps or domain violations |
| 3. Code Generation | Signatures match graph; no duplicate imports |
| 4. Quality Gates | Graph diff is clean; no dead code introduced |
| 5. Testing | Tests cover full blast radius in topological order |
| 6. Code Review | Graph annotations generated for the diff |
| 7. Refactoring | Sequence derived from dependency graph |
| 8. Health (Cron) | Nightly — no human trigger required |

### 6. Prefer Graph Queries Over File Scans
| Do not... | Instead... |
|---|---|
| `grep` or `glob` to find callers | `POST /v1/graphs/call` |
| Read files to understand imports | `POST /v1/graphs/dependency` |
| Guess function signatures | `POST /v1/graphs/call  (search nodes)` |
| Scan for dead code | `POST /v1/analysis/dead-code` |

---

## Guardrails

The `guardrails` skill defines architectural constraints for this project. Always load it
when making structural changes. If no guardrails skill exists yet, create one as part of
the first architecture review phase.

Violations block advancement. Fix the code, not the guardrails.

---

## Skill Improvement

After completing any non-trivial task, evaluate whether the relevant phase skill should be
updated. Use `skill_manage patch` to add:
- New patterns discovered
- Failure modes encountered
- Project-specific conventions confirmed

The factory improves by accumulating this knowledge. Treat skill updates as part of the
definition of done.

---

## Token Budget Discipline

Graph queries are cheap. File loads are expensive. When in doubt, query first.

The graph provides: signatures, call relationships, dependency edges, domain ownership,
dead code detection, and blast radius — all without loading a single file.

Reserve file reads for: writing code, reading implementation details, and debugging
specific logic that the graph cannot surface.
