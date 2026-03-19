# ~/.zshrc.d/07-1password.zsh
# 1Password CLI helpers and SSH agent configuration

if command -v op &>/dev/null; then
  # ============================================
  # 1Password SSH Agent
  # ============================================
  # Redirect SSH auth to the 1Password agent socket.
  # Requires: 1Password > Settings > Developer > Use SSH Agent
  export SSH_AUTH_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

  # ============================================
  # Aliases
  # ============================================
  # Sign in to 1Password account
  alias opsignin='eval "$(op signin)"'

  # ============================================
  # Helper functions
  # ============================================

  # Get a field from a 1Password item
  # Usage: opget "Item Name" fieldname
  opget() {
    local item="${1:?Usage: opget <item-name> [field]}"
    local field="${2:-password}"
    op item get "$item" --fields "$field" 2>/dev/null
  }

  # Copy a 1Password item's password to clipboard
  # Usage: opcopy "Item Name"
  opcopy() {
    local item="${1:?Usage: opcopy <item-name>}"
    op item get "$item" --fields password --reveal 2>/dev/null | pbcopy
    echo "Copied password for '${item}' to clipboard."
  }

  # Sync local SSH config back to 1Password
  # Usage: op-sync-ssh
  op-sync-ssh() {
    if [[ ! -f "${HOME}/.ssh/config" ]]; then
      echo "Error: ~/.ssh/config not found"
      return 1
    fi
    op item edit "SSH Config" --vault "Private" \
      notesPlain="$(cat "${HOME}/.ssh/config")"
    echo "SSH config synced to 1Password"
  }

  # Sync local kube config back to 1Password
  # Usage: op-sync-kube
  op-sync-kube() {
    if [[ ! -f "${HOME}/.kube/config" ]]; then
      echo "Error: ~/.kube/config not found"
      return 1
    fi
    op item edit "Kube Config" --vault "Private" \
      notesPlain="$(cat "${HOME}/.kube/config")"
    echo "Kube config synced to 1Password"
  }

  # Add a new SSH host entry to ~/.ssh/config
  # Usage: ssh-add-host
  ssh-add-host() {
    local alias host user port keyfile
    read -rp "SSH alias (shortname): " alias
    read -rp "Hostname or IP:        " host
    read -rp "User [$(whoami)]:      " user
    user="${user:-$(whoami)}"
    read -rp "Port [22]:             " port
    port="${port:-22}"
    read -rp "IdentityFile [default]: " keyfile

    {
      printf "\nHost %s\n" "$alias"
      printf "  HostName %s\n" "$host"
      printf "  User %s\n" "$user"
      printf "  Port %s\n" "$port"
      [[ -n "$keyfile" ]] && printf "  IdentityFile %s\n" "$keyfile"
    } >> "${HOME}/.ssh/config"

    echo "Added Host '${alias}' to ~/.ssh/config"
    echo "Tip: Run 'chezmoi re-add ~/.ssh/config' to track the change."
  }
fi
