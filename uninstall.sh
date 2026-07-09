#!/usr/bin/env bash
#
# uninstall.sh — remove skill entries created by install.sh from agent dirs.
#
# Only removes entries that match a skill name in ./skills AND are either a
# symlink into this repo or (with --copy) a plain copy. Real symlinks pointing
# elsewhere and unrelated files are left untouched.
#
# Usage:
#   ./uninstall.sh [--copy] [--dry-run] [--target DIR ...]
#
#   --copy         Also remove plain-directory copies (not just symlinks).
#   --dry-run      Print what would happen without changing anything.
#   --target DIR   Uninstall from DIR instead of auto-detected defaults.
#                  May be repeated. Overrides the default target list.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/skills"

COPY=false
DRY_RUN=false
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)    COPY=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --target)  TARGETS+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  for d in "$HOME/.claude/skills" "$HOME/.copilot/skills"; do
    [[ -d "$d" ]] && TARGETS+=("$d")
  done
fi

run() { if $DRY_RUN; then echo "  [dry-run] $*"; else eval "$@"; fi; }

for target in "${TARGETS[@]}"; do
  echo "Target: $target"
  for skill_path in "$SRC_DIR"/*/; do
    name="$(basename "$skill_path")"
    dest="$target/$name"
    src="${skill_path%/}"

    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
      run "rm '$dest'"
      echo "  - $name (unlinked)"
    elif $COPY && [[ -d "$dest" && ! -L "$dest" ]]; then
      run "rm -rf '$dest'"
      echo "  - $name (removed copy)"
    else
      echo "  = $name (not managed here, skipping)"
    fi
  done
  echo
done

echo "Done."
