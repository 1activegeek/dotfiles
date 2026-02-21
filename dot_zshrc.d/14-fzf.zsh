# ~/.zshrc.d/14-fzf.zsh
# fzf (fuzzy finder) configuration and key bindings

if command -v fzf &>/dev/null; then
  # ============================================
  # Default options
  # ============================================
  export FZF_DEFAULT_OPTS="
    --height 40%
    --layout=reverse
    --border
    --info=inline
    --bind='ctrl-/:toggle-preview'
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
  "
  # ^^ Catppuccin Mocha theme

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
