#!/usr/bin/env bash
# supermodel.sh — Supermodel API client for Big Iron
#
# Wraps the Supermodel API (https://api.supermodeltools.com).
# Handles ZIP packaging, async polling, and result extraction.
#
# Auth: X-Api-Key header with smsk_live_* key
# Required env: SUPERMODEL_API_KEY
#
# Usage:
#   source ./scripts/supermodel.sh   # use as a library
#   ./scripts/supermodel.sh <command> [args]
#
# Commands:
#   dependency <path>                      Dependency graph
#   call <path>                            Call graph
#   domain <path>                          Domain classification graph
#   dead-code <path>                       Dead code analysis
#   circular <path>                        Circular dependency detection
#   coverage <path>                        Test coverage map
#   impact <path> <file:function>          Blast radius analysis
#   full <path>                            Full Supermodel IR (all graphs)
#
# <path> can be a directory (auto-zipped) or a pre-made .zip file.
#
# Examples:
#   ./scripts/supermodel.sh dependency ./demo
#   ./scripts/supermodel.sh impact ./demo app/application/order_service.py:create_order
#   ./scripts/supermodel.sh full ./demo

set -euo pipefail

API_BASE="https://api.supermodeltools.com"
MAX_POLLS=120      # 120 × 10s = 20 minutes max
POLL_INTERVAL=10   # poll every 10s

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_require_key() {
  if [[ -z "${SUPERMODEL_API_KEY:-}" ]]; then
    echo "ERROR: SUPERMODEL_API_KEY is not set." >&2
    echo "  export SUPERMODEL_API_KEY=smsk_live_..." >&2
    exit 1
  fi
}

_make_zip() {
  local src="$1"
  if [[ "$src" == *.zip ]]; then
    echo "$src"
    return
  fi
  local tmp_zip
  tmp_zip=$(python3 -c "import tempfile,os; f=tempfile.mkstemp(suffix='.zip',prefix='supermodel-'); os.close(f[0]); os.unlink(f[1]); print(f[1])")
  (cd "$src" && zip -rq "$tmp_zip" . \
    --exclude "*.pyc" \
    --exclude "*/__pycache__/*" \
    --exclude "*/.git/*" \
    --exclude "*/node_modules/*" \
    --exclude "*/dist/*" \
    --exclude "*/build/*" \
    --exclude "*/.venv/*" \
    --exclude "*/venv/*"
  )
  echo "$tmp_zip"
}

_post() {
  local endpoint="$1"
  local zip_path="$2"
  local extra_query="${3:-}"

  local idem
  idem=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
  local url="${API_BASE}${endpoint}"
  [[ -n "$extra_query" ]] && url="${url}?${extra_query}"

  curl -sf --max-time 60 \
    -X POST "$url" \
    -H "X-Api-Key: $SUPERMODEL_API_KEY" \
    -H "Idempotency-Key: $idem" \
    -F "file=@$zip_path"
}

_poll() {
  local endpoint="$1"
  local zip_path="$2"
  local idem="$3"
  local extra_query="${4:-}"
  local label="${5:-request}"

  local url="${API_BASE}${endpoint}"
  [[ -n "$extra_query" ]] && url="${url}?${extra_query}"

  for i in $(seq 1 $MAX_POLLS); do
    sleep $POLL_INTERVAL
    local resp
    resp=$(curl -sf --max-time 60 \
      -X POST "$url" \
      -H "X-Api-Key: $SUPERMODEL_API_KEY" \
      -H "Idempotency-Key: $idem" \
      -F "file=@$zip_path")

    local status
    status=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)

    if [[ "$status" == "completed" ]]; then
      echo "$resp"
      return 0
    elif [[ "$status" == "failed" ]]; then
      echo "ERROR: Job failed" >&2
      echo "$resp" >&2
      return 1
    fi

    echo "  [${label}] poll ${i}/${MAX_POLLS}: ${status}..." >&2
  done

  echo "ERROR: Timed out waiting for ${label}" >&2
  return 1
}

# ---------------------------------------------------------------------------
# Main: submit + poll + print result
# ---------------------------------------------------------------------------

supermodel_run() {
  local endpoint="$1"
  local src="$2"
  local extra_query="${3:-}"
  local label="${4:-$(basename $endpoint)}"

  _require_key
  local zip_path
  zip_path=$(_make_zip "$src")
  local is_tmp=false
  [[ "$zip_path" != "$src" ]] && is_tmp=true

  echo "Submitting to ${endpoint}..." >&2

  local idem resp
  idem=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
  local url="${API_BASE}${endpoint}"
  [[ -n "$extra_query" ]] && url="${url}?${extra_query}"

  resp=$(curl -sf --max-time 60 \
    -X POST "$url" \
    -H "X-Api-Key: $SUPERMODEL_API_KEY" \
    -H "Idempotency-Key: $idem" \
    -F "file=@$zip_path")

  local status
  status=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)

  if [[ "$status" == "completed" ]]; then
    if [[ "$is_tmp" == "true" ]]; then rm -f "$zip_path"; fi
    echo "$resp"
    return 0
  fi

  echo "  Status: ${status}, polling..." >&2
  local result
  result=$(_poll "$endpoint" "$zip_path" "$idem" "$extra_query" "$label")
  if [[ "$is_tmp" == "true" ]]; then rm -f "$zip_path"; fi
  echo "$result"
}

# ---------------------------------------------------------------------------
# Convenience extractors
# ---------------------------------------------------------------------------

# Print a human-readable summary of any result
supermodel_summary() {
  python3 -c "
import sys, json
d = json.load(sys.stdin)
r = d.get('result', {})
if not r:
    print('No result yet:', d.get('status'))
    sys.exit(0)

stats = r.get('stats', {})
meta = r.get('metadata', {})

# Stats
if stats:
    print('STATS:')
    for k,v in stats.items():
        if v is not None:
            print(f'  {k}: {v}')

# Metadata
if meta:
    print('METADATA:')
    for k,v in meta.items():
        if v is not None:
            print(f'  {k}: {v}')

# Dead code candidates
for c in r.get('deadCodeCandidates', []):
    print(f'  DEAD [{c[\"confidence\"]}] {c[\"file\"]}:{c[\"name\"]} - {c[\"reason\"]}')

# Cycles
for c in r.get('cycles', []):
    print(f'  CYCLE [{c[\"severity\"]}] {\" -> \".join(c[\"files\"])}')

# Coverage
if 'coveragePercentage' in (r.get('metadata') or {}):
    pct = r['metadata']['coveragePercentage']
    total = r['metadata']['totalFunctions']
    tested = r['metadata']['testedFunctions']
    print(f'  Coverage: {pct:.1f}% ({tested}/{total} functions)')
    for f in r.get('untestedFunctions', []):
        print(f'  UNTESTED: {f[\"file\"]}:{f[\"name\"]}')

# Impact
for imp in r.get('impacts', []):
    t = imp['target']
    b = imp['blastRadius']
    print(f'  IMPACT {t[\"file\"]}:{t.get(\"name\",\"?\")}')
    print(f'    direct={b[\"directDependents\"]} transitive={b[\"transitiveDependents\"]} risk={b[\"riskScore\"]}')
    for rf in b.get('riskFactors', []):
        print(f'    factor: {rf}')

# Domain graph
for n in r.get('graph', {}).get('nodes', []):
    if 'Domain' in n.get('labels', []) or 'Subdomain' in n.get('labels', []):
        print(f'  {n[\"labels\"][0]}: {n[\"properties\"].get(\"name\",\"?\")}')
"
}

# Extract just the graph (nodes + relationships) as JSON
supermodel_graph() {
  python3 -c "
import sys, json
d = json.load(sys.stdin)
r = d.get('result', {})
g = r.get('graph', {})
print(json.dumps(g, indent=2))
"
}

# Extract result.result subtree
supermodel_result() {
  python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('result',{}), indent=2))"
}

# ---------------------------------------------------------------------------
# CLI dispatch
# ---------------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  CMD="${1:-}"
  SRC="${2:-}"

  [[ -z "$CMD" || -z "$SRC" ]] && {
    echo "Usage: $0 <command> <path> [target]"
    echo "Commands: dependency call domain dead-code circular coverage impact full"
    exit 1
  }

  case "$CMD" in
    dependency) supermodel_run "/v1/graphs/dependency" "$SRC" | tee /tmp/sm_last.json | supermodel_summary ;;
    call)       supermodel_run "/v1/graphs/call"       "$SRC" | tee /tmp/sm_last.json | supermodel_summary ;;
    domain)     supermodel_run "/v1/graphs/domain"     "$SRC" | tee /tmp/sm_last.json | supermodel_summary ;;
    full)       supermodel_run "/v1/graphs/supermodel" "$SRC" | tee /tmp/sm_last.json | supermodel_summary ;;
    dead-code)  supermodel_run "/v1/analysis/dead-code"            "$SRC" | tee /tmp/sm_last.json | supermodel_summary ;;
    circular)   supermodel_run "/v1/analysis/circular-dependencies" "$SRC" | tee /tmp/sm_last.json | supermodel_summary ;;
    coverage)   supermodel_run "/v1/analysis/test-coverage-map"    "$SRC" | tee /tmp/sm_last.json | supermodel_summary ;;
    impact)
      TARGET="${3:-}"
      [[ -z "$TARGET" ]] && { echo "Usage: $0 impact <path> <file:function>"; exit 1; }
      supermodel_run "/v1/analysis/impact" "$SRC" "targets=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TARGET")" | tee /tmp/sm_last.json | supermodel_summary
      ;;
    *)
      echo "Unknown command: $CMD"
      exit 1
      ;;
  esac
fi
