#!/bin/bash
# run_once_after_10-macos-defaults.sh
# Applies macOS system preferences. Runs once per machine.
set -euo pipefail
[[ "$(uname)" != "Darwin" ]] && exit 0

echo "==> Applying macOS defaults..."

# Close System Settings to prevent it from overriding our changes
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

# ============================================
# Dock
# ============================================
echo "    Dock settings"

# Icon size (normal and magnified)
defaults write com.apple.dock tilesize          -float 60

# Minimize to app icon (not separate tile)
defaults write com.apple.dock minimize-to-application -bool true

# Auto-hide the Dock
defaults write com.apple.dock autohide          -bool true

# Hide recently-used apps section in Dock
defaults write com.apple.dock show-recents      -bool false

# Don't rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces        -bool false

# Show indicator lights for open apps
defaults write com.apple.dock show-process-indicators -bool true

# ============================================
# Trackpad
# ============================================
echo "    Trackpad settings"

# Natural scrolling: ON (keep the default macOS behavior)
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool true

# Tap to click (enabled for current user and login screen)
defaults write com.apple.AppleMultitouchTrackpad Clicking -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Tracking speed
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.5

# Enable three-finger drag
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# ============================================
# Keyboard
# ============================================
echo "    Keyboard settings"

# Enable full keyboard access (Tab to move focus between controls)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Disable press-and-hold for keys (enable key repeat)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Key repeat rate (lower = faster)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# ============================================
# Finder
# ============================================
echo "    Finder settings"

# Show internal hard drives on desktop
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true

# Show status bar at bottom
defaults write com.apple.finder ShowStatusBar -bool true

# Show path bar at bottom
defaults write com.apple.finder ShowPathbar -bool true

# Default new Finder window to Downloads
defaults write com.apple.finder NewWindowTarget   -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Downloads/"

# Search current folder by default (not "This Mac")
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Remove items from Trash after 30 days
defaults write com.apple.finder FXRemoveOldTrashItems -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Don't show warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Don't write .DS_Store files on network volumes or USB
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores    -bool true

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Use column view in Finder by default (options: icnv clmv lisv Nlsv)
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# ============================================
# Screenshots
# ============================================
echo "    Screenshot settings"

# Save screenshots to ~/Desktop
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

# Save in PNG format (options: BMP GIF JPG PDF TIFF PNG)
defaults write com.apple.screencapture type -string "png"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# Disable built-in screenshot shortcuts so Kap/Shottr can own them.
# Shortcut IDs:
#   28 = Cmd+Shift+3  (save screenshot to file)
#   29 = Cmd+Shift+4  (save selection to file)  + Ctrl variant
#   30 = Cmd+Ctrl+Shift+3  (copy to clipboard)
#   31 = Cmd+Ctrl+Shift+4  (copy selection)
for hotkey_id in 28 29 30 31; do
  /usr/libexec/PlistBuddy \
    -c "Set :AppleSymbolicHotKeys:${hotkey_id}:enabled false" \
    "${HOME}/Library/Preferences/com.apple.symbolichotkeys.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy \
    -c "Add :AppleSymbolicHotKeys:${hotkey_id}:enabled bool false" \
    "${HOME}/Library/Preferences/com.apple.symbolichotkeys.plist" 2>/dev/null || true
done
# Activate the changes (requires reactivateSettings on Sonoma+)
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
echo "==> ✓ Built-in screenshot shortcuts disabled (Kap/Shottr can now own Cmd+Shift+3/4)"

# ============================================
# Contacts
# ============================================
echo "    Contacts settings"

# Don't prefer nicknames over real names
defaults write NSGlobalDomain NSPersonNameDefaultShouldPreferNicknamesPreference -int 0

# ============================================
# Safari
# ============================================
echo "    Safari settings"

# Safari defaults can fail on fresh systems before Safari has initialized its
# preference container. Continue without failing the full bootstrap.
if ! defaults write com.apple.Safari.SandboxBroker ShowDevelopMenu -bool true; then
  echo "    ⚠ Safari defaults skipped: could not set ShowDevelopMenu"
fi
if ! defaults write com.apple.Safari IncludeDevelopMenu -bool true; then
  echo "    ⚠ Safari defaults skipped: could not set IncludeDevelopMenu"
fi
if ! defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true; then
  echo "    ⚠ Safari defaults skipped: could not set WebKitDeveloperExtrasEnabledPreferenceKey"
fi
if ! defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true; then
  echo "    ⚠ Safari defaults skipped: could not set ShowFullURLInSmartSearchField"
fi
if ! defaults write com.apple.Safari AutoOpenSafeDownloads -bool false; then
  echo "    ⚠ Safari defaults skipped: could not set AutoOpenSafeDownloads"
fi
if ! defaults write com.apple.Safari AlwaysRestoreSessionAtLaunch -bool true; then
  echo "    ⚠ Safari defaults skipped: could not set AlwaysRestoreSessionAtLaunch"
fi

# ============================================
# Audio
# ============================================
echo "    Audio settings"

# Play feedback sound when volume is changed
defaults write NSGlobalDomain com.apple.sound.beep.feedback -int 1

# ============================================
# Appearance
# ============================================
echo "    Appearance settings"

# Dark mode
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# Green button = Fill (not Full Screen)
defaults write NSGlobalDomain NSZoomButtonMenuOption -int 2

# Disable double-click titlebar to minimize
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false

# Small sidebar icon size (1=small, 2=medium, 3=large)
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1

# ============================================
# Window Manager
# ============================================
echo "    Window Manager settings"

# Disable click wallpaper to show desktop
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

# No margins between tiled windows
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

# Disable window tiling by dragging to screen edge
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false

# Hide desktop items when clicking wallpaper
defaults write com.apple.WindowManager HideDesktop -bool true

# ============================================
# Menu Bar / UI
# ============================================
echo "    Menu bar / UI settings"

# Always show scrollbars
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode  -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint  -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Disable the "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# ============================================
# Menu Bar Clock
# ============================================
echo "    Menu bar clock settings"

# Hide date from menu bar clock
defaults write com.apple.menuextra.clock ShowDate -int 0

# Hide day of week from menu bar clock
defaults write com.apple.menuextra.clock ShowDayOfWeek -int 0

# ============================================
# Control Center / Menu Bar Icons
# ============================================
echo "    Control Center settings"

# Hide battery from menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool false

# Hide WiFi from menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool false

# Hide Focus modes from menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible FocusModes" -bool false

# Hide Now Playing from menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible NowPlaying" -bool false

# ============================================
# Activity Monitor
# ============================================
echo "    Activity Monitor settings"

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# ============================================
# Misc / Power
# ============================================
echo "    Miscellaneous settings"

# Disable automatic capitalization
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable smart dashes
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable smart quotes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# ============================================
# TODO items (require manual configuration or deeper research)
# ============================================
# - Mouse cursor color: Use System Settings > Accessibility > Display > Pointer
#   to set a lighter cursor color. No reliable `defaults write` key found.
# - Desktop wallpaper folders: System Settings > Wallpaper > Add Folder
#   Set style to "Fit to Screen". Not reliably automatable via defaults write.
# - Catppuccin theme: App-by-app. Ghostty: set in config. Zellij: set in config.
#   Terminal.app themes require importing a profile.
# - Kap shortcut: Open Kap > Preferences > Record shortcut: Cmd+Shift+3
#   (system shortcuts are now disabled by this script)

# ============================================
# Restart affected services to apply changes
# ============================================
echo "    Restarting Dock, Finder, and SystemUIServer"
killall Dock          2>/dev/null || true
killall Finder        2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

echo "==> ✓ macOS defaults applied"
echo "    ⚠ Some settings may require a logout/restart to fully take effect."
