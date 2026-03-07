#!/bin/bash
# run_once_after_12-post-install.sh
# Prints post-install validation and manual checklist. Runs once per machine.

set -euo pipefail

[[ "$(uname)" != "Darwin" ]] && exit 0

echo ""
echo "══════════════════════════════════════════════"
echo "  POST-INSTALL VALIDATION"
echo "══════════════════════════════════════════════"
echo ""

# Tool status check
TOOLS=(brew chezmoi starship atuin zoxide eza fzf zellij op dockutil fastfetch git)
NAMES=(Homebrew chezmoi Starship Atuin Zoxide eza fzf Zellij "1Password CLI" dockutil fastfetch Git)

echo "  Tool Status:"
echo "  ─────────────────────────────────────────"

pass=0
fail=0
for i in "${!TOOLS[@]}"; do
  if command -v "${TOOLS[$i]}" &>/dev/null; then
    printf "  ✓  %-20s\n" "${NAMES[$i]}"
    (( pass++ )) || true
  else
    printf "  ?  %-20s  (not found)\n" "${NAMES[$i]}"
    (( fail++ )) || true
  fi
done

echo "  ─────────────────────────────────────────"
echo "  ${pass} available, ${fail} not found"
echo ""

# System summary
echo "  System Summary:"
echo "  ─────────────────────────────────────────"
printf "  %-18s %s\n" "Hostname:" "$(scutil --get ComputerName 2>/dev/null || echo 'unknown')"
printf "  %-18s %s\n" "macOS:" "$(sw_vers -productVersion)"
printf "  %-18s %s\n" "Shell:" "${SHELL}"
printf "  %-18s %s\n" "Chezmoi:" "$(chezmoi --version 2>/dev/null | head -1 || echo 'n/a')"
managed="$(chezmoi managed 2>/dev/null | wc -l | tr -d ' ')"
printf "  %-18s %s files\n" "Managed files:" "$managed"
echo "  ─────────────────────────────────────────"

# fastfetch
if command -v fastfetch &>/dev/null; then
  echo ""
  fastfetch
fi

# Manual steps
echo ""
echo "  Manual steps remaining:"
echo ""
echo "  [ ] Open 1Password — verify SSH agent is working"
echo "  [ ] Sign into iCloud and verify Obsidian/sync"
echo "  [ ] Open Raycast and import settings backup"
echo "  [ ] Configure Kap: set global shortcut Cmd+Shift+3"
echo "  [ ] Set desktop wallpaper in System Settings > Wallpaper"
echo "  [ ] Set mouse cursor color in Accessibility > Display"
echo "  [ ] Configure app-specific settings (Slack, Discord)"
echo "  [ ] Restart to complete all system changes"
echo ""
echo "  App Settings Restore Notes:"
echo ""
echo "  Raycast    — Settings > Advanced > Import"
echo "  Ghostty    — Managed by chezmoi (~/.config/ghostty/config)"
echo "  Zellij     — Managed by chezmoi (~/.config/zellij/config.kdl)"
echo "  VS Code    — Settings Sync (sign in with GitHub)"
echo "  Slack      — File > Sign in to another workspace"
echo "  Discord    — Sign in; servers rejoin automatically"
echo "  Obsidian   — Open vault from iCloud Drive"
echo "  Atuin      — Run: atuin login"
echo "  1Password  — Sign in to restore vault access"
echo ""
