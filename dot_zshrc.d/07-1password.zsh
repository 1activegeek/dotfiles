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

  # Write a file into the notesPlain field of a Secure Note (vault: Private).
  # The content goes to op through a pipe (JSON on stdin), never as a command
  # argument, so other processes cannot read it from `ps`. Creates the note if
  # it does not exist. Usage: _op_note_put "<note title>" <file>
  _op_note_put() {
    local item="$1" file="$2"
    command -v jq &>/dev/null || { echo "Error: jq is required" >&2; return 1; }
    [[ -f "$file" ]] || { echo "Error: $file not found" >&2; return 1; }
    # Strip trailing newlines (chezmoi templates add one back on apply).
    local set_note='($c | sub("\n+$"; "")) as $v
      | if any(.fields[]?; .id == "notesPlain")
        then (.fields[] | select(.id == "notesPlain") | .value) = $v
        else .fields += [{"id": "notesPlain", "type": "STRING", "purpose": "NOTES", "label": "notesPlain", "value": $v}]
        end'
    if op item get "$item" --vault "Private" &>/dev/null; then
      op item get "$item" --vault "Private" --format json \
        | jq --rawfile c "$file" "$set_note" \
        | op item edit "$item" --vault "Private" >/dev/null
    else
      op item template get "Secure Note" \
        | jq --rawfile c "$file" --arg t "$item" ".title = \$t | $set_note" \
        | op item create --vault "Private" - >/dev/null
    fi
  }

  # Sync local SSH config back to 1Password
  # Usage: op-sync-ssh
  op-sync-ssh() {
    _op_note_put "SSH Config" "${HOME}/.ssh/config" && echo "SSH config synced to 1Password"
  }

  # Sync local kube config back to 1Password
  # Usage: op-sync-kube
  op-sync-kube() {
    _op_note_put "Kube Config" "${HOME}/.kube/config" && echo "Kube config synced to 1Password"
  }

  # Push private files to their 1Password Secure Notes (vault: Private).
  # The file → note list lives in .chezmoidata/private_notes.yaml (the public
  # repo holds only note names). Creates any note that does not exist yet.
  # Usage: op-sync-private              # every listed file
  #        op-sync-private <target>...  # e.g. .claude/settings.json
  op-sync-private() {
    command -v jq &>/dev/null || { echo "Error: jq is required"; return 1; }
    local map target item file n=0 failed=0
    map="$(chezmoi data --format json | jq -r '.private_notes[]? | "\(.target)\t\(.item)"')" || return 1
    [[ -n "$map" ]] || { echo "Error: no private_notes in chezmoi data"; return 1; }
    while IFS=$'\t' read -r target item; do
      if (( $# )) && ! (( ${@[(Ie)$target]} )); then continue; fi
      file="${HOME}/${target}"
      if [[ ! -f "$file" ]]; then echo "  skip (no file): ~/${target}"; continue; fi
      if _op_note_put "$item" "$file"; then
        echo "  synced: ${item}"; n=$((n + 1))
      else
        echo "  FAILED: ${item}"; failed=$((failed + 1))
      fi
    done <<< "$map"
    echo "${n} private file(s) synced to 1Password, ${failed} failed."
    (( failed == 0 ))
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
