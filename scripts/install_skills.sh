#!/usr/bin/env bash
# install_skills.sh — Sync Big Iron skills into ~/.hermes/skills/
#
# Run this after cloning or after updating skill files.
# Existing skills with the same name will be overwritten.
#
# Usage: ./scripts/install_skills.sh [--dry-run]

set -euo pipefail

SKILLS_SRC="$(cd "$(dirname "$0")/../skills" && pwd)"
SKILLS_DST="${HOME}/.hermes/skills"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[dry-run] No files will be written."
fi

if [[ ! -d "$SKILLS_SRC" ]]; then
  echo "ERROR: skills directory not found at $SKILLS_SRC" >&2
  exit 1
fi

if [[ ! -d "$SKILLS_DST" ]]; then
  echo "Creating ~/.hermes/skills/ ..."
  if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$SKILLS_DST"
  fi
fi

echo "Installing skills from $SKILLS_SRC → $SKILLS_DST"
echo ""

INSTALLED=0
for skill_file in "$SKILLS_SRC"/*.md; do
  skill_name="$(basename "$skill_file")"
  dest="$SKILLS_DST/$skill_name"

  if [[ "$DRY_RUN" == true ]]; then
    echo "  [would install] $skill_name"
  else
    cp "$skill_file" "$dest"
    echo "  ✓ $skill_name"
  fi
  ((INSTALLED++))
done

echo ""
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run complete. $INSTALLED skill(s) would be installed."
else
  echo "Done. $INSTALLED skill(s) installed."
  echo ""
  echo "Reload skills in Hermes with: /reload-mcp"
fi
