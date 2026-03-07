#!/bin/bash
# run_once_after_11-dock.sh
# Configures the macOS Dock via dockutil. Runs once per machine.
set -euo pipefail
[[ "$(uname)" != "Darwin" ]] && exit 0
if ! command -v dockutil &>/dev/null; then
  echo "    ⚠ dockutil not installed, skipping"
  exit 0
fi

echo "==> Configuring Dock..."

# ============================================
# Remove unwanted items
# ============================================
echo "    Removing unwanted Dock items"

DOCK_REMOVE=(
  "Launchpad"
  "Maps"
  "FaceTime"
  "Contacts"
  "Notes"
  "Freeform"
  "TV"
  "News"
  "Numbers"
  "Keynote"
  "Pages"
  "App Store"
  "System Settings"
  "Google Chrome"
  "Firefox"
  "Microsoft Outlook"
  "Microsoft Word"
  "Microsoft Excel"
  "Microsoft PowerPoint"
  "Microsoft OneNote"
  "Self Service"
  "Terminal"
)

for item in "${DOCK_REMOVE[@]}"; do
  if dockutil --find "$item" &>/dev/null 2>&1; then
    dockutil --remove "$item" --no-restart
    echo "    Removed: $item"
  fi
done

# ============================================
# Add desired items in order
# ============================================
echo "    Adding Dock items"

# Format: "AppName|/path/to/App.app"
# Apps are added left-to-right (each appended to end of apps section)
DOCK_ADD=(
  "Safari|/System/Applications/Safari.app"
  "Brave Browser|/Applications/Brave Browser.app"
  "Mail|/System/Applications/Mail.app"
  "Messages|/System/Applications/Messages.app"
  "Calendar|/System/Applications/Calendar.app"
  "Reminders|/System/Applications/Reminders.app"
  "zoom.us|/Applications/zoom.us.app"
  "Slack|/Applications/Slack.app"
  "Obsidian|/Applications/Obsidian.app"
  "Discord|/Applications/Discord.app"
  "Music|/System/Applications/Music.app"
  "Claude|/Applications/Claude.app"
  "Perplexity|/Applications/Perplexity.app"
  "OpenCode|/Applications/OpenCode.app"
  "Visual Studio Code|/Applications/Visual Studio Code.app"
  "Ghostty|/Applications/Ghostty.app"
)

for entry in "${DOCK_ADD[@]}"; do
  IFS='|' read -r name path <<< "$entry"

  # Try the exact path first; if Safari lives in an alternate location, handle it
  if [[ ! -e "$path" ]] && [[ "$name" == "Safari" ]]; then
    path="/Applications/Safari.app"
  fi

  if [[ -e "$path" ]]; then
    if ! dockutil --find "$name" &>/dev/null 2>&1; then
      dockutil --add "$path" --label "$name" --section apps --no-restart
      echo "    Added: $name"
    fi
  else
    echo "    ⚠ App not found, skipping Dock entry: $name ($path)"
  fi
done

# ============================================
# Add "Others" section (folders)
# ============================================
echo "    Adding Dock folder items"

# Applications folder — grid view
if ! dockutil --find "Applications" &>/dev/null 2>&1; then
  dockutil --add "/Applications" \
    --label "Applications" \
    --view grid \
    --display folder \
    --sort name \
    --section others \
    --no-restart
  echo "    Added: Applications folder"
fi

# Downloads folder — list view
if ! dockutil --find "Downloads" &>/dev/null 2>&1; then
  dockutil --add "${HOME}/Downloads" \
    --label "Downloads" \
    --view list \
    --display folder \
    --sort dateadded \
    --section others \
    --no-restart
  echo "    Added: Downloads folder"
fi

# ============================================
# Single Dock restart (apply all changes at once)
# ============================================
echo "    Restarting Dock to apply changes"
killall Dock 2>/dev/null || true

echo "==> ✓ Dock configured"
