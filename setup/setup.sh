#!/usr/bin/env bash
# setup/setup.sh — one-time machine setup (packages, macOS defaults, Dock, ...).
#
# This is NOT part of `chezmoi apply`. chezmoi only deploys dotfiles; nothing in
# here runs unless you (or bootstrap.sh) call this script.
#
# Each stage writes a stamp file when it succeeds. A stage with a stamp never
# runs again by itself — re-run it on purpose with --only or --force.
#
# Usage:
#   setup.sh                    run every stage that has not succeeded yet
#   setup.sh --list             show stages and whether each one is done
#   setup.sh --only dock        run one stage (or a comma list) even if done
#   setup.sh --only packages --prune
#                               also remove packages not in packages.yaml (asks first)
#   setup.sh --force            run every stage again
#   setup.sh --mark-done        stamp every stage as done without running it
#                               (use once on a machine that is already set up)
#   setup.sh --report           print the post-install report only
set -uo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SETUP_DIR")"
STAGE_DIR="$SETUP_DIR/stages"
STAMP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/setup"

usage() { sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

ONLY=""; FORCE=false; MARK_DONE=false; LIST=false; REPORT_ONLY=false
export DOTFILES_PRUNE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)      ONLY="${2:-}"; shift ;;
    --only=*)    ONLY="${1#*=}" ;;
    --force)     FORCE=true ;;
    --prune)     DOTFILES_PRUNE=true ;;
    --mark-done) MARK_DONE=true ;;
    --list)      LIST=true ;;
    --report)    REPORT_ONLY=true ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

# brew on PATH for every stage (fresh shells may not have it yet)
if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi

# Render a chezmoi template from this repo (uses .chezmoidata + machine profile).
render() { chezmoi --source "$SOURCE_DIR" execute-template < "$1"; }
export -f render 2>/dev/null || true
export SETUP_DIR SOURCE_DIR

stage_name() { local b; b="$(basename "$1" .sh)"; echo "${b#[0-9][0-9]-}"; }
stamp_of()   { echo "$STAMP_DIR/$(stage_name "$1").done"; }

STAGES=()
for f in "$STAGE_DIR"/[0-9][0-9]-*.sh; do STAGES+=("$f"); done

run_report() {
  if command -v chezmoi &>/dev/null; then
    render "$SETUP_DIR/report.sh.tmpl" | bash || true
  else
    echo "    (chezmoi not installed — skipping report)"
  fi
}

if $REPORT_ONLY; then run_report; exit 0; fi

if $LIST; then
  for f in "${STAGES[@]}"; do
    s="$(stamp_of "$f")"
    if [[ -f "$s" ]]; then printf "  ✓ %-16s done %s\n" "$(stage_name "$f")" "$(cat "$s")"
    else printf "  · %-16s not run\n" "$(stage_name "$f")"; fi
  done
  exit 0
fi

mkdir -p "$STAMP_DIR"

if $MARK_DONE; then
  for f in "${STAGES[@]}"; do date '+%Y-%m-%d %H:%M (marked)' > "$(stamp_of "$f")"; done
  echo "==> All setup stages marked as done. Nothing ran."
  exit 0
fi

# Validate --only names
if [[ -n "$ONLY" ]]; then
  IFS=',' read -ra WANT <<< "$ONLY"
  for w in "${WANT[@]}"; do
    found=false
    for f in "${STAGES[@]}"; do [[ "$(stage_name "$f")" == "$w" ]] && found=true; done
    $found || { echo "Unknown stage: $w (see --list)" >&2; exit 2; }
  done
fi

wanted() {
  local name; name="$(stage_name "$1")"
  if [[ -n "$ONLY" ]]; then [[ ",$ONLY," == *",$name,"* ]]; return; fi
  $FORCE && return 0
  [[ ! -f "$(stamp_of "$1")" ]]
}

RAN=0; FAILED=()
for f in "${STAGES[@]}"; do
  wanted "$f" || continue
  name="$(stage_name "$f")"
  echo ""
  echo "──── setup: $name ────"
  if bash "$f"; then
    date '+%Y-%m-%d %H:%M' > "$(stamp_of "$f")"
  else
    echo "    ⚠ stage '$name' failed — it will run again next time (or: setup.sh --only $name)"
    FAILED+=("$name")
  fi
  RAN=$((RAN + 1))
done

if [[ $RAN -eq 0 ]]; then
  echo "==> Machine setup already complete. Nothing to do."
  echo "    See stages:        $0 --list"
  echo "    Re-run one stage:  $0 --only <stage>"
  exit 0
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo "==> Setup finished with failed stages: ${FAILED[*]}"
  exit 1
fi
echo ""
echo "==> Setup stages complete."
