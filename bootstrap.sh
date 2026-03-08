#!/usr/bin/env bash
# bootstrap.sh — Bootstrap for a bare macOS machine.
# Safe to re-run at any time — chezmoi is idempotent.
#
# Usage (first run or re-run to continue after errors):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"

set -uo pipefail

DOTFILES_REPO="https://github.com/1activegeek/dotfiles.git"
BOOTSTRAP_CMD="/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)\""
CHEZMOI_CONFIG="$HOME/.config/chezmoi/chezmoi.toml"
CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"
CHEZMOI_LOG=$(mktemp)
trap 'rm -f "$CHEZMOI_LOG"' EXIT

# ── Helpers ──────────────────────────────────────────────────────────────────

step() { echo ""; echo "==> $*"; }
ok()   { echo "    ✓ $*"; }

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

# ── Pre-flight checklist ──────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
echo "  BEFORE YOU CONTINUE"
echo "════════════════════════════════════════════════════"
echo ""
echo "  Please ensure the following are done first:"
echo "    [ ] Signed into Apple ID (System Settings)"
echo "    [ ] Signed into Mac App Store"
echo "    [ ] iCloud sync complete (Documents/Desktop)"
echo "    [ ] 1Password installed, signed in, and CLI"
echo "        integration enabled (Settings → Developer)"
echo ""
read -r -p "  Ready to continue? [y/N] " preflight
echo ""
if [[ ! "$preflight" =~ ^[Yy]$ ]]; then
  echo "  Complete the steps above and re-run when ready."
  echo ""
  exit 0
fi

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
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi
ok "Homebrew"

# ── chezmoi ───────────────────────────────────────────────────────────────────

step "Checking chezmoi..."
brew install chezmoi 2>/dev/null || fail "Failed to install chezmoi via Homebrew."
ok "chezmoi"

# ── Machine configuration ─────────────────────────────────────────────────────

step "Checking machine configuration..."

if [[ -f "$CHEZMOI_CONFIG" ]]; then
  ok "Configuration already exists — skipping prompts"
else
  echo ""
  echo "  Let's configure this machine before applying dotfiles."
  echo ""

  # Profile
  while true; do
    read -r -p "  Machine profile (personal/work) [personal]: " PROFILE
    PROFILE="${PROFILE:-personal}"
    if [[ "$PROFILE" == "personal" || "$PROFILE" == "work" ]]; then
      break
    fi
    echo "  Please enter 'personal' or 'work'."
  done

  # Git name
  while true; do
    read -r -p "  Git full name: " GIT_NAME
    [[ -n "$GIT_NAME" ]] && break
    echo "  Name is required."
  done

  # Git email
  while true; do
    read -r -p "  Git email: " GIT_EMAIL
    [[ -n "$GIT_EMAIL" ]] && break
    echo "  Email is required."
  done

  mkdir -p "$(dirname "$CHEZMOI_CONFIG")"
  cat > "$CHEZMOI_CONFIG" << TOML
[data]
  profile = "$PROFILE"
  name    = "$GIT_NAME"
  email   = "$GIT_EMAIL"

[onepassword]
  command = "op"

[edit]
  command = "code"
  args    = ["--wait"]

[diff]
  pager = "less -R"
TOML

  echo ""
  ok "Configuration saved (profile: $PROFILE, name: $GIT_NAME, email: $GIT_EMAIL)"
fi

# ── Apply dotfiles ────────────────────────────────────────────────────────────

step "Applying dotfiles..."

if [[ -d "$CHEZMOI_SOURCE" ]]; then
  git -C "$CHEZMOI_SOURCE" fetch origin 2>&1 \
    || fail "Failed to reach origin. Check your network connection and re-run."

  # Warn before discarding any local state in the source dir
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
  fi

  git -C "$CHEZMOI_SOURCE" reset --hard origin/main 2>&1
  chezmoi apply 2>&1 | tee "$CHEZMOI_LOG"
  CHEZMOI_EXIT=${PIPESTATUS[0]}
else
  chezmoi init --apply "$DOTFILES_REPO" 2>&1 | tee "$CHEZMOI_LOG"
  CHEZMOI_EXIT=${PIPESTATUS[0]}
fi

if [[ $CHEZMOI_EXIT -ne 0 ]]; then
  CHEZMOI_OUT=$(cat "$CHEZMOI_LOG")

  # 1Password / op auth is the most common first-run blocker
  if echo "$CHEZMOI_OUT" | grep -qiE "1password|op: |biometric|sign in|not found|unauthorized"; then
    incomplete \
      "1Password CLI is not authenticated — required to deploy secrets." \
      "Steps:" \
      "  1. Open 1Password and sign in" \
      "  2. Enable CLI: Settings → Developer → Integrate with 1Password CLI" \
      "  3. Run:  op signin"
  fi

  # Generic fallback — output already shown via tee above
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
echo "  (copied to clipboard — just paste and hit enter)"
echo "exec zsh -l" | pbcopy
echo ""
