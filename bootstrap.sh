#!/usr/bin/env bash
# bootstrap.sh — Bootstrap for a bare macOS machine.
# Safe to re-run at any time — chezmoi is idempotent.
#
# Usage (first run or re-run to continue after errors):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"

set -uo pipefail

DOTFILES_REPO="https://github.com/1activegeek/dotfiles.git"
DOTFILES_REPO_SSH="git@github.com:1activegeek/dotfiles.git"
BOOTSTRAP_CMD="/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)\""
CHEZMOI_CONFIG="$HOME/.config/chezmoi/chezmoi.toml"
CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"
CHEZMOI_LOG=$(mktemp)
SKIP_1PASSWORD=false
trap 'rm -f "$CHEZMOI_LOG"' EXIT

# ── Ensure brew is in PATH for re-runs ────────────────────────────────────────
# First run won't have it yet, but re-runs need it so `command -v brew` succeeds
# and we don't re-install Homebrew unnecessarily.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh 2>/dev/null)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv zsh 2>/dev/null)"
fi

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
# Accept the license only if it hasn't been accepted yet (fresh install or OS update).
# xcodebuild -license status exits non-zero when acceptance is needed, regardless of
# whether full Xcode or just the CLT is active.
if ! xcodebuild -license status &>/dev/null; then
  echo "    Accepting Xcode license agreement..."
  sudo xcodebuild -license accept || fail "Failed to accept Xcode license."
fi
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

  while true; do
    read -r -p "  Press Enter when ready (or 's' to skip secrets for now)... " response
    if [[ "$response" == "s" || "$response" == "S" ]]; then
      echo "    ⚠ Skipping 1Password — secrets won't be deployed"
      echo "    Re-run bootstrap later to deploy secrets"
      SKIP_1PASSWORD=true
      break
    fi
    if op account list &>/dev/null 2>&1; then
      echo "    ✓ 1Password CLI authenticated"
      break
    fi
    echo "    ✗ Still not authenticated — please check the steps above"
    echo ""
  done
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

[git]
  autoCommit = true
  autoPush = true
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
fi

# Build chezmoi apply args
CHEZMOI_APPLY_ARGS=()
if [[ "$SKIP_1PASSWORD" == true ]]; then
  CHEZMOI_APPLY_ARGS+=(--exclude=encrypted)
fi

MAX_RETRIES=2
RETRY=0
while true; do
  if [[ -d "$CHEZMOI_SOURCE/.git" ]]; then
    chezmoi apply ${CHEZMOI_APPLY_ARGS[@]+"${CHEZMOI_APPLY_ARGS[@]}"} 2>&1 | tee "$CHEZMOI_LOG"
    CHEZMOI_EXIT=${PIPESTATUS[0]}
  else
    chezmoi init --apply "$DOTFILES_REPO" ${CHEZMOI_APPLY_ARGS[@]+"${CHEZMOI_APPLY_ARGS[@]}"} 2>&1 | tee "$CHEZMOI_LOG"
    CHEZMOI_EXIT=${PIPESTATUS[0]}
  fi

  if [[ $CHEZMOI_EXIT -eq 0 ]]; then
    break
  fi

  RETRY=$((RETRY + 1))
  CHEZMOI_OUT=$(cat "$CHEZMOI_LOG")

  if echo "$CHEZMOI_OUT" | grep -qiE "1password|op: |biometric|sign in|not found|unauthorized"; then
    echo ""
    echo "    ⚠ chezmoi failed due to 1Password authentication"
    echo "    Please complete 1Password CLI setup (see steps above)"
    echo ""
    if [[ $RETRY -ge $MAX_RETRIES ]]; then
      incomplete "1Password CLI is not authenticated after $MAX_RETRIES retries."
    fi
    read -r -p "    Press Enter to retry chezmoi apply (or 's' to skip)... " response
    if [[ "$response" == "s" || "$response" == "S" ]]; then
      echo "    ⚠ Skipping — some secrets may not be deployed"
      break
    fi
    continue
  fi

  # Non-1Password failure
  if [[ $RETRY -ge $MAX_RETRIES ]]; then
    incomplete "chezmoi exited with an error after $MAX_RETRIES retries (see output above)."
  fi
  echo ""
  echo "    ⚠ chezmoi apply failed — review the error above"
  read -r -p "    Press Enter to retry (or 's' to skip)... " response
  if [[ "$response" == "s" || "$response" == "S" ]]; then
    echo "    ⚠ Skipping — some dotfiles may not be applied"
    break
  fi
done

# ── Switch chezmoi source to SSH remote ──────────────────────────────────────
# The initial clone uses HTTPS (SSH keys aren't deployed yet on a fresh machine).
# Now that chezmoi has applied dotfiles (including SSH keys from 1Password),
# switch to SSH so autoPush works going forward.

step "Switching chezmoi source remote to SSH..."
if [[ -d "$CHEZMOI_SOURCE/.git" ]]; then
  CURRENT_REMOTE=$(git -C "$CHEZMOI_SOURCE" remote get-url origin 2>/dev/null || true)
  if [[ "$CURRENT_REMOTE" != "$DOTFILES_REPO_SSH" ]]; then
    git -C "$CHEZMOI_SOURCE" remote set-url origin "$DOTFILES_REPO_SSH"
    ok "Remote switched to SSH ($DOTFILES_REPO_SSH)"
  else
    ok "Remote already using SSH"
  fi
fi

# ── Dock retry check ─────────────────────────────────────────────────────────

DOCK_STAMP="${HOME}/.local/state/dotfiles/dock-configured"
DOCK_SCRIPT="${CHEZMOI_SOURCE}/.chezmoiscripts/run_onchange_after_11-dock.sh"
if [[ -f "$DOCK_SCRIPT" ]] && [[ ! -f "$DOCK_STAMP" ]]; then
  echo ""
  echo "    ⚠ Dock configuration did not complete"
  while true; do
    read -r -p "    Retry dock configuration? [Y/n] " response
    response="${response:-y}"
    if [[ "$response" =~ ^[Nn]$ ]]; then
      echo "    Skipping — run manually later: bash $DOCK_SCRIPT"
      break
    fi
    if bash "$DOCK_SCRIPT"; then
      break
    fi
    echo "    ⚠ Dock configuration failed again"
  done
fi

# ── Post-install report ───────────────────────────────────────────────────────

REPORT_TMPL="$CHEZMOI_SOURCE/post-install-report.sh.tmpl"
if [[ -f "$REPORT_TMPL" ]]; then
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
