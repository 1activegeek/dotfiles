# ~/.zshrc.d/14-fzf.zsh
# fzf (fuzzy finder) configuration and key bindings

if command -v fzf &>/dev/null; then
  # ============================================
  # Default options
  # ============================================
  # Catppuccin Mocha theme (matches your live .zshrc)
  export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A \
--color=border:#6C7086,label:#CDD6F4 \
--height 40% \
--layout=reverse \
--border \
--info=inline \
--bind='ctrl-/:toggle-preview'"

  # ============================================
  # Default command (use fd if available, else find)
  # ============================================
  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi

  # ============================================
  # Key bindings and completion
  # ============================================
  # Load fzf shell integration (Ctrl+T, Ctrl+R, Alt+C)
  source <(fzf --zsh) 2>/dev/null

  # ============================================
  # Helper functions
  # ============================================

  # Interactive git branch checkout with fzf
  fbr() {
    local branch
    branch=$(git branch --all | grep -v HEAD | fzf +s +m -e) &&
    git checkout "$(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")"
  }

  # Interactive process kill with fzf
  fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
    [[ -n "$pid" ]] && echo "$pid" | xargs kill -"${1:-9}"
  }
fi
