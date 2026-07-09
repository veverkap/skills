#!/usr/bin/env bash
#
# install.sh — link (or copy) every skill in ./skills into your agent skill dirs.
#
# Usage:
#   ./install.sh [--copy] [--force] [--dry-run] [--target DIR ...]
#
#   --copy         Copy skill folders instead of symlinking (for tools that
#                  don't follow symlinks). Repo is no longer the live source.
#   --force        Replace an existing skill entry even if it is a real
#                  directory or a symlink pointing elsewhere.
#   --dry-run      Print what would happen without changing anything.
#   --target DIR   Install into DIR instead of the auto-detected defaults.
#                  May be repeated. Overrides the default target list.
#
# Default targets (only those whose parent dir exists are used):
#   ~/.claude/skills
#   ~/.copilot/skills
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/skills"

COPY=false
FORCE=false
DRY_RUN=false
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)    COPY=true; shift ;;
    --force)   FORCE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --target)  TARGETS+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  for d in "$HOME/.claude/skills" "$HOME/.copilot/skills"; do
    [[ -d "$(dirname "$d")" ]] && TARGETS+=("$d")
  done
fi

if [[ ! -d "$SRC_DIR" ]]; then
  echo "No skills/ directory found at $SRC_DIR" >&2
  exit 1
fi

run() { if $DRY_RUN; then echo "  [dry-run] $*"; else eval "$@"; fi; }

echo "Repo:    $REPO_DIR"
echo "Mode:    $($COPY && echo copy || echo symlink)$($FORCE && echo ' (force)')$($DRY_RUN && echo ' (dry-run)')"
echo

for target in "${TARGETS[@]}"; do
  echo "Target: $target"
  run "mkdir -p '$target'"

  for skill_path in "$SRC_DIR"/*/; do
    [[ -d "$skill_path" ]] || continue
    name="$(basename "$skill_path")"
    dest="$target/$name"
    src="${skill_path%/}"

    # Already the correct symlink?
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" && "$COPY" == false ]]; then
      echo "  = $name (already linked)"
      continue
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
      if $FORCE; then
        run "rm -rf '$dest'"
      else
        echo "  ! $name (exists, skipping — use --force to replace)"
        continue
      fi
    fi

    if $COPY; then
      run "cp -R '$src' '$dest'"
      echo "  + $name (copied)"
    else
      run "ln -s '$src' '$dest'"
      echo "  + $name (linked)"
    fi
  done
  echo
done

echo "Done."
