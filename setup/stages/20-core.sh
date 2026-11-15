#!/bin/bash
# setup stage: core
# Installs the core apps first (1Password, browser, terminal, launcher) so the
# machine is usable while the full package stage runs.
# Run by setup/setup.sh only (never by chezmoi apply).

set -euo pipefail

[[ "$(uname)" == "Darwin" ]] || exit 0

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "==> Installing core packages..."

CORE_FORMULAE=(chezmoi gh mas)
CORE_CASKS=(1password 1password-cli brave-browser ghostty raycast)

for formula in "${CORE_FORMULAE[@]}"; do
  if ! brew list --formula "$formula" &>/dev/null; then
    echo "    Installing formula: $formula"
    brew install "$formula" || echo "    WARNING: Failed to install $formula"
  fi
done

for cask in "${CORE_CASKS[@]}"; do
  if ! brew list --cask "$cask" &>/dev/null; then
    echo "    Installing cask: $cask"
    HOMEBREW_CASK_OPTS="--no-quarantine" brew install --cask "$cask" || echo "    WARNING: Failed to install $cask"
  fi
done

echo "==> Core packages: OK"

