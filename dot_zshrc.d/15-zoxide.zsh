# ~/.zshrc.d/15-zoxide.zsh
# zoxide — smart cd with frecency ranking
#
# Replaces `cd` with `z`, learning your most-visited directories.
# Usage:
#   z foo      — jump to the most frecent dir matching 'foo'
#   z foo bar  — jump to dir matching both 'foo' and 'bar'
#   zi         — interactive selection with fzf
#   z -        — go to previous directory

if command -v zoxide &>/dev/null; then
  # Initialise zoxide, replacing cd with z
  eval "$(zoxide init zsh)"

  # Keep the original cd available as 'cdd' for edge cases
  alias cdd='builtin cd'
fi
