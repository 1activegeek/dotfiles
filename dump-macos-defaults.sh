#!/bin/bash
# dump-macos-defaults.sh
# Dumps macOS defaults for key domains into a structured, diffable format.
# Run on both a fresh install and a configured Mac, then diff the outputs.
#
# Usage:
#   ./dump-macos-defaults.sh > defaults-fresh.txt    # on fresh Tahoe install
#   ./dump-macos-defaults.sh > defaults-current.txt  # on configured Mac
#   diff -u defaults-fresh.txt defaults-current.txt  # compare
set -euo pipefail

# Domains to dump, grouped by category.
# These cover the areas most commonly customized.
DOMAINS=(
  # Global / system-wide
  NSGlobalDomain

  # Dock & Mission Control
  com.apple.dock
  com.apple.spaces

  # Finder & Desktop
  com.apple.finder
  com.apple.desktopservices

  # Trackpad & Mouse
  com.apple.AppleMultitouchTrackpad
  com.apple.driver.AppleBluetoothMultitouch.trackpad
  com.apple.AppleMultitouchMouse
  com.apple.driver.AppleBluetoothMultitouch.mouse

  # Keyboard & Input
  com.apple.HIToolbox

  # Screenshots
  com.apple.screencapture

  # Menu bar & UI
  com.apple.menuextra.clock
  com.apple.controlcenter

  # Safari
  com.apple.Safari
  com.apple.Safari.SandboxBroker

  # Activity Monitor
  com.apple.ActivityMonitor

  # Launch Services (quarantine dialogs, etc.)
  com.apple.LaunchServices

  # Contacts
  com.apple.AddressBook

  # Spotlight
  com.apple.Spotlight

  # TextEdit
  com.apple.TextEdit

  # Disk Utility
  com.apple.DiskUtility

  # Time Machine
  com.apple.TimeMachine

  # Bluetooth
  com.apple.BluetoothAudioAgent

  # Sound
  com.apple.sound.beep
  com.apple.systemsound

  # Login window
  com.apple.loginwindow

  # Software Update
  com.apple.SoftwareUpdate
  com.apple.commerce

  # Terminal
  com.apple.Terminal

  # Print
  com.apple.print.PrintingPrefs

  # Universal Access / Accessibility
  com.apple.universalaccess
  com.apple.Accessibility
)

echo "# macOS Defaults Dump"
echo "# Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "# Host: $(scutil --get ComputerName 2>/dev/null || hostname)"
echo "# macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
echo "# User: $(whoami)"
echo ""

for domain in "${DOMAINS[@]}"; do
  echo "###############################################################################"
  echo "# DOMAIN: ${domain}"
  echo "###############################################################################"
  if defaults read "${domain}" 2>/dev/null; then
    :
  else
    echo "# (domain not found or empty)"
  fi
  echo ""
done

# Also dump symbolic hotkeys (screenshot shortcuts, etc.)
echo "###############################################################################"
echo "# SYMBOLIC HOTKEYS (com.apple.symbolichotkeys)"
echo "###############################################################################"
if defaults read com.apple.symbolichotkeys 2>/dev/null; then
  :
else
  echo "# (not found)"
fi
echo ""

# Current-host defaults for NSGlobalDomain (tap-to-click, etc.)
echo "###############################################################################"
echo "# CURRENT-HOST NSGlobalDomain"
echo "###############################################################################"
if defaults -currentHost read NSGlobalDomain 2>/dev/null; then
  :
else
  echo "# (not found)"
fi
