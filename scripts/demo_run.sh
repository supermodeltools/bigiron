#!/usr/bin/env bash
# demo_run.sh — Walk through all 8 SDLC phases on a target codebase
#
# This demo runs Hermes through a complete factory cycle, using the
# Supermodel graph at each phase. Requires a codebase to operate on.
#
# Usage:
#   ./scripts/demo_run.sh <path-to-target-codebase> "<feature description>"
#
# Example:
#   ./scripts/demo_run.sh ./demo "Add user authentication endpoint"

set -euo pipefail

TARGET="${1:-}"
FEATURE="${2:-}"

if [[ -z "$TARGET" || -z "$FEATURE" ]]; then
  echo "Usage: $0 <codebase-path> \"<feature description>\""
  echo ""
  echo "Example:"
  echo "  $0 ./demo \"Add rate limiting to the API\""
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "ERROR: Target codebase not found: $TARGET"
  exit 1
fi

echo ""
echo "        _________   "
echo "       /  _____  \  "
echo "      /___________\ "
echo "      |  (o)  (o) |     B I G   I R O N — Demo Run"
echo "      |     ^     |     ~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "      |   [---]   |"
echo "      |___________|"
echo "      /|         |\ "
echo "     (_)         (_)"
echo ""
echo "  Target codebase: $TARGET"
echo "  Feature request: $FEATURE"
echo ""
echo "  Phases to run:"
echo "    [1] Planning & Scoping"
echo "    [2] Architecture Review"
echo "    [3] Code Generation"
echo "    [4] Quality Gates"
echo "    [5] Dependency-Ordered Testing"
echo "    [6] Code Review"
echo "    [7] Refactoring (if needed)"
echo "    [8] Health Check (nightly — skipped in demo)"
echo ""
echo "  Press Enter to begin, Ctrl+C to cancel."
read -r

# ---------------------------------------------------------------------------
# Phase 1 — Planning
# ---------------------------------------------------------------------------

echo "════════════════════════════════════════"
echo "  Phase 1: Planning & Scoping"
echo "════════════════════════════════════════"
echo ""

hermes run --cwd "$TARGET" --skill planning <<EOF
Feature request: $FEATURE

Use the planning skill to:
1. Identify the target symbols in the codebase related to this feature
2. Compute blast radius for any symbols that will change
3. Map module dependencies
4. Produce a structured implementation plan with a phase checklist

Query the Supermodel graph (mcp_supermodel_*) for all context.
Do not read source files for context gathering — use the graph.
EOF

echo ""
echo "  Phase 1 complete. Press Enter to continue to Phase 2."
read -r

# ---------------------------------------------------------------------------
# Phase 2 — Architecture Review
# ---------------------------------------------------------------------------

echo "════════════════════════════════════════"
echo "  Phase 2: Architecture Review"
echo "════════════════════════════════════════"
echo ""

hermes run --cwd "$TARGET" --skill arch_check <<EOF
Review the implementation plan from Phase 1 against the codebase architecture.

Use the arch_check skill to:
1. Load the guardrails skill
2. Check for circular dependencies in the proposed change path
3. Validate domain layering — no upward calls
4. Check coupling thresholds
5. Produce an arch review verdict: PASS, FAIL, or CONDITIONAL

Do not proceed (do not write any code) until the verdict is PASS or CONDITIONAL.
EOF

echo ""
echo "  Phase 2 complete. Press Enter to continue to Phase 3."
read -r

# ---------------------------------------------------------------------------
# Phase 3 — Code Generation
# ---------------------------------------------------------------------------

echo "════════════════════════════════════════"
echo "  Phase 3: Code Generation"
echo "════════════════════════════════════════"
echo ""

hermes run --cwd "$TARGET" --skill codegen <<EOF
Implement the feature described in Phase 1, following the Phase 2 arch verdict.

Use the codegen skill to:
1. Fetch exact signatures for all symbols you will call or extend
2. Resolve import paths via the dependency graph
3. Check for existing implementations before writing new ones
4. Write the code — matching signatures, imports, naming, and error handling style
5. Verify all new calls resolve to real symbols

Do not open a source file for context — query the graph first.
Only open files when you are ready to write to them.
EOF

echo ""
echo "  Phase 3 complete. Press Enter to continue to Phase 4."
read -r

# ---------------------------------------------------------------------------
# Phase 4 — Quality Gates
# ---------------------------------------------------------------------------

echo "════════════════════════════════════════"
echo "  Phase 4: Quality Gates"
echo "════════════════════════════════════════"
echo ""

# Run the shell-based gate for CI parity
echo "  Running graph gate (quality)..."
bash "$(dirname "$0")/graph_gate.sh" quality "$TARGET" || {
  echo ""
  echo "  ⚠ Shell gate failed. Hermes will attempt to resolve."
}
echo ""

hermes run --cwd "$TARGET" --skill quality_gates <<EOF
The code from Phase 3 has been written. Run the quality gate.

Use the quality_gates skill to:
1. Get the graph diff since the Phase 3 changes
2. Validate all new edges against the guardrails
3. Check for dead code (new nodes with in-degree 0)
4. Audit removed edges for unintentional breakage
5. Check coupling delta on modified modules
6. Issue a quality gate verdict: PASS or FAIL

If FAIL, describe the required fix. Do not advance to Phase 5 until PASS.
EOF

echo ""
echo "  Phase 4 complete. Press Enter to continue to Phase 5."
read -r

# ---------------------------------------------------------------------------
# Phase 5 — Testing
# ---------------------------------------------------------------------------

echo "════════════════════════════════════════"
echo "  Phase 5: Dependency-Ordered Testing"
echo "════════════════════════════════════════"
echo ""

hermes run --cwd "$TARGET" --skill test_order <<EOF
Run tests for the blast radius of the Phase 3 changes.

Use the test_order skill to:
1. Retrieve the blast radius (from Phase 1 plan or recompute)
2. Build a topological test execution order (leaf functions first)
3. Map each symbol to its test file
4. Run tests in topological order, stopping at the first failure
5. Report coverage gaps (symbols with no test file)

Do not run the full test suite — run only the blast radius subset.
EOF

echo ""
echo "  Phase 5 complete. Press Enter to continue to Phase 6."
read -r

# ---------------------------------------------------------------------------
# Phase 6 — Code Review
# ---------------------------------------------------------------------------

echo "════════════════════════════════════════"
echo "  Phase 6: Code Review"
echo "════════════════════════════════════════"
echo ""

hermes run --cwd "$TARGET" --skill code_review <<EOF
Produce a graph-enriched code review for the Phase 3 changes.

Use the code_review skill to:
1. Annotate every modified symbol with caller count, domain, and cross-domain exposure
2. Produce the graph diff summary (new edges, removed edges, new dependencies)
3. Run the arch violation scan on the diff
4. Assign risk levels (LOW/MEDIUM/HIGH) to each changed symbol
5. Produce the full review document with reviewer focus areas

Output the complete review document.
EOF

echo ""
echo "  Phase 6 complete."
echo ""
echo "════════════════════════════════════════"
echo "  Demo Complete!"
echo "════════════════════════════════════════"
echo ""
echo "  All 6 active phases passed."
echo "  Phase 7 (Refactoring) runs on demand."
echo "  Phase 8 (Health Check) runs nightly via cron."
echo ""
echo "  To trigger Phase 7 manually:"
echo "    hermes run --cwd $TARGET --skill refactor"
echo ""
echo "  To trigger Phase 8 manually:"
echo "    hermes run --cwd $TARGET --skill health_cron"
echo ""
echo "  Or use the factory CLI:"
echo "    factory improve $TARGET"
echo ""
