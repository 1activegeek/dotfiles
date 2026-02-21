# ~/.zshrc.d/02-aliases.zsh
# Generic shell aliases

# ============================================
# Navigation
# ============================================
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# ============================================
# File listing (eza replaces ls)
# ============================================
if command -v eza &>/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -la --icons --git'
  alias la='eza -a --icons'
  alias l='eza -1 --icons'
  alias lt='eza --tree --icons --level=2'
  alias lta='eza --tree --icons --level=3 -a'
else
  # Fallback to standard ls with colors
  alias ls='ls -G'
  alias ll='ls -lahG'
  alias la='ls -AG'
  alias l='ls -CG'
fi

# ============================================
# Shell management
# ============================================
alias reload='exec zsh'
alias path='echo -e "${PATH//:/\\n}"'
alias cls='clear'

# ============================================
# Safety
# ============================================
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
alias mkdir='mkdir -pv'

# ============================================
# Misc
# ============================================
alias j='jobs -l'
alias ports='lsof -i -n -P | grep LISTEN'
alias please='sudo $(fc -ln -1)'
alias week='date +%V'
alias timestamp='date "+%Y-%m-%d %H:%M:%S"'

# Quick edit common config files
alias zshrc='${EDITOR:-code} ~/.zshrc'
alias zshd='${EDITOR:-code} ~/.zshrc.d/'
