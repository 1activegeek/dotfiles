# ~/.zshrc.d/13-sudo.zsh
# Esc-Esc widget: prepend (or toggle) sudo on the current command line
#
# Press Escape twice to prepend "sudo" to the current or last command.
# Press Escape twice again to remove it (toggle).

sudo-command-line() {
  # If command buffer is empty, pull the last command from history
  [[ -z "$BUFFER" ]] && zle up-history

  if [[ "$LBUFFER" == sudo\ * ]]; then
    # Already has sudo — remove it
    LBUFFER="${LBUFFER#sudo }"
  else
    # Prepend sudo
    LBUFFER="sudo $LBUFFER"
  fi
}

zle -N sudo-command-line

# Bind to Escape Escape
bindkey '\e\e' sudo-command-line
