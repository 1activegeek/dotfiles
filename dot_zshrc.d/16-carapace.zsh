# ~/.zshrc.d/16-carapace.zsh
# carapace — multi-shell, multi-command argument completer
#
# Bridges completions from zsh, fish, bash, and inshellisense sources.
# Must be sourced AFTER compinit (handled by dot_zshrc loader order).

if command -v carapace &>/dev/null; then
  # Enable completion bridges from multiple shells
  export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'

  # Dim completion category headers
  zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'

  # Load carapace completions
  source <(carapace _carapace)
fi
