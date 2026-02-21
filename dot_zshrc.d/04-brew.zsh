# ~/.zshrc.d/04-brew.zsh
# Homebrew aliases and helpers

# ============================================
# Basic aliases
# ============================================
alias bi='brew install'
alias bic='brew install --cask'
alias bu='brew update && brew upgrade'
alias buu='brew update && brew upgrade --greedy'
alias bs='brew search'
alias bl='brew list'
alias blc='brew list --cask'
alias binfo='brew info'
alias bclean='brew cleanup --prune=all'
alias bdoctor='brew doctor'
alias bout='brew outdated'

# Dump installed packages to ~/Brewfile
alias bdump='brew bundle dump --file="${HOME}/Brewfile" --force --describe'

# ============================================
# Homebrew autoupdate
# ============================================
alias baustart='brew autoupdate start 86400 --upgrade --cleanup --enable-notification'
alias baukill='brew autoupdate delete'
alias baustatus='brew autoupdate status'
