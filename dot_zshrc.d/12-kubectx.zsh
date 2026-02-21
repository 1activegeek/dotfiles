# ~/.zshrc.d/12-kubectx.zsh
# kubectx and kubens shortcuts + completions

if command -v kubectx &>/dev/null; then
  alias kctx='kubectx'
fi

if command -v kubens &>/dev/null; then
  alias kns='kubens'
fi

# Load Homebrew-provided completions for kubectx (if present)
if command -v brew &>/dev/null; then
  _kubectx_completion="$(brew --prefix 2>/dev/null)/etc/kubectx.zsh"
  if [[ -f "$_kubectx_completion" ]]; then
    # shellcheck source=/dev/null
    source "$_kubectx_completion"
  fi
  unset _kubectx_completion
fi
