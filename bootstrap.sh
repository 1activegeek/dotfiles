#!/usr/bin/env bash
# bootstrap.sh — Bootstrap for a bare macOS machine.
# Safe to re-run at any time — chezmoi is idempotent.
#
# Usage (first run or re-run to continue after errors):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"

set -uo pipefail

DOTFILES_REPO="https://github.com/1activegeek/dotfiles.git"
BOOTSTRAP_CMD="/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)\""

# ── Helpers ──────────────────────────────────────────────────────────────────

step()  { echo ""; echo "==> $*"; }
ok()    { echo "    ✓ $*"; }
warn()  { echo "    ⚠ $*"; }

fail() {
  echo ""
  echo "════════════════════════════════════════════════════"
  echo "  ERROR"
  echo "════════════════════════════════════════════════════"
  echo ""
  echo "  $*"
  echo ""
  echo "  Fix the issue above, then re-run bootstrap:"
  echo ""
  echo "    $BOOTSTRAP_CMD"
  echo ""
  exit 1
}

incomplete() {
  local reason="$1"; shift
  echo ""
  echo "════════════════════════════════════════════════════"
  echo "  SETUP INCOMPLETE — ACTION REQUIRED"
  echo "════════════════════════════════════════════════════"
  echo ""
  echo "  $reason"
  echo ""
  while [[ $# -gt 0 ]]; do
    echo "  $1"; shift
  done
  echo ""
  echo "  Then re-run bootstrap to continue:"
  echo ""
  echo "    $BOOTSTRAP_CMD"
  echo ""
  exit 1
}

# ── Xcode CLI Tools ───────────────────────────────────────────────────────────

step "Checking Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
  echo "    Installing — a dialog will appear, click Install..."
  xcode-select --install
  until xcode-select -p &>/dev/null; do sleep 5; done
fi
ok "Xcode CLI Tools"

# ── Homebrew ──────────────────────────────────────────────────────────────────

step "Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || fail "Homebrew installation failed."
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
fi
ok "Homebrew"

# ── chezmoi ───────────────────────────────────────────────────────────────────

step "Checking chezmoi..."
brew install chezmoi 2>/dev/null || fail "Failed to install chezmoi via Homebrew."
ok "chezmoi"

# ── Apply dotfiles ────────────────────────────────────────────────────────────

step "Applying dotfiles..."

CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"

if [[ -d "$CHEZMOI_SOURCE" ]]; then
  git -C "$CHEZMOI_SOURCE" fetch origin 2>&1 \
    || fail "Failed to reach origin. Check your network connection and re-run."

  # Check if the source dir has local changes or is in a conflicted state
  if ! git -C "$CHEZMOI_SOURCE" diff --quiet 2>/dev/null \
      || ! git -C "$CHEZMOI_SOURCE" diff --cached --quiet 2>/dev/null \
      || [[ -n "$(git -C "$CHEZMOI_SOURCE" ls-files --unmerged 2>/dev/null)" ]]; then
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  WARNING — Local changes detected in source dir"
    echo "════════════════════════════════════════════════════"
    echo ""
    echo "  $CHEZMOI_SOURCE"
    echo "  has uncommitted or conflicted changes:"
    echo ""
    git -C "$CHEZMOI_SOURCE" status --short | sed 's/^/    /'
    echo ""
    echo "  This usually means a previous run failed mid-way."
    echo "  Resetting will discard these local changes and sync"
    echo "  the source dir to match origin/main exactly."
    echo ""
    echo "  If you have intentional changes here, press N and"
    echo "  resolve them manually in:"
    echo "    $CHEZMOI_SOURCE"
    echo ""
    read -r -p "  Reset source dir and continue? [y/N] " confirm
    echo ""
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "  Aborted. Resolve the changes above, then re-run:"
      echo ""
      echo "    $BOOTSTRAP_CMD"
      echo ""
      exit 1
    fi
    git -C "$CHEZMOI_SOURCE" reset --hard origin/main 2>&1
  else
    git -C "$CHEZMOI_SOURCE" reset --hard origin/main 2>&1
  fi

  CHEZMOI_OUT=$(chezmoi apply 2>&1)
  CHEZMOI_EXIT=$?
else
  CHEZMOI_OUT=$(chezmoi init --apply "$DOTFILES_REPO" 2>&1)
  CHEZMOI_EXIT=$?
fi

if [[ $CHEZMOI_EXIT -ne 0 ]]; then
  # Surface the raw error for context
  echo ""
  echo "  chezmoi output:"
  echo "$CHEZMOI_OUT" | sed 's/^/    /'

  # 1Password / op auth is the most common first-run blocker
  if echo "$CHEZMOI_OUT" | grep -qiE "1password|op: |biometric|sign in|not found|unauthorized"; then
    incomplete \
      "1Password CLI is not authenticated — required to deploy secrets." \
      "Steps:" \
      "  1. Open 1Password and sign in" \
      "  2. Enable CLI: Settings → Developer → Integrate with 1Password CLI" \
      "  3. Run:  op signin"
  fi

  # Generic fallback
  incomplete "chezmoi exited with an error (see output above)."
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
echo "  ALL DONE"
echo "════════════════════════════════════════════════════"
echo ""
echo "  Dotfiles applied. Restart your shell to continue:"
echo ""
echo "    exec zsh -l"
echo ""
