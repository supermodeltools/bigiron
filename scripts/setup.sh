#!/usr/bin/env bash
# setup.sh — First-time setup for Big Iron
#
# Usage: ./scripts/setup.sh

set -euo pipefail

echo ""
echo "        _________   "
echo "       /  _____  \  "
echo "      /___________\ "
echo "      |  (o)  (o) |     B I G   I R O N"
echo "      |     ^     |     ~~~~~~~~~~~~~~~~~"
echo "      |   [---]   |     AI-Native SDLC Setup"
echo "      |___________|     Ride the graph. Ship clean iron."
echo "      /|         |\ "
echo "     (_)         (_)"
echo ""

# ---------------------------------------------------------------------------
# 1. Check prerequisites
# ---------------------------------------------------------------------------

echo "Checking prerequisites..."
MISSING=()

command -v hermes &>/dev/null || MISSING+=("hermes (install: pip install hermes-agent)")
command -v node &>/dev/null   || MISSING+=("node (install: https://nodejs.org)")
command -v npm &>/dev/null    || MISSING+=("npm (bundled with node)")
command -v git &>/dev/null    || MISSING+=("git")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  echo "ERROR: Missing required tools:"
  for tool in "${MISSING[@]}"; do
    echo "  - $tool"
  done
  echo ""
  echo "Install missing tools and re-run setup."
  exit 1
fi

echo "  ✓ hermes"
echo "  ✓ node / npm"
echo "  ✓ git"
echo ""

# ---------------------------------------------------------------------------
# 2. Check environment variables
# ---------------------------------------------------------------------------

echo "Checking environment variables..."
MISSING_ENV=()

[[ -z "${SUPERMODEL_API_KEY:-}" ]] && MISSING_ENV+=("SUPERMODEL_API_KEY  (get at: https://supermodeltools.com)")
[[ -z "${GITHUB_TOKEN:-}" ]]       && MISSING_ENV+=("GITHUB_TOKEN        (optional — required for PR automation)")

if [[ ${#MISSING_ENV[@]} -gt 0 ]]; then
  echo ""
  echo "WARNING: Missing environment variables:"
  for var in "${MISSING_ENV[@]}"; do
    echo "  - $var"
  done
  echo ""
  echo "Set these in your shell profile or ~/.hermes/.env"
  echo "Continuing setup (some features will be disabled)..."
  echo ""
fi

# ---------------------------------------------------------------------------
# 3. Install Supermodel MCP server
# ---------------------------------------------------------------------------

echo "Installing Supermodel MCP server..."
if command -v supermodel-mcp &>/dev/null; then
  echo "  ✓ supermodel-mcp already installed"
else
  npm install -g @supermodeltools/mcp-server
  echo "  ✓ supermodel-mcp installed"
fi
echo ""

# ---------------------------------------------------------------------------
# 4. Install Hermes skills
# ---------------------------------------------------------------------------

echo "Installing SDLC skills..."
bash "$(dirname "$0")/install_skills.sh"
echo ""

# ---------------------------------------------------------------------------
# 5. Install Hermes config
# ---------------------------------------------------------------------------

echo "Installing Hermes config..."
HERMES_CONFIG="${HOME}/.hermes/config.yaml"
PROJECT_CONFIG="$(cd "$(dirname "$0")/../config" && pwd)/hermes-config.yaml"

if [[ -f "$HERMES_CONFIG" ]]; then
  echo "  ⚠ ~/.hermes/config.yaml already exists."
  echo "  Backup saved to ~/.hermes/config.yaml.bak"
  cp "$HERMES_CONFIG" "${HERMES_CONFIG}.bak"
fi

mkdir -p "${HOME}/.hermes"
cp "$PROJECT_CONFIG" "$HERMES_CONFIG"
echo "  ✓ Config installed to ~/.hermes/config.yaml"
echo ""

# ---------------------------------------------------------------------------
# 6. Initialize Supermodel on this project
# ---------------------------------------------------------------------------

echo "Initializing Supermodel graph..."
if [[ -n "${SUPERMODEL_API_KEY:-}" ]]; then
  supermodel-mcp init --root "$(pwd)" || echo "  ⚠ Graph init failed — run 'supermodel-mcp init' manually"
  echo "  ✓ Graph initialized"
else
  echo "  ⚠ Skipped (SUPERMODEL_API_KEY not set)"
fi
echo ""

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo "================================================"
echo "  Setup complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Set SUPERMODEL_API_KEY if not done"
echo "  2. Run: hermes"
echo "  3. In Hermes, run: /reload-mcp"
echo "  4. Point the factory at a goal:"
echo "       factory run ./my-project \"add feature X\""
echo ""
echo "Demo: ./scripts/demo_run.sh ./demo \"Add rate limiting to the order API\""
echo ""
