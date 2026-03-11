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
# Accept the Xcode license — required before any build tools (including brew) work.
# Runs silently if already accepted.
sudo xcodebuild -license accept 2>/dev/null || true
ok "Xcode CLI Tools"

# ── Homebrew ──────────────────────────────────────────────────────────────────

step "Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "    Homebrew installation requires administrator access."
  sudo -v || fail "sudo authentication failed — ensure your account has administrator privileges."
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
if ! brew list --formula chezmoi &>/dev/null; then
  brew install chezmoi || fail "Failed to install chezmoi via Homebrew."
fi
ok "chezmoi"

# ── 1Password ─────────────────────────────────────────────────────────────────

step "Setting up 1Password..."

if ! brew list --cask 1password &>/dev/null; then
  echo "    Installing 1Password..."
  HOMEBREW_CASK_OPTS="--no-quarantine" brew install --cask 1password \
    || fail "Failed to install 1Password."
fi

if ! brew list --cask 1password-cli &>/dev/null; then
  echo "    Installing 1Password CLI..."
  HOMEBREW_CASK_OPTS="--no-quarantine" brew install --cask 1password-cli \
    || fail "Failed to install 1Password CLI."
fi

# Pause and guide the user through CLI authentication if not already set up
if ! op account list &>/dev/null 2>&1; then
  echo ""
  echo "════════════════════════════════════════════════════"
  echo "  ACTION REQUIRED — Authenticate 1Password CLI"
  echo "════════════════════════════════════════════════════"
  echo ""
  echo "  1Password is now installed. Complete these steps:"
  echo ""
  echo "    1. Open 1Password and sign into your account"
  echo "    2. Go to Settings → Developer"
  echo "    3. Enable 'Integrate with 1Password CLI'"
  echo ""
  read -r -p "  Press Enter when ready..." _
  echo ""
  if ! op account list &>/dev/null 2>&1; then
    fail "1Password CLI is not authenticated. Complete the steps above and re-run."
  fi
fi
ok "1Password"

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

  # Hostname (personal only)
  HOSTNAME_SET=false
  if [[ "$PROFILE" == "personal" ]]; then
    read -r -p "  Set a custom hostname? [y/N] " set_hn
    if [[ "$set_hn" =~ ^[Yy]$ ]]; then
      read -r -p "  Hostname (e.g. shawns-macbook): " HOSTNAME_VAL
      if [[ -n "$HOSTNAME_VAL" ]]; then
        sudo scutil --set ComputerName  "$HOSTNAME_VAL"
        sudo scutil --set HostName      "$HOSTNAME_VAL"
        sudo scutil --set LocalHostName "$HOSTNAME_VAL"
        ok "Hostname set to: $HOSTNAME_VAL"
        HOSTNAME_SET=true
      fi
    fi
  fi

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

# Snapshot state before apply so we can tell if chezmoi runs the report itself.
if chezmoi state dump --format=json 2>/dev/null | grep -q "run_once_after_12"; then
  REPORT_IN_STATE_BEFORE=true
else
  REPORT_IN_STATE_BEFORE=false
fi

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

# ── Post-install report ───────────────────────────────────────────────────────
# Run the report explicitly unless chezmoi just ran it during this apply session
# (i.e. it was absent from state before apply but present after — meaning chezmoi
# ran it and the output already appeared inline). In all other cases run it here
# so it always appears at the end of bootstrap output where it's easy to see.

if chezmoi state dump --format=json 2>/dev/null | grep -q "run_once_after_12"; then
  REPORT_IN_STATE_AFTER=true
else
  REPORT_IN_STATE_AFTER=false
fi

REPORT_TMPL="$CHEZMOI_SOURCE/.chezmoiscripts/run_once_after_12-post-install.sh.tmpl"
# Skip only if chezmoi ran it during THIS apply (was absent before, present after)
if [[ "$REPORT_IN_STATE_BEFORE" == "false" && "$REPORT_IN_STATE_AFTER" == "true" ]]; then
  : # chezmoi ran it inline during apply — no need to repeat
elif [[ -f "$REPORT_TMPL" ]]; then
  chezmoi execute-template < "$REPORT_TMPL" | bash || true
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
echo "  ALL DONE"
echo "════════════════════════════════════════════════════"
echo ""
echo "  Dotfiles applied successfully."
echo ""
echo "  ► Reloading your shell now for a clean session..."
echo ""
echo "exec zsh -l" | pbcopy

# Replace the current interactive shell with a fresh login zsh.
# This sources .zprofile + .zshrc as if opening a brand-new terminal.
exec zsh -l
