# CLAUDE.md — Big Iron

This file configures Claude Code's behavior when working in this repository.

## Project Summary

Big Iron is an AI-native SDLC system. It uses:
- **Hermes Agent** for autonomous task execution, skills, memory, and orchestration
- **Supermodel** for persistent code graph intelligence (call, dependency, domain, AST graphs)

The code graph is integrated at every phase of the development lifecycle to ensure architectural alignment, reduce token usage, and enable autonomous quality gates.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full system design.
See [`AGENTS.md`](AGENTS.md) for agent operating rules (also applies to Claude when acting as an agent here).

---

## Working in This Repo

### Always Read Architecture First
Before making any structural decisions, read `docs/ARCHITECTURE.md`. All design decisions
should be consistent with the phase-gate model and graph-first principles described there.

### Follow the Phase Model
Work in this repo is organized around 8 SDLC phases. Each has a defined graph-based gate.
Do not implement features that skip phases or bypass gates. If a gate cannot be satisfied,
surface the blocker rather than working around it.

### Graph-First, Files-Second
When the Supermodel MCP server is available, prefer graph queries over file reads for
context gathering. See `AGENTS.md` for the full list of when to use which query.

---

## Code Style Preferences

- Keep implementations minimal — the factory itself is the product; avoid gold-plating
- Skill files are Markdown; keep them structured with clear headings and verification steps
- Config files use YAML; keep MCP server configs explicit and well-commented
- No unnecessary abstraction layers — the graph API and agent runtime are the platform

---

## File Layout

```
big-iron/
├── CLAUDE.md               ← this file
├── AGENTS.md               ← agent operating instructions
├── factory                 ← main CLI entry point
├── docs/
│   └── ARCHITECTURE.md     ← full system design
├── skills/                 ← SDLC phase skill files (source of truth before ~/.hermes/skills/)
│   ├── planning.md
│   ├── arch_check.md
│   ├── codegen.md
│   ├── quality_gates.md
│   ├── test_order.md
│   ├── code_review.md
│   ├── refactor.md
│   ├── health_cron.md
│   └── guardrails.md
├── config/
│   └── hermes-config.yaml  ← Hermes MCP and model configuration
└── scripts/                ← automation and CI scripts
```

---

## Key Constraints

- **No phase skipping.** Each SDLC phase gate must pass before advancing.
- **No file-first context gathering.** Query the graph first; read files only when necessary.
- **No guardrail bypasses.** If architectural constraints block progress, fix the design — don't weaken the guardrail.
- **Skill updates are part of done.** Any completed non-trivial task should produce a skill patch.

---

## References

- [Architecture](docs/ARCHITECTURE.md)
- [Agent Rules](AGENTS.md)
- [Hermes Agent Docs](https://hermes-agent.nousresearch.com/docs)
- [Supermodel](https://supermodeltools.com)
