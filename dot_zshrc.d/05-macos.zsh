# ~/.zshrc.d/05-macos.zsh
# macOS-specific aliases and helper functions

# ============================================
# Finder helpers
# ============================================
alias showfiles='defaults write com.apple.Finder AppleShowAllFiles -bool true && killall Finder'
alias hidefiles='defaults write com.apple.Finder AppleShowAllFiles -bool false && killall Finder'
alias f='open -a Finder .'

# ============================================
# System helpers
# ============================================
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo "DNS flushed"'
alias emptytrash='rm -rf "${HOME}/.Trash/"* && echo "Trash emptied"'

# Lock screen
alias lock='pmset displaysleepnow'

# Put display to sleep (triggers screensaver + login required)
alias afk='/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend'

# Show/hide desktop icons
alias showdesktop='defaults write com.apple.finder CreateDesktop -bool true && killall Finder'
alias hidedesktop='defaults write com.apple.finder CreateDesktop -bool false && killall Finder'

# ============================================
# Quick Look
# ============================================
alias ql='qlmanage -p'

# ============================================
# Network
# ============================================
# Get local IP
alias localip='ipconfig getifaddr en0'
# Get all IPs
alias ips='ifconfig -a | grep -o "inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)" | awk "{ sub(/inet6? (addr:)? ?/, \"\"); print }"'

# ============================================
# defaults write helper
# Lets you diff before/after changing a setting
# Usage: da (before change), make change in GUI, db (after), ddif
# ============================================
alias da='defaults read > /tmp/defaults_before.txt && echo "Saved defaults snapshot A"'
alias db='defaults read > /tmp/defaults_after.txt  && echo "Saved defaults snapshot B"'
alias ddif='diff /tmp/defaults_before.txt /tmp/defaults_after.txt'

# ============================================
# App management
# ============================================
# Kill an app by name
kapp() {
  local app="${1:?Usage: kapp <AppName>}"
  osascript -e "quit app \"${app}\""
}

# Open app if not already running
oapp() {
  local app="${1:?Usage: oapp <AppName>}"
  open -a "$app"
}
