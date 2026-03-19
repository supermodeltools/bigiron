# Big Iron — Architecture

## Overview

Big Iron is an AI-native software development system that integrates two core tools:

- **[Hermes Agent](https://github.com/NousResearch/hermes-agent)** — a self-improving, MCP-capable CLI agent with persistent memory, a skills system, and a built-in learning loop
- **[Supermodel](https://supermodeltools.com)** — a Code Graph API and MCP server that maintains a persistent, multi-layered structural representation of a codebase

The central idea: use the **code graph as a first-class citizen at every phase of the SDLC** — not just for visualization, but as live context fed into the agent during planning, generation, review, testing, and refactoring. This keeps the agent architecturally aligned, reduces hallucination, saves tokens, and enables autonomous quality gates.

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          BIG IRON                                │
│                                                                  │
│  ┌─────────────────┐        ┌──────────────────────────────────┐ │
│  │   Hermes Agent  │◄──MCP──│       Supermodel Graph API       │ │
│  │                 │        │                                  │ │
│  │  - ReAct loop   │        │  Layers:                         │ │
│  │  - 40+ tools    │        │  ├─ Call Graph                   │ │
│  │  - Skills sys.  │        │  ├─ Dependency Graph             │ │
│  │  - Session mem. │        │  ├─ Domain Graph                 │ │
│  │  - Cron sched.  │        │  └─ AST / Parse Graph            │ │
│  │  - MCP client   │        │                                  │ │
│  └────────┬────────┘        └──────────────────────────────────┘ │
│           │                                                      │
│  ┌────────▼──────────────────────────────────────────────────┐   │
│  │                    SDLC PHASE SKILLS                      │   │
│  │                                                           │   │
│  │  planning.md  │  arch_check.md  │  codegen.md            │   │
│  │  quality.md   │  test_order.md  │  review.md             │   │
│  │  refactor.md  │  health_cron.md │  guardrails.md         │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ Session Mem. │  │  Cron Jobs   │  │   LLM Backend        │   │
│  │ (SQLite/FTS) │  │  (nightly    │  │   (Nous Portal /     │   │
│  │              │  │   health chk)│  │    OpenRouter / etc.) │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Hermes Agent

The agent runtime. Handles all orchestration, tool invocation, memory, and skill management.

| Capability | Detail |
|---|---|
| Agent loop | Synchronous ReAct loop with retry and fallback |
| Tool count | 40+ built-in tools across 8 categories |
| MCP support | Stdio and HTTP transports; auto-discovery at startup |
| Skills | Markdown-based knowledge docs in `~/.hermes/skills/` |
| Memory | SQLite + FTS5 full-text search across sessions |
| Cron | Built-in scheduler for autonomous background tasks |
| LLM backends | Nous Portal, OpenRouter, OpenAI-compatible, Anthropic |
| Platforms | CLI, Telegram, Discord, Slack, WhatsApp, Signal |
| Deployment | Local, Docker, SSH, Daytona, Singularity, Modal |

**Skills are the primary mechanism for encoding SDLC phase knowledge.** Each phase of the factory has a corresponding skill file. As the agent operates, it improves these skills with real project data using its autonomous self-improvement loop.

### 2. Supermodel Code Graph API

The structural intelligence layer. Provides a persistent, queryable representation of the codebase.

| Graph Layer | What it encodes |
|---|---|
| Call Graph | Function-to-function invocation relationships |
| Dependency Graph | Module and import dependencies |
| Domain Graph | Semantic domain/subdomain classifications |
| Parse Graph | AST structure and parse tree metadata |

**Key properties:**
- Incremental updates — only re-processes changed files on each write
- Git-aware — diffs and commit history linked to code symbols
- Multi-language — TypeScript, Python, Go, Rust, Java, Ruby, C++, Kotlin, Swift, and more
- Exposed as an MCP server — natively consumable by Hermes with zero custom integration code

### 3. SDLC Phase Skills

The factory's institutional knowledge, stored as Hermes skill files. Each phase has a skill that instructs the agent how to use the graph API at that stage. Skills improve autonomously as the agent gains experience with the codebase.

---

## SDLC Integration Map

### Phase 1: Planning & Scoping

**Graph queries used:**
- Domain graph → identify which subdomain owns affected code
- Dependency graph → compute blast radius of proposed changes upfront
- Call graph → list all callers of functions that will be modified

**Output:** Graph-grounded implementation checklist with scope and impact pre-computed. No surprises at review time.

**Token strategy:** Load domain graph summary only; fetch subgraph details on demand.

---

### Phase 2: Architecture Review (Pre-Code)

**Graph queries used:**
- Domain graph → check proposed design against existing layering
- Dependency graph → detect circular dependencies before code is written
- Call graph → verify no prohibited cross-domain call patterns are introduced

**Output:** Architectural violation report or green light. Blocked by guardrail skill if violations detected.

**Token strategy:** Graph edge queries are O(1); no file loading required.

---

### Phase 3: Code Generation

**Graph queries used:**
- Call graph → understand who calls what before writing new functions
- Parse graph → fetch exact function signatures to avoid hallucinated APIs
- Dependency graph → know what's already in scope; don't reinvent

**Output:** Graph-aware code that matches existing call conventions and import structure exactly.

**Token strategy:** Load only relevant subgraph nodes + signatures, not entire files.

---

### Phase 4: Quality Gates

**Graph queries used:**
- Incremental graph diff after each file write
- Dead code detection (nodes with in-degree = 0)
- New edge validation against architectural rules

**Output:** Pass/fail gate. New graph edges must be architecturally valid before the phase advances.

**Token strategy:** Diff only changed subgraph; full graph never loaded.

---

### Phase 5: Dependency-Ordered Testing

**Graph queries used:**
- Call graph → topological sort for test execution order (leaves first)
- Blast radius query → identify all functions in the call subtree of changed code

**Output:** Targeted test run covering exactly the impacted surface area, in dependency order.

**Token strategy:** Test list derived from graph query; no codebase scan required.

---

### Phase 6: Code Review

**Graph queries used:**
- Call graph → annotate diff with caller count and cross-domain impact
- Dependency graph → flag new dependencies introduced
- Domain graph → detect domain boundary violations in the diff

**Output:** Enriched review summary with graph-level impact, not just line-level changes.

**Token strategy:** Graph annotations are additive to the diff; no extra file reads.

---

### Phase 7: Refactoring & Debt Reduction

**Graph queries used:**
- Betweenness centrality → identify highest-risk refactor targets
- Dependency graph → sequence multi-file refactors safely (leaves first)
- Dead code query → surface unreachable functions for removal

**Output:** Sequenced refactor plan. Hermes captures successful refactor patterns as updated skill files.

**Token strategy:** Graph-derived sequence eliminates need to reason about ordering from scratch.

---

### Phase 8: Continuous Background Health (Cron)

**Schedule:** Nightly

**Graph queries used:**
- Full graph snapshot vs. previous snapshot → architectural drift detection
- Coupling metrics → flag modules becoming too tightly coupled
- Circular dependency scan

**Output:** Health report. Anomalies trigger scheduled refactor tasks. Clean runs update the "golden graph" stored in the health skill.

**Token strategy:** Hermes checks graph summaries first; detailed subgraphs only loaded when anomalies detected.

---

## Token Economy

A primary design goal is minimizing token usage while maximizing architectural intelligence. The graph API enables this by replacing large context loads with precise queries.

| Naive Approach | Graph-Powered Approach | Savings |
|---|---|---|
| Load entire file for context | Fetch relevant subgraph nodes + signatures | ~90% |
| Scan codebase to understand dependencies | Query call graph edge list | ~99% |
| Read files to discover function signatures | Fetch exact signatures from parse graph | ~95% |
| Full codebase scan for dead code | Query nodes with in-degree = 0 | ~99% |
| Re-discover architecture each session | Load domain graph summary from skill | ~85% |
| Reason about test order from code | Topological sort on call graph | ~95% |

---

## Key Design Principles

### Graph-as-Navigation
The agent never loads a full codebase into context. Instead, it navigates the graph the way a senior developer navigates a large codebase mentally — querying what it needs, when it needs it.

### Phase Gates
No work advances to the next SDLC phase without passing a graph-based check. These are structural proofs of architectural consistency, not just linting rules.

### Self-Improving Skills
Each SDLC phase skill improves with real project data. After the first 10 features, the planning skill knows this codebase's patterns. After 50, it knows its failure modes.

### Autonomous Architect
The nightly cron job acts as an autonomous architect — watching graph metrics over time and scheduling refactoring work when structural entropy exceeds thresholds. No human needs to ask.

### Guardrail Mesh
Architectural rules are encoded as graph constraints in the `guardrails` skill. Every agent action that produces code is validated against the graph before the result is accepted.

---

## MCP Configuration

Supermodel is wired into Hermes via `config/hermes-config.yaml` (installed to `~/.hermes/config.yaml` by `scripts/setup.sh`):

```yaml
mcp_servers:
  supermodel:
    command: "supermodel-mcp"
    args: []
    timeout: 15000
    tools:
      include:
        - get_call_graph
        - get_dependency_graph
        - get_domain_graph
        - get_parse_graph
        - query_symbol
        - get_blast_radius
        - detect_dead_code
        - get_graph_diff
    enabled: true
```

Tools are available to the agent as `Supermodel API` prefixed names.

---

## Skill File Inventory

| Skill File | Phase | Purpose |
|---|---|---|
| `planning.md` | Phase 1 | Graph-grounded scoping and impact analysis |
| `arch_check.md` | Phase 2 | Pre-code architectural validation |
| `codegen.md` | Phase 3 | Graph-aware code generation patterns |
| `quality_gates.md` | Phase 4 | Graph diff validation rules |
| `test_order.md` | Phase 5 | Dependency-ordered test execution |
| `code_review.md` | Phase 6 | Graph-enriched review annotation |
| `refactor.md` | Phase 7 | Graph-guided refactoring sequences |
| `health_cron.md` | Phase 8 | Nightly health check procedures |
| `guardrails.md` | All phases | Architectural constraint definitions |

---

## References

- [Hermes Agent GitHub](https://github.com/NousResearch/hermes-agent)
- [Hermes Agent Docs](https://hermes-agent.nousresearch.com/docs)
- [Supermodel](https://supermodeltools.com)
- [Model Context Protocol](https://modelcontextprotocol.io)
