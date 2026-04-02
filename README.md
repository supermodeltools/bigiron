> **⚠️ Deprecated:** Big Iron was an experimental prototype and is no longer maintained. This functionality has been rebuilt and shipped as [`supermodel factory`](https://github.com/supermodeltools/cli) in the [supermodel CLI](https://github.com/supermodeltools/cli). Please use that instead.

---

```
        _________
       /  _____  \
      /___________\        ____  ___ ____   ___ ____  ___  _  _
      |  (o)  (o) |       | __ )| |/ ___|  |_ _|  _ \/ _ \| \| |
      |     ^     |       |  _ \| | |  _    | || |_) |   /| .` |
      |   [---]   |       | |_) | | |_| |   | ||  _ <| |\ \| |\  |
      |___________|       |____/|_|\____|  |___|_| \_\_| \_|_| \_|
      /|         |\
     (_)         (_)      AI-Native SDLC — Ride the graph. Ship clean iron.
```

An AI-native software development system that integrates **[Hermes Agent](https://github.com/NousResearch/hermes-agent)** with the **[Supermodel Code Graph API](https://supermodeltools.com)** to make structural code intelligence a first-class citizen at every phase of the SDLC.

The graph replaces file loading for context. The agent stays architecturally aligned across sessions. Phase gates enforce quality without human gatekeeping. The system improves itself with every completed task.

---

## Quick Start

```bash
# 1. Set required env vars
export SUPERMODEL_API_KEY=your_key_here
export GITHUB_TOKEN=your_token_here   # optional — for PR automation

# 2. Run setup (installs Supermodel MCP, Hermes config, and all skills)
./scripts/setup.sh

# 3. Launch Hermes
hermes

# 4. In Hermes, reload MCP connections
/reload-mcp

# 5. Point the factory at a goal
factory run ./my-project "Add rate limiting to the order API"
```

---

## The `factory` CLI

The top-level entry point. Three modes:

```bash
# Run the full 8-phase SDLC cycle autonomously on a goal
factory run <codebase> "<goal>"

# Read-only health check — structural metrics and risk report
factory health <codebase>

# Continuous improvement pass — health + refactor + dead code sweep
factory improve <codebase>
```

Examples:

```bash
factory run ./demo "Add discount system to orders"
factory health ./demo
factory improve ./demo
```

Hermes is launched with all relevant skills pre-loaded and runs autonomously through the phases, using the graph at each step.

---

## Demo

A complete layered Python app is included in `demo/` as a factory target. Run the full 8-phase cycle on it:

```bash
./scripts/demo_run.sh ./demo "Add rate limiting to the order API"
```

Or just run the demo tests standalone:

```bash
cd demo && python3 -m pytest tests/ -v
```

The demo app has:
- **Domain layer** — `User`, `Order` entities and domain services
- **Infrastructure layer** — in-memory repositories
- **Application layer** — `UserService`, `OrderService` use cases
- **Orchestration layer** — `SDLCRunner`, the phase gate coordinator
- **36 tests** organized in dependency order

---

## How It Works

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full design. The short version:

**Supermodel** ships as an MCP server that Hermes consumes natively. It maintains a persistent multi-layered graph of the codebase — call graph, dependency graph, domain graph, AST. The agent queries this graph instead of loading files.

**Hermes** runs a skill at each SDLC phase. Each skill knows how to use the graph API for that specific phase: blast radius before planning, arch validation before coding, topological test ordering, graph-diff quality gates.

**The result:** the agent always knows what's connected to what, never hallucinates signatures, and can't accidentally violate the architecture without it being caught at a gate.

---

## The 8 Phases

| Phase | Skill | What it does |
|---|---|---|
| 1 | `planning` | Graph-grounded scoping: blast radius, domain ownership, implementation checklist |
| 2 | `arch_check` | Pre-code arch review: circular deps, domain layering, coupling thresholds |
| 3 | `codegen` | Graph-aware code generation: exact signatures, resolved imports, no duplicate impls |
| 4 | `quality_gates` | Post-write graph diff: validate new edges, dead code check, coupling delta |
| 5 | `test_order` | Dependency-ordered test run: topological sort, blast-radius scoping |
| 6 | `code_review` | Graph-enriched review: caller annotations, domain impact, risk levels |
| 7 | `refactor` | Graph-guided refactoring: leaf-first sequencing, debt scoring, pattern capture |
| 8 | `health_cron` | Nightly autonomous health check: drift detection, auto-scheduled remediation |

Phases run in order. No phase advances without passing its graph-based gate.

---

## CI Integration

`graph_gate.sh` wraps the Supermodel REST API for use in git hooks, GitHub Actions, or any CI pipeline:

```bash
# Architecture gate (pre-code)
./scripts/graph_gate.sh arch ./my-project

# Quality gate (post-write)
./scripts/graph_gate.sh quality ./my-project

# Test coverage gate
./scripts/graph_gate.sh coverage ./my-project

# Health gate (nightly)
./scripts/graph_gate.sh health ./my-project

# Blast radius for a specific function
./scripts/graph_gate.sh impact ./my-project app/service.py:create_order
```

Exit code `0` = PASS, `1` = FAIL. Drop into any CI step.

---

## File Layout

```
big-iron/
├── factory                 ← main entry point (run/health/improve)
├── README.md
├── CLAUDE.md               ← Claude Code configuration
├── AGENTS.md               ← Agent operating rules
├── docs/
│   └── ARCHITECTURE.md     ← full system design
├── skills/                 ← SDLC phase skill files (source of truth)
│   ├── guardrails.md       ← architectural constraints (all phases)
│   ├── planning.md
│   ├── arch_check.md
│   ├── codegen.md
│   ├── quality_gates.md
│   ├── test_order.md
│   ├── code_review.md
│   ├── refactor.md
│   └── health_cron.md
├── config/
│   └── hermes-config.yaml  ← Hermes + Supermodel MCP config
├── scripts/
│   ├── setup.sh            ← first-time setup
│   ├── install_skills.sh   ← sync skills to ~/.hermes/skills/
│   ├── graph_gate.sh       ← shell phase gate (CI-ready)
│   ├── supermodel.sh       ← Supermodel API client library
│   └── demo_run.sh         ← interactive 8-phase demo runner
└── demo/                   ← target codebase for demos
    ├── pyproject.toml
    ├── app/
    │   ├── domain/         ← Layer 2: User, Order entities
    │   ├── infrastructure/ ← Layer 3: in-memory repositories
    │   ├── application/    ← Layer 1: UserService, OrderService
    │   └── orchestration/  ← Layer 0: SDLCRunner
    └── tests/
```

---

## Prerequisites

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) — `pip install hermes-agent`
- [Node.js](https://nodejs.org) ≥ 18 (for Supermodel MCP server)
- [Supermodel API key](https://supermodeltools.com) — free 14-day trial
- Python ≥ 3.11 (for demo codebase)

---

## References

- [Architecture](docs/ARCHITECTURE.md)
- [Agent Rules](AGENTS.md)
- [Hermes Agent Docs](https://hermes-agent.nousresearch.com/docs)
- [Supermodel](https://supermodeltools.com)
- [Model Context Protocol](https://modelcontextprotocol.io)
