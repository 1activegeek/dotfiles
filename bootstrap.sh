#!/usr/bin/env bash
# bootstrap.sh — Bootstrap for a bare macOS machine.
# Safe to re-run at any time: chezmoi is idempotent, and setup/setup.sh skips
# every stage that already succeeded (stamps in ~/.local/state/dotfiles/setup).
#
# Two separate parts:
#   1. chezmoi apply      → dotfiles only (no scripts run)
#   2. setup/setup.sh     → one-time machine setup: Homebrew, packages + MAS,
#                           macOS defaults, Dock, Claude skill links
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

  # Private files from 1Password notes (.chezmoidata/private_notes.yaml): personal only
  PRIVATE_NOTES=false
  [[ "$PROFILE" == "personal" ]] && PRIVATE_NOTES=true

  mkdir -p "$(dirname "$CHEZMOI_CONFIG")"
  cat > "$CHEZMOI_CONFIG" << TOML
[data]
  profile = "$PROFILE"
  name    = "$GIT_NAME"
  email   = "$GIT_EMAIL"
  privateNotes = $PRIVATE_NOTES

[onepassword]
  command = "op"

[edit]
  command = "code"
  args    = ["--wait"]

[diff]
  pager = "less -R"

[git]
  autoCommit = false
  autoPush = false
TOML

  echo ""
  ok "Configuration saved (profile: $PROFILE, name: $GIT_NAME, email: $GIT_EMAIL)"
fi

# ── Apply dotfiles ────────────────────────────────────────────────────────────

step "Applying dotfiles..."

if [[ -d "$CHEZMOI_SOURCE/.git" ]]; then
  # Update the source dir WITHOUT discarding anything: fast-forward only.
  # If there is local work (uncommitted changes, unpushed commits, another
  # branch), stop and let you decide — never reset it away.
  git -C "$CHEZMOI_SOURCE" fetch origin 2>&1 \
    || fail "Failed to reach origin. Check your network connection and re-run."

  SRC_BRANCH="$(git -C "$CHEZMOI_SOURCE" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  SRC_DIRTY="$(git -C "$CHEZMOI_SOURCE" status --porcelain 2>/dev/null)"
  SRC_AHEAD="$(git -C "$CHEZMOI_SOURCE" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)"

  if [[ "$SRC_BRANCH" != "main" || -n "$SRC_DIRTY" || "$SRC_AHEAD" != "0" ]]; then
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  LOCAL WORK IN THE DOTFILES SOURCE DIR"
    echo "════════════════════════════════════════════════════"
    echo ""
    echo "  $CHEZMOI_SOURCE"
    [[ "$SRC_BRANCH" != "main" ]] && echo "  - on branch '$SRC_BRANCH' (expected 'main')"
    [[ "$SRC_AHEAD" != "0" ]] && echo "  - $SRC_AHEAD local commit(s) not on origin/main"
    if [[ -n "$SRC_DIRTY" ]]; then
      echo "  - uncommitted changes:"
      echo "$SRC_DIRTY" | sed 's/^/      /'
    fi
    echo ""
    echo "  Bootstrap will not touch this work. Commit/push or move it aside, then re-run."
    read -r -p "  Continue WITHOUT updating the source dir (apply what is there now)? [y/N] " confirm
    echo ""
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "  Stopped. Resolve the items above, then re-run:"
      echo ""
      echo "    $BOOTSTRAP_CMD"
      echo ""
      exit 1
    fi
  else
    git -C "$CHEZMOI_SOURCE" merge --ff-only origin/main 2>&1 \
      || fail "Could not fast-forward $CHEZMOI_SOURCE to origin/main."
  fi
fi

# Build chezmoi apply args
CHEZMOI_APPLY_ARGS=()
if [[ "$SKIP_1PASSWORD" == true ]]; then
  # .chezmoiignore skips every 1Password-backed file (ssh/kube config, age key,
  # private notes) while this is set. Re-run bootstrap later to deploy them.
  export DOTFILES_SKIP_1PASSWORD=1
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

# ── One-time machine setup ───────────────────────────────────────────────────
# Packages, MAS apps, macOS defaults, Dock. Stages that already succeeded are
# skipped, so a re-run only retries what failed.

step "Running machine setup stages..."
SETUP_SCRIPT="$CHEZMOI_SOURCE/setup/setup.sh"
if [[ -x "$SETUP_SCRIPT" ]]; then
  while true; do
    if "$SETUP_SCRIPT"; then
      break
    fi
    echo ""
    read -r -p "    Some setup stages failed. Retry them? [Y/n] " response
    response="${response:-y}"
    if [[ "$response" =~ ^[Nn]$ ]]; then
      echo "    Skipping — retry later with: $SETUP_SCRIPT"
      break
    fi
  done
else
  echo "    ⚠ $SETUP_SCRIPT not found — skipping machine setup"
fi

# ── Post-install report ───────────────────────────────────────────────────────

[[ -x "$SETUP_SCRIPT" ]] && "$SETUP_SCRIPT" --report

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
