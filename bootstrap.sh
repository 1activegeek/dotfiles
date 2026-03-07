#!/usr/bin/env bash
# bootstrap.sh — Minimal bootstrap for a bare macOS machine.
# Installs Xcode CLI Tools, Homebrew, and chezmoi, then hands off
# to chezmoi for everything else.
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"

set -euo pipefail

echo "==> Installing Xcode Command Line Tools (if needed)..."
if ! xcode-select -p &>/dev/null; then
  xcode-select --install
  echo "    Waiting for Xcode CLI tools..."
  until xcode-select -p &>/dev/null; do sleep 5; done
fi

echo "==> Installing Homebrew (if needed)..."
if ! command -v brew &>/dev/null; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "==> Installing chezmoi..."
brew install chezmoi

echo "==> Initializing dotfiles..."
chezmoi init --apply https://github.com/1activegeek/dotfiles.git

echo "==> Done! Restart your shell or run: exec zsh -l"
