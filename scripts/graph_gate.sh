#!/usr/bin/env bash
# graph_gate.sh — Big Iron phase gate checks via the Supermodel API
#
# Uploads a codebase ZIP to Supermodel, runs structural checks,
# and exits 0 (PASS) or 1 (FAIL). Drop into any CI pipeline.
#
# Auth: SUPERMODEL_API_KEY env var (smsk_live_* key)
#
# Usage:
#   ./scripts/graph_gate.sh <phase> <codebase-path> [options]
#
# Phases:
#   arch     <path>              Pre-code architectural validation
#   quality  <path>              Post-write quality check
#   health   <path>              Full codebase health report
#   coverage <path>              Test coverage gate
#   impact   <path> <file:fn>   Blast radius for a specific function
#
# Examples:
#   ./scripts/graph_gate.sh arch    ./demo
#   ./scripts/graph_gate.sh health  ./demo
#   ./scripts/graph_gate.sh impact  ./demo app/application/order_service.py:create_order

set -uo pipefail   # note: no -e, we handle failures explicitly

API_BASE="https://api.supermodeltools.com"
COVERAGE_THRESHOLD=80
POLL_MAX=120       # 120 × 10s = 20 minutes max
POLL_INTERVAL=10   # poll every 10s

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
GATE_FAILED=false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

require_key() {
  if [[ -z "${SUPERMODEL_API_KEY:-}" ]]; then
    echo -e "${RED}ERROR: SUPERMODEL_API_KEY not set.${NC}" >&2
    exit 1
  fi
}

make_zip() {
  local src="$1"
  if [[ "$src" == *.zip ]]; then
    echo "$src"
    return 0
  fi
  local tmp
  tmp=$(python3 -c "import tempfile,os; f=tempfile.mkstemp(suffix='.zip',prefix='sm-gate-'); os.close(f[0]); os.unlink(f[1]); print(f[1])")
  (
    cd "$src"
    zip -rq "$tmp" . \
      --exclude "*.pyc" \
      --exclude "*/__pycache__/*" \
      --exclude "*/.git/*" \
      --exclude "*/node_modules/*" \
      --exclude "*/dist/*" \
      --exclude "*/build/*" \
      --exclude "*/.venv/*" \
      --exclude "*/venv/*" \
      2>/dev/null
  )
  echo "$tmp"
}

submit_and_poll() {
  local endpoint="$1"
  local zip="$2"
  local extra_query="${3:-}"
  local idem url resp status

  idem=$(python3 -c "import uuid; print(uuid.uuid4())")
  url="${API_BASE}${endpoint}"
  if [[ -n "$extra_query" ]]; then
    url="${url}?${extra_query}"
  fi

  resp=$(curl -sf --max-time 60 \
    -X POST "$url" \
    -H "X-Api-Key: $SUPERMODEL_API_KEY" \
    -H "Idempotency-Key: $idem" \
    -F "file=@$zip" 2>/dev/null) || { echo "curl failed" >&2; return 1; }

  status=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null || echo "?")

  local i=0
  while [[ $i -lt $POLL_MAX ]]; do
    if [[ "$status" == "completed" ]]; then
      echo "$resp"
      return 0
    fi
    if [[ "$status" == "failed" ]]; then
      echo "Job failed" >&2
      echo "$resp" >&2
      return 1
    fi
    i=$((i + 1))
    echo "  polling ${i}/${POLL_MAX} ($status)..." >&2
    sleep $POLL_INTERVAL
    resp=$(curl -sf --max-time 60 \
      -X POST "$url" \
      -H "X-Api-Key: $SUPERMODEL_API_KEY" \
      -H "Idempotency-Key: $idem" \
      -F "file=@$zip" 2>/dev/null) || { echo "curl failed on poll" >&2; return 1; }
    status=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null || echo "?")
  done

  echo "Timed out waiting for $endpoint" >&2
  return 1
}

pass() { echo -e "  ${GREEN}✓ PASS${NC}  $1"; }
fail() { echo -e "  ${RED}✗ FAIL${NC}  $1"; GATE_FAILED=true; }
warn() { echo -e "  ${YELLOW}⚠ WARN${NC}  $1"; }
info() { echo -e "       $1"; }

# ---------------------------------------------------------------------------
# Phase: arch
# ---------------------------------------------------------------------------

run_arch() {
  local zip="$1"

  echo -e "${BOLD}→ Circular dependency scan${NC}"
  local circ cycle_count
  circ=$(submit_and_poll "/v1/analysis/circular-dependencies" "$zip")
  cycle_count=$(echo "$circ" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['metadata']['cycleCount'])" 2>/dev/null || echo "0")
  if [[ "$cycle_count" -eq 0 ]]; then
    pass "No circular dependencies"
  else
    fail "Circular dependencies: $cycle_count cycle(s)"
    echo "$circ" | python3 -c "
import sys,json
for c in json.load(sys.stdin)['result'].get('cycles',[]):
    print(f'    [{c[\"severity\"]}] {\" -> \".join(c[\"files\"])}')
" 2>/dev/null || true
  fi

  echo ""
  echo -e "${BOLD}→ Domain graph${NC}"
  local domain domain_count
  domain=$(submit_and_poll "/v1/graphs/domain" "$zip")
  domain_count=$(echo "$domain" | python3 -c "
import sys,json
r=json.load(sys.stdin)['result']
print(len([n for n in r['graph']['nodes'] if 'Domain' in n.get('labels',[])]))" 2>/dev/null || echo "0")
  info "Domains identified: $domain_count"
  echo "$domain" | python3 -c "
import sys,json
r=json.load(sys.stdin)['result']
for n in r['graph']['nodes']:
    if 'Domain' in n.get('labels',[]):
        print(f'    Domain: {n[\"properties\"].get(\"name\",\"?\")}')
" 2>/dev/null || true
  if [[ "$domain_count" -gt 0 ]]; then
    pass "Domain graph: $domain_count domain(s)"
  else
    warn "No domains identified"
  fi
}

# ---------------------------------------------------------------------------
# Phase: quality
# ---------------------------------------------------------------------------

run_quality() {
  local zip="$1"

  echo -e "${BOLD}→ Dead code analysis${NC}"
  local dead dead_count total_decls
  dead=$(submit_and_poll "/v1/analysis/dead-code" "$zip")
  dead_count=$(echo "$dead" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['metadata']['deadCodeCandidates'])" 2>/dev/null || echo "0")
  total_decls=$(echo "$dead" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['metadata']['totalDeclarations'])" 2>/dev/null || echo "?")
  info "Total declarations: $total_decls"
  if [[ "$dead_count" -eq 0 ]]; then
    pass "No dead code"
  elif [[ "$dead_count" -le 5 ]]; then
    warn "$dead_count dead code candidate(s)"
    echo "$dead" | python3 -c "
import sys,json
for c in json.load(sys.stdin)['result'].get('deadCodeCandidates',[]):
    print(f'    [{c[\"confidence\"]}] {c[\"file\"]}:{c[\"name\"]} - {c[\"reason\"]}')
" 2>/dev/null || true
  else
    fail "$dead_count dead code candidates"
    echo "$dead" | python3 -c "
import sys,json
for c in json.load(sys.stdin)['result'].get('deadCodeCandidates',[])[:10]:
    print(f'    [{c[\"confidence\"]}] {c[\"file\"]}:{c[\"name\"]} - {c[\"reason\"]}')
" 2>/dev/null || true
  fi

  echo ""
  echo -e "${BOLD}→ Circular dependency check${NC}"
  local circ cycle_count
  circ=$(submit_and_poll "/v1/analysis/circular-dependencies" "$zip")
  cycle_count=$(echo "$circ" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['metadata']['cycleCount'])" 2>/dev/null || echo "0")
  if [[ "$cycle_count" -eq 0 ]]; then
    pass "No circular dependencies"
  else
    fail "$cycle_count circular dependency cycle(s)"
    echo "$circ" | python3 -c "
import sys,json
for c in json.load(sys.stdin)['result'].get('cycles',[]):
    print(f'    [{c[\"severity\"]}] {\" -> \".join(c[\"files\"])}')
" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Phase: coverage
# ---------------------------------------------------------------------------

run_coverage() {
  local zip="$1"
  echo -e "${BOLD}→ Test coverage analysis${NC}"
  local cov pct total_fns tested_fns untested_count pct_int
  cov=$(submit_and_poll "/v1/analysis/test-coverage-map" "$zip")
  pct=$(echo "$cov" | python3 -c "import sys,json; print(f'{json.load(sys.stdin)[\"result\"][\"metadata\"][\"coveragePercentage\"]:.1f}')" 2>/dev/null || echo "0.0")
  total_fns=$(echo "$cov" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['metadata']['totalFunctions'])" 2>/dev/null || echo "?")
  tested_fns=$(echo "$cov" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['metadata']['testedFunctions'])" 2>/dev/null || echo "?")
  untested_count=$(echo "$cov" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['metadata']['untestedFunctions'])" 2>/dev/null || echo "0")
  pct_int=${pct%.*}
  info "Functions: $tested_fns/$total_fns covered (${pct}%)"
  if [[ "$pct_int" -ge "$COVERAGE_THRESHOLD" ]]; then
    pass "Coverage ${pct}% ≥ threshold ${COVERAGE_THRESHOLD}%"
  else
    fail "Coverage ${pct}% below threshold ${COVERAGE_THRESHOLD}%"
  fi
  if [[ "$untested_count" -gt 0 ]]; then
    warn "$untested_count untested function(s):"
    echo "$cov" | python3 -c "
import sys,json
for f in json.load(sys.stdin)['result'].get('untestedFunctions',[]):
    print(f'    {f[\"file\"]}:{f[\"name\"]}')
" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Phase: health
# ---------------------------------------------------------------------------

run_health() {
  local zip="$1"

  echo -e "${BOLD}→ Dead code sweep${NC}"
  local dead dead_count
  dead=$(submit_and_poll "/v1/analysis/dead-code" "$zip")
  dead_count=$(echo "$dead" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['metadata']['deadCodeCandidates'])" 2>/dev/null || echo "0")
  if [[ "$dead_count" -eq 0 ]]; then
    pass "No dead code"
  else
    warn "$dead_count dead code candidate(s)"
  fi

  echo ""
  echo -e "${BOLD}→ Circular dependencies${NC}"
  local circ cycle_count
  circ=$(submit_and_poll "/v1/analysis/circular-dependencies" "$zip")
  cycle_count=$(echo "$circ" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['metadata']['cycleCount'])" 2>/dev/null || echo "0")
  if [[ "$cycle_count" -eq 0 ]]; then
    pass "No cycles"
  else
    fail "$cycle_count cycle(s) detected"
  fi

  echo ""
  echo -e "${BOLD}→ Test coverage${NC}"
  local cov pct pct_int
  cov=$(submit_and_poll "/v1/analysis/test-coverage-map" "$zip")
  pct=$(echo "$cov" | python3 -c "import sys,json; print(f'{json.load(sys.stdin)[\"result\"][\"metadata\"][\"coveragePercentage\"]:.1f}')" 2>/dev/null || echo "0.0")
  pct_int=${pct%.*}
  info "Coverage: ${pct}%"
  if [[ "$pct_int" -ge "$COVERAGE_THRESHOLD" ]]; then
    pass "Coverage healthy (${pct}%)"
  else
    warn "Coverage ${pct}% below threshold ${COVERAGE_THRESHOLD}%"
  fi

  echo ""
  echo -e "${BOLD}→ Domain graph${NC}"
  local domain domain_count
  domain=$(submit_and_poll "/v1/graphs/domain" "$zip")
  domain_count=$(echo "$domain" | python3 -c "
import sys,json
r=json.load(sys.stdin)['result']
print(len([n for n in r['graph']['nodes'] if 'Domain' in n.get('labels',[])]))" 2>/dev/null || echo "0")
  pass "$domain_count domain(s) identified"
  echo "$domain" | python3 -c "
import sys,json
r=json.load(sys.stdin)['result']
for n in r['graph']['nodes']:
    if 'Domain' in n.get('labels',[]):
        print(f'    {n[\"properties\"].get(\"name\",\"?\")}')
" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Phase: impact
# ---------------------------------------------------------------------------

run_impact() {
  local zip="$1" target="$2"
  local encoded_target result

  encoded_target=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$target")
  echo -e "${BOLD}→ Impact analysis: ${target}${NC}"
  result=$(submit_and_poll "/v1/analysis/impact" "$zip" "targets=${encoded_target}")

  echo "$result" | python3 -c "
import sys,json
r=json.load(sys.stdin)['result']
for imp in r.get('impacts',[]):
    t=imp['target']; b=imp['blastRadius']
    print(f'  Target:                {t[\"file\"]}:{t.get(\"name\",\"?\")}')
    print(f'  Direct dependents:     {b[\"directDependents\"]}')
    print(f'  Transitive dependents: {b[\"transitiveDependents\"]}')
    print(f'  Affected files:        {b[\"affectedFiles\"]}')
    print(f'  Risk score:            {b[\"riskScore\"]}')
    for rf in b.get('riskFactors',[]): print(f'  Risk factor:           {rf}')
" 2>/dev/null || true

  pass "Impact analysis complete"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

require_key

PHASE="${1:-}"
SRC="${2:-}"

if [[ -z "$PHASE" || -z "$SRC" ]]; then
  echo "Usage: $0 <arch|quality|coverage|health|impact> <path> [target]"
  exit 1
fi

if [[ ! -e "$SRC" ]]; then
  echo "ERROR: Path not found: $SRC" >&2
  exit 1
fi

echo ""
echo -e "${BOLD}================================================${NC}"
echo -e "${BOLD}  Big Iron Graph Gate — Phase: ${PHASE}${NC}"
echo -e "${BOLD}================================================${NC}"
echo ""

ZIP=$(make_zip "$SRC")
IS_TMP=false
if [[ "$ZIP" != "$SRC" ]]; then
  IS_TMP=true
fi

case "$PHASE" in
  arch)     run_arch "$ZIP" ;;
  quality)  run_quality "$ZIP" ;;
  coverage) run_coverage "$ZIP" ;;
  health)   run_health "$ZIP" ;;
  impact)
    TARGET="${3:-}"
    if [[ -z "$TARGET" ]]; then
      echo "Usage: $0 impact <path> <file:function>" >&2
      exit 1
    fi
    run_impact "$ZIP" "$TARGET"
    ;;
  *)
    echo "Unknown phase: $PHASE"
    exit 1
    ;;
esac

if [[ "$IS_TMP" == "true" ]]; then
  rm -f "$ZIP"
fi

echo ""
if [[ "$GATE_FAILED" == true ]]; then
  echo -e "${RED}${BOLD}GATE FAILED — do not advance to the next phase.${NC}"
  exit 1
else
  echo -e "${GREEN}${BOLD}GATE PASSED${NC}"
  exit 0
fi
