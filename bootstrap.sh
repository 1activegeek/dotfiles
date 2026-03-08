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
  CHEZMOI_OUT=$(chezmoi update 2>&1)
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
