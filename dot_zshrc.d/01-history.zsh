# ~/.zshrc.d/01-history.zsh
# ZSH history configuration + Atuin initialisation
#
# ZSH still needs HISTSIZE/SAVEHIST/HISTFILE for built-in `history` command.
# Atuin replaces Ctrl+R search with its own fuzzy database.

# ============================================
# ZSH history settings
# ============================================
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt EXTENDED_HISTORY       # Write timestamps to history
setopt HIST_EXPIRE_DUPS_FIRST # When trimming, expire duplicates first
setopt HIST_IGNORE_DUPS       # Don't store consecutive duplicate entries
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate entries from history
setopt HIST_IGNORE_SPACE      # Don't store entries starting with a space
setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks before storing
setopt HIST_VERIFY            # Show history expansion before executing
setopt SHARE_HISTORY          # Share history across all sessions
setopt APPEND_HISTORY         # Append to history file (don't overwrite)

# Convenience aliases
alias h='history 1'
alias hs='history | grep'

# ============================================
# Atuin — enhanced shell history
# ============================================
# Replaces Ctrl+R with a searchable, syncable history database.
if command -v atuin &>/dev/null; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi
