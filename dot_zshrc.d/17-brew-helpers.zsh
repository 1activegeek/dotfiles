# 17-brew-helpers.zsh — Homebrew sync and export helpers

# Export current Homebrew state to chezmoi source for comparison
brew-export() {
  local output
  output="$(chezmoi source-path)/Brewfile.current"
  echo "Exporting current Homebrew state to: $output"
  brew bundle dump --file="$output" --force
  echo "Done. Compare with .chezmoidata/packages.yaml to see drift."
}

# Sync installed packages with the chezmoi-managed package list
brew-sync() {
  local brewfile
  brewfile="$(mktemp)"
  trap 'rm -f "$brewfile"' RETURN

  # Re-apply the brew bundle script to get latest Brewfile
  echo "==> Applying brew bundle (this may take a moment)..."
  chezmoi apply --include=scripts 2>/dev/null || {
    echo "    Note: chezmoi apply returned non-zero (some scripts may have been skipped)"
  }

  # Check for packages not in chezmoi's Brewfile
  echo "==> Generating current Brewfile for comparison..."
  brew bundle dump --file="$brewfile" --force 2>/dev/null

  echo "==> Checking for untracked packages..."
  local cleanup_output
  cleanup_output="$(brew bundle cleanup --file="$brewfile" 2>/dev/null || true)"

  if [[ -n "$cleanup_output" ]]; then
    echo ""
    echo "The following packages are installed but not in your package list:"
    echo "$cleanup_output"
    echo ""
    read -rp "Remove these packages? [y/N]: " confirm
    if [[ "$(echo "${confirm:-n}" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
      brew bundle cleanup --file="$brewfile" --force
      echo "==> Cleanup complete."
    else
      echo "==> Skipped cleanup."
    fi
  else
    echo "==> All packages accounted for."
  fi
}
