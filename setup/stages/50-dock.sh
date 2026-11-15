#!/bin/bash
# setup stage: dock
# Wipes and rebuilds the macOS Dock via dockutil.
# Run by setup/setup.sh only (never by chezmoi apply). Re-run on purpose:
#   ~/.local/share/chezmoi/setup/setup.sh --only dock
set -euo pipefail
[[ "$(uname)" != "Darwin" ]] && exit 0
if ! command -v dockutil &>/dev/null; then
  echo "    ⚠ dockutil not installed (it comes from the packages stage)"
  exit 1
fi

echo "==> Configuring Dock..."

# ============================================
# Wipe existing Dock and rebuild from scratch
# ============================================
echo "    Clearing existing Dock items"
dockutil --remove all --no-restart

# ============================================
# Add apps in exact order
# ============================================
echo "    Adding Dock items"

# Format: "Label|/path/to/App.app"
DOCK_APPS=(
  "Microsoft Teams|/Applications/Microsoft Teams.app"
  "Brave Browser|/Applications/Brave Browser.app"
  "Safari|/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
  "Mail|/System/Applications/Mail.app"
  "Messages|/System/Applications/Messages.app"
  "Calendar|/System/Applications/Calendar.app"
  "Reminders|/System/Applications/Reminders.app"
  "Obsidian|/Applications/Obsidian.app"
  "Discord|/Applications/Discord.app"
  "Music|/System/Applications/Music.app"
  "Claude|/Applications/Claude.app"
  "ChatGPT|/Applications/ChatGPT.app"
  "Perplexity|/Applications/Perplexity.app"
  "OpenCode|/Applications/OpenCode.app"
  "Visual Studio Code|/Applications/Visual Studio Code.app"
  "Ghostty|/Applications/Ghostty.app"
)

for entry in "${DOCK_APPS[@]}"; do
  IFS='|' read -r name path <<< "$entry"
  if [[ -e "$path" ]]; then
    dockutil --add "$path" --label "$name" --section apps --no-restart || \
      echo "    ⚠ Failed to add: $name"
    echo "    Added: $name"
  else
    echo "    ⚠ App not found, skipping: $name ($path)"
  fi
done

# ============================================
# Add "Others" section (folders)
# ============================================
echo "    Adding Dock folder items"

# Applications folder — grid view, sorted by name
dockutil --add "/Applications" \
  --label "Applications" \
  --view grid \
  --display folder \
  --sort name \
  --section others \
  --no-restart || echo "    ⚠ Failed to add: Applications folder"
echo "    Added: Applications folder"

# Downloads folder — list view, sorted by date added
dockutil --add "${HOME}/Downloads" \
  --label "Downloads" \
  --view list \
  --display folder \
  --sort dateadded \
  --section others \
  --no-restart || echo "    ⚠ Failed to add: Downloads folder"
echo "    Added: Downloads folder"

# ============================================
# Single Dock restart (apply all changes at once)
# ============================================
echo "    Restarting Dock to apply changes"
killall Dock 2>/dev/null || true

echo "==> ✓ Dock configured"
