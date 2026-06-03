#!/usr/bin/env bash
# op-session-setup.sh — First-time setup for the op-session skill
#
# This script:
#   1. Verifies 1Password CLI and python3 are installed and desktop integration works
#   2. Creates a 1Password Service Account, or configures an existing SA token,
#      or points to an existing vault item that already holds the SA token
#   3. Stores the SA token in your personal vault (options 1 & 2 only)
#   4. Creates the config file at ~/.config/op-session/config
#
# Run this once per machine. After setup, use op-session.sh for daily use.

set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "→ $*"; }
warn() { echo "⚠ $*" >&2; }
ask() {
    local prompt="$1" var="$2" default="${3:-}"
    local input
    if [[ -n "$default" ]]; then
        read -rp "$prompt [$default]: " input
        printf -v "$var" '%s' "${input:-$default}"
    else
        read -rp "$prompt: " "$var"
    fi
}

CONFIG_DIR="${HOME}/.config/op-session"
CONFIG_FILE="${CONFIG_DIR}/config"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  1Password Session Manager — First Setup"
echo "============================================"
echo ""

# ── Step 1: Check prerequisites ───────────────────────────────────────────────

info "Checking prerequisites..."

if ! command -v op &>/dev/null; then
    die "1Password CLI (op) is not installed.
Install it: https://developer.1password.com/docs/cli/get-started/"
fi

if ! command -v python3 &>/dev/null; then
    die "python3 is required but not installed.
Install it via Homebrew: brew install python3"
fi

OP_VERSION=$(op --version 2>/dev/null || echo "unknown")
info "1Password CLI version: $OP_VERSION"

# Test biometric/desktop integration
info "Testing 1Password desktop integration (you may see a biometric prompt)..."
if ! op account list &>/dev/null; then
    die "Cannot communicate with 1Password desktop app.
Ensure:
  1. 1Password 8 desktop app is running
  2. Settings → Developer → 'Integrate with 1Password CLI' is ON
  3. You're signed in to the desktop app"
fi
info "Desktop integration working."

# ── Step 2: Determine vault and SA token ──────────────────────────────────────

echo ""
echo "This setup configures a 1Password Service Account token so it can be"
echo "fetched with one biometric prompt per session."
echo ""
echo "You have three options:"
echo "  1. I already have a Service Account token — let me paste it"
echo "  2. I need help creating a Service Account"
echo "  3. My SA token is already stored in 1Password — use an existing vault item"
echo ""

ask "Choose [1, 2, or 3]" CHOICE
case "$CHOICE" in
    1|2|3) ;;
    *) die "Invalid choice '$CHOICE'. Please enter 1, 2, or 3." ;;
esac

SA_TOKEN=""
SA_REF=""

if [[ "$CHOICE" == "2" ]]; then
    echo ""
    echo "To create a Service Account:"
    echo "  1. Go to https://my.1password.com → Settings → Service Accounts"
    echo "  2. Create a new service account"
    echo "  3. Give it a name like 'Claude Code Agent'"
    echo "  4. Grant it READ access to the vault(s) containing secrets Claude needs"
    echo "  5. Copy the service account token"
    echo ""
    echo "IMPORTANT: Only grant READ access, and only to the specific vault(s)"
    echo "containing the secrets the agent needs (e.g., API tokens, not passwords)."
    echo ""
    ask "Paste your Service Account token" SA_TOKEN
elif [[ "$CHOICE" == "3" ]]; then
    echo ""
    echo "Enter the name of the 1Password item that contains your SA token."
    ask "Item name" ITEM_NAME "Claude-SA-Token"

    info "Searching for '$ITEM_NAME' across all vaults..."
    # Pass item name via sys.argv to avoid shell injection from user input
    MATCH_LINES=$(op item list --format=json | python3 -c "
import sys, json
try:
    items = json.load(sys.stdin)
except Exception as e:
    sys.stderr.write('JSON parse error: ' + str(e) + '\n')
    sys.exit(1)
name = sys.argv[1].lower()
matches = [i for i in items if i['title'].lower() == name]
for m in matches:
    print(m['id'] + '\t' + m['vault']['name'] + '\t' + m['title'])
" "$ITEM_NAME") || die "Failed to list 1Password items."

    MATCH_COUNT=$(echo "$MATCH_LINES" | grep -c $'.' 2>/dev/null || echo "0")

    if [[ -z "$MATCH_LINES" || "$MATCH_COUNT" -eq 0 ]]; then
        die "No item named '$ITEM_NAME' found in any vault.
Verify the item exists: op item list | grep -i '$ITEM_NAME'"
    elif [[ "$MATCH_COUNT" -eq 1 ]]; then
        ITEM_ID=$(echo "$MATCH_LINES" | awk -F'\t' '{print $1}')
        VAULT_NAME=$(echo "$MATCH_LINES" | awk -F'\t' '{print $2}')
        ITEM_TITLE=$(echo "$MATCH_LINES" | awk -F'\t' '{print $3}')
        info "Found: '$ITEM_TITLE' in vault '$VAULT_NAME'"
    else
        echo ""
        echo "Multiple items named '$ITEM_NAME' found:"
        i=1
        while IFS=$'\t' read -r id vault title; do
            echo "  $i. $title  (vault: $vault)"
            (( i++ ))
        done <<< "$MATCH_LINES"
        echo ""
        ask "Which item? (enter number)" PICK
        ITEM_ID=$(echo "$MATCH_LINES" | awk -F'\t' -v n="$PICK" 'NR==n{print $1}')
        VAULT_NAME=$(echo "$MATCH_LINES" | awk -F'\t' -v n="$PICK" 'NR==n{print $2}')
        ITEM_TITLE=$(echo "$MATCH_LINES" | awk -F'\t' -v n="$PICK" 'NR==n{print $3}')
        [[ -z "$ITEM_ID" ]] && die "Invalid selection."
        info "Selected: '$ITEM_TITLE' in vault '$VAULT_NAME'"
    fi

    # Determine which field holds the token.
    # stderr goes to the terminal so op/python3 errors are visible.
    # Exit codes: 0=found one, 1=no usable field, 2=multiple candidates (tab-separated).
    info "Inspecting fields of '$ITEM_TITLE'..."
    FIELD_EXIT=0
    FIELD_NAME=$(op item get "$ITEM_ID" --format=json | python3 -c "
import sys, json
try:
    item = json.load(sys.stdin)
except Exception as e:
    sys.stderr.write('JSON parse error: ' + str(e) + '\n')
    sys.exit(1)
fields = item.get('fields', [])
preferred = ['credential', 'password', 'token']
candidates = []
for pref in preferred:
    for f in fields:
        label = (f.get('label') or f.get('id') or '').lower()
        if label == pref and f.get('value'):
            candidates.append(label)
            break
if len(candidates) == 1:
    print(candidates[0])
elif len(candidates) > 1:
    print('\t'.join(candidates))
    sys.exit(2)
else:
    skip = {'notesPlain', 'type', 'uuid', ''}
    for f in fields:
        label = (f.get('label') or f.get('id') or '').lower()
        if label not in skip and f.get('value'):
            print(label)
            sys.exit(0)
    sys.exit(1)
") || FIELD_EXIT=$?

    if [[ $FIELD_EXIT -eq 1 ]]; then
        die "Could not find a usable field in '$ITEM_TITLE'. Check the item has a non-empty credential/password/token field."
    elif [[ $FIELD_EXIT -eq 2 ]]; then
        echo ""
        echo "Multiple candidate fields found: $FIELD_NAME"
        ask "Which field name to use?" FIELD_NAME
    fi

    SA_REF="op://${VAULT_NAME}/${ITEM_TITLE}/${FIELD_NAME}"
    info "Secret reference: $SA_REF"

    # Validate by reading the token back
    info "Validating token (biometric prompt expected)..."
    TEST_TOKEN=$(op read "$SA_REF" 2>&1) || {
        die "Could not read '$SA_REF'.
Error: $TEST_TOKEN
Verify the item and field are correct."
    }
    VAULT_LIST=$(OP_SERVICE_ACCOUNT_TOKEN="$TEST_TOKEN" op vault list --format=json 2>&1) || {
        die "Token validation failed. The SA token may be invalid or expired.
Error: $VAULT_LIST"
    }
    VAULT_COUNT=$(echo "$VAULT_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
    info "Token valid. Service account has access to $VAULT_COUNT vault(s)."
else
    ask "Paste your Service Account token" SA_TOKEN
fi

if [[ "$CHOICE" != "3" ]]; then
    if [[ -z "$SA_TOKEN" || ${#SA_TOKEN} -lt 20 ]]; then
        die "That doesn't look like a valid service account token."
    fi

    # Validate the token
    info "Validating service account token..."
    VAULT_LIST=$(OP_SERVICE_ACCOUNT_TOKEN="$SA_TOKEN" op vault list --format=json 2>&1) || {
        die "Token validation failed. Error: $VAULT_LIST"
    }

    VAULT_COUNT=$(echo "$VAULT_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
    info "Token valid. Service account has access to $VAULT_COUNT vault(s)."
fi

# ── Step 3: Store the token in 1Password ──────────────────────────────────────

if [[ "$CHOICE" != "3" ]]; then
    echo ""
    info "Now storing the SA token in your personal 1Password vault."
    info "This way it's protected by biometric auth and never stored on disk in plain text."
    echo ""

    # List available vaults for the user to choose
    info "Your available vaults:"
    VAULT_JSON=$(op vault list --format=json 2>/dev/null || echo "[]")
    echo "$VAULT_JSON" | python3 -c "
import sys, json
vaults = json.load(sys.stdin)
for i, v in enumerate(vaults):
    print(f\"  {i+1}. {v['name']}\")" 2>/dev/null || {
        info "  (Could not list vaults. You'll need to enter the vault name manually.)"
    }

    echo ""
    ask "Which vault? (enter number or name)" VAULT_INPUT "Private"

    # Resolve number to vault name if user entered a digit
    if [[ "$VAULT_INPUT" =~ ^[0-9]+$ ]]; then
        VAULT_NAME=$(echo "$VAULT_JSON" | python3 -c "
import sys, json
vaults = json.load(sys.stdin)
idx = int('$VAULT_INPUT') - 1
print(vaults[idx]['name']) if 0 <= idx < len(vaults) else sys.exit(1)" 2>/dev/null) || \
            die "Invalid vault number: $VAULT_INPUT"
    else
        VAULT_NAME="$VAULT_INPUT"
    fi
    info "Using vault: $VAULT_NAME"
    ask "Item name for the SA token?" ITEM_NAME "Claude-SA-Token"

    # Check if item already exists
    if op item get "$ITEM_NAME" --vault="$VAULT_NAME" &>/dev/null 2>&1; then
        warn "Item '$ITEM_NAME' already exists in vault '$VAULT_NAME'."
        ask "Overwrite it? (y/n)" OVERWRITE "n"
        if [[ "$OVERWRITE" == "y" ]]; then
            op item edit "$ITEM_NAME" --vault="$VAULT_NAME" \
                "credential=$SA_TOKEN" &>/dev/null || die "Failed to update item."
            info "Updated existing item."
        else
            info "Keeping existing item. Make sure it contains the correct SA token."
        fi
    else
        CREATE_ERR=$(op item create \
            --category="API Credential" \
            --title="$ITEM_NAME" \
            --vault="$VAULT_NAME" \
            "credential=$SA_TOKEN" 2>&1) || die "Failed to create item in vault.\nError: $CREATE_ERR"
        info "SA token stored as '$ITEM_NAME' in vault '$VAULT_NAME'."
    fi

    # Build the op:// reference
    SA_REF="op://${VAULT_NAME}/${ITEM_NAME}/credential"
    info "Secret reference: $SA_REF"
fi

# ── Step 4: Create config file ────────────────────────────────────────────────

echo ""
info "Creating config at $CONFIG_FILE..."

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

ask "Session inactivity timeout in seconds" TIMEOUT "7200"

cat > "$CONFIG_FILE" <<EOF
# op-session configuration
# Generated by op-session-setup.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")

# op:// reference to the Service Account token in your vault
OP_SESSION_SA_REF="${SA_REF}"

# Inactivity timeout in seconds (rolling — resets on each use)
OP_SESSION_TIMEOUT=${TIMEOUT}

# Session file directory (default: /tmp/op-session)
# OP_SESSION_DIR="/tmp/op-session"
EOF

chmod 600 "$CONFIG_FILE"
info "Config written."

# ── Step 5: Verify the full flow ──────────────────────────────────────────────

echo ""
if [[ "$CHOICE" == "3" ]]; then
    # Token was already read and validated in Step 2 — no need for a second read.
    info "Skipping redundant verification (already validated above)."
else
    info "Running end-to-end verification..."
    info "(You should see a biometric prompt now)"

    # Clear the SA_TOKEN from this process so the test is realistic
    unset SA_TOKEN

    TEST_TOKEN=$(op read "$SA_REF" 2>&1) || {
        die "Could not read SA token back from vault.
Error: $TEST_TOKEN
Verify the item exists: op item get '$ITEM_NAME' --vault='$VAULT_NAME'"
    }

    TEST_VAULTS=$(OP_SERVICE_ACCOUNT_TOKEN="$TEST_TOKEN" op vault list --format=json 2>&1) || {
        die "Retrieved token failed validation. Error: $TEST_VAULTS"
    }

    info "Full flow verified: biometric → vault → SA token → vault access."
fi

# ── Step 6: Make op-session.sh easily accessible ──────────────────────────────

echo ""
INSTALL_PATH="${HOME}/.local/bin/op-session"

if [[ -d "${HOME}/.local/bin" ]] || mkdir -p "${HOME}/.local/bin" 2>/dev/null; then
    cp "${SCRIPT_DIR}/op-session.sh" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"
    info "Installed op-session to $INSTALL_PATH"

    if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
        warn "${HOME}/.local/bin is not in your PATH."
        echo "  Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
else
    warn "Could not install to ~/.local/bin. You can run the script directly:"
    echo "  ${SCRIPT_DIR}/op-session.sh"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "Quick start:"
echo "  op-session init          # One biometric prompt"
echo "  op-session exec op run --env-file=.env -- ./my-script.sh"
echo "  op-session read 'op://VaultName/ItemName/field'"
echo "  op-session status        # Check session"
echo "  op-session end           # Cleanup"
echo ""
echo "For Claude Code, add this to your AGENTS.md or project instructions:"
echo "  'Use op-session exec to run any command that requires secrets.'"
echo "  'Never read or log the output of op-session read directly.'"
echo ""
