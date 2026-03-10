# Home-Ops Agent 1Password Access Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give local terminal and GUI-launched agents non-interactive read/write access to the `home-ops` vault through a dedicated 1Password service account, while keeping the token itself stored only in 1Password and the setup logic synced through dotfiles.

**Architecture:** Store the service account token in the personal 1Password account as a bootstrap secret, then deploy a small shell helper plus a macOS LaunchAgent that reads that bootstrap secret and publishes `OP_SERVICE_ACCOUNT_TOKEN` into the user session. Agents use the service account token directly for `op item get`, `op item create`, and `op item edit` operations against the `home-ops` vault. The repo continues to sync only code and config; no plaintext token is committed.

**Tech Stack:** chezmoi templates, ZSH, macOS `launchctl` / LaunchAgents, 1Password CLI (`op`)

---

### Task 1: Document the Required 1Password Objects

**Files:**
- Modify: `README.md`

**Context:** Before any automation lands, the repo needs a documented contract for the 1Password objects this setup depends on. That includes the dedicated service account and the bootstrap item in the personal vault that stores the service account token.

**Step 1: Add a new README subsection for agent auth prerequisites**

Add a subsection under `## Secrets` that documents these required objects:

```md
### Agent access for `home-ops`

This repo supports non-interactive agent access to the `home-ops` vault through a dedicated 1Password service account.

Required 1Password setup:

1. Create a service account with access limited to the `home-ops` vault.
2. Grant the service account item read/write permissions required for automation.
3. Store the service account token in your personal 1Password account as:
   - Vault: `Private`
   - Item: `Agent Service Account - home-ops`
   - Field: `credential`
```

**Step 2: Verify the README wording matches the intended design**

Read the added section and confirm it states all three of these constraints explicitly:
- scoped only to `home-ops`
- read/write allowed
- token stored in 1Password, not in git

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: define home-ops agent auth prerequisites"
```

---

### Task 2: Add a Shell Helper That Fetches and Exports the Token

**Files:**
- Modify: `dot_zshrc.d/07-1password.zsh`

**Context:** Terminal-launched tools need a simple, explicit way to bootstrap the service account token from your personal 1Password session. This helper should fail closed and should not write the token to disk.

**Step 1: Add a helper to fetch the bootstrap token**

Append these functions near the existing `opget` / `opcopy` helpers:

```zsh
op_home_ops_agent_token() {
  op item get "Agent Service Account - home-ops" \
    --vault "Private" \
    --fields label=credential
}

op_home_ops_agent_env() {
  local token
  token="$(op_home_ops_agent_token)" || return 1

  if [[ -z "$token" ]]; then
    echo "home-ops agent token not found in 1Password." >&2
    return 1
  fi

  export OP_SERVICE_ACCOUNT_TOKEN="$token"
}
```

**Step 2: Add a helper to launch a command in that environment**

Add this function directly below the export helper:

```zsh
op_home_ops_agent_run() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: op_home_ops_agent_run <command> [args...]" >&2
    return 1
  fi

  local token
  token="$(op_home_ops_agent_token)" || return 1

  if [[ -z "$token" ]]; then
    echo "home-ops agent token not found in 1Password." >&2
    return 1
  fi

  OP_SERVICE_ACCOUNT_TOKEN="$token" "$@"
}
```

**Step 3: Verify the shell file parses cleanly**

Run: `zsh -n dot_zshrc.d/07-1password.zsh`

Expected: no output, exit code `0`

**Step 4: Verify the helper can read the token after a human 1Password sign-in**

Run: `zsh -ic 'source dot_zshrc.d/07-1password.zsh && op_home_ops_agent_token >/dev/null && echo ok'`

Expected: `ok`

**Step 5: Commit**

```bash
git add dot_zshrc.d/07-1password.zsh
git commit -m "feat: add home-ops agent token shell helpers"
```

---

### Task 3: Create a Bootstrap Script for User-Session Export

**Files:**
- Create: `dot_local/bin/op-home-ops-agent-bootstrap`

**Context:** GUI-launched tools need the token published into the macOS user environment. This script should read the bootstrap secret from 1Password, validate it, and then call `launchctl setenv OP_SERVICE_ACCOUNT_TOKEN ...`.

**Step 1: Create the bootstrap script**

Create `dot_local/bin/op-home-ops-agent-bootstrap` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v op >/dev/null 2>&1; then
  echo "op CLI is required" >&2
  exit 1
fi

token="$(op item get "Agent Service Account - home-ops" --vault "Private" --fields label=credential)"

if [[ -z "${token}" ]]; then
  echo "home-ops agent token not found in 1Password" >&2
  exit 1
fi

launchctl setenv OP_SERVICE_ACCOUNT_TOKEN "${token}"
```

**Step 2: Make the script executable in source control**

Run:

```bash
chmod +x dot_local/bin/op-home-ops-agent-bootstrap
git add --chmod=+x dot_local/bin/op-home-ops-agent-bootstrap
```

**Step 3: Verify the script succeeds when 1Password is unlocked**

Run: `./dot_local/bin/op-home-ops-agent-bootstrap`

Expected: no output, exit code `0`

**Step 4: Verify the env var was published into the user session**

Run: `launchctl getenv OP_SERVICE_ACCOUNT_TOKEN | wc -c`

Expected: non-zero length output

**Step 5: Commit**

```bash
git add dot_local/bin/op-home-ops-agent-bootstrap
git commit -m "feat: add home-ops agent bootstrap script"
```

---

### Task 4: Create a LaunchAgent for GUI Availability

**Files:**
- Create: `dot_Library/LaunchAgents/com.shawnmix.op-home-ops-agent-bootstrap.plist.tmpl`

**Context:** The bootstrap script should run automatically in the user login session so GUI apps launched later can inherit the service account token. The plist should be conservative: run at load, restart on failure, and log to a user-visible location.

**Step 1: Create the LaunchAgent plist template**

Create `dot_Library/LaunchAgents/com.shawnmix.op-home-ops-agent-bootstrap.plist.tmpl` with this content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.shawnmix.op-home-ops-agent-bootstrap</string>

  <key>ProgramArguments</key>
  <array>
    <string>{{ .chezmoi.homeDir }}/.local/bin/op-home-ops-agent-bootstrap</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <false/>

  <key>StandardOutPath</key>
  <string>{{ .chezmoi.homeDir }}/Library/Logs/op-home-ops-agent-bootstrap.log</string>

  <key>StandardErrorPath</key>
  <string>{{ .chezmoi.homeDir }}/Library/Logs/op-home-ops-agent-bootstrap.log</string>
</dict>
</plist>
```

**Step 2: Render the template to verify chezmoi syntax**

Run: `chezmoi execute-template < dot_Library/LaunchAgents/com.shawnmix.op-home-ops-agent-bootstrap.plist.tmpl`

Expected: valid XML with the absolute home directory path rendered in both locations

**Step 3: Apply and load the LaunchAgent**

Run:

```bash
chezmoi apply
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.shawnmix.op-home-ops-agent-bootstrap.plist" || true
launchctl kickstart -k "gui/$(id -u)/com.shawnmix.op-home-ops-agent-bootstrap"
```

Expected: no fatal error; the agent runs and publishes `OP_SERVICE_ACCOUNT_TOKEN`

**Step 4: Verify GUI-session inheritance works**

Run: `launchctl getenv OP_SERVICE_ACCOUNT_TOKEN | wc -c`

Expected: non-zero length output

**Step 5: Commit**

```bash
git add dot_Library/LaunchAgents/com.shawnmix.op-home-ops-agent-bootstrap.plist.tmpl
git commit -m "feat: add launch agent for home-ops token bootstrap"
```

---

### Task 5: Add an Explicit Unset / Rotation Helper

**Files:**
- Modify: `dot_zshrc.d/07-1password.zsh`
- Modify: `README.md`

**Context:** Because this token allows writes to `home-ops`, there needs to be an explicit way to clear it from the session and a documented token rotation path.

**Step 1: Add a shell helper to clear the exported token**

Append this function below the launch helper:

```zsh
op_home_ops_agent_unset() {
  unset OP_SERVICE_ACCOUNT_TOKEN
  launchctl unsetenv OP_SERVICE_ACCOUNT_TOKEN >/dev/null 2>&1 || true
}
```

**Step 2: Add rotation / recovery docs to the README**

Add a short subsection like this:

```md
### Rotating the `home-ops` agent token

1. Rotate or replace the 1Password service account token.
2. Update the `Agent Service Account - home-ops` item in the `Private` vault.
3. Run `op-home-ops-agent-bootstrap` again, or restart the LaunchAgent.
4. Verify with `launchctl getenv OP_SERVICE_ACCOUNT_TOKEN`.
```

**Step 3: Verify the unset helper clears the session env**

Run: `zsh -ic 'source dot_zshrc.d/07-1password.zsh && op_home_ops_agent_unset && launchctl getenv OP_SERVICE_ACCOUNT_TOKEN'`

Expected: empty output

**Step 4: Commit**

```bash
git add dot_zshrc.d/07-1password.zsh README.md
git commit -m "docs: add home-ops token rotation workflow"
```

---

### Task 6: Add a Verification Workflow for Vault Read/Write Access

**Files:**
- Modify: `README.md`

**Context:** This feature is only successful if the token can read from and write to `home-ops`. The repo should include a single smoke-test sequence that proves the service account scope and permissions are correct.

**Step 1: Add a verification subsection to the README**

Document this exact smoke test:

````md
### Verify `home-ops` agent access

```bash
op_home_ops_agent_env
op vault get home-ops
op item create --vault home-ops --category=login --title "Agent Smoke Test" --generate-password
op item get "Agent Smoke Test" --vault home-ops
op item delete "Agent Smoke Test" --vault home-ops --archive
```
````

Also add one sentence stating that the smoke test should succeed without any interactive prompt after the bootstrap token has been retrieved.

**Step 2: Run the smoke test manually**

Run the exact commands above after `op_home_ops_agent_env` succeeds.

Expected:
- `op vault get home-ops` succeeds
- item creation succeeds
- item read succeeds
- item archive succeeds

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add home-ops agent auth verification steps"
```

---

### Task 7: Final End-to-End Validation

**Files:**
- Verify only: `dot_zshrc.d/07-1password.zsh`
- Verify only: `dot_local/bin/op-home-ops-agent-bootstrap`
- Verify only: `dot_Library/LaunchAgents/com.shawnmix.op-home-ops-agent-bootstrap.plist.tmpl`
- Verify only: `README.md`

**Context:** Before considering the feature complete, validate both the terminal and GUI flows from a clean session.

**Step 1: Verify shell helper syntax and template rendering**

Run:

```bash
zsh -n dot_zshrc.d/07-1password.zsh
chezmoi execute-template < dot_Library/LaunchAgents/com.shawnmix.op-home-ops-agent-bootstrap.plist.tmpl >/dev/null
```

Expected: both commands succeed with exit code `0`

**Step 2: Verify terminal-only agent launch**

Run:

```bash
zsh -ic 'source dot_zshrc.d/07-1password.zsh && op_home_ops_agent_run op vault get home-ops >/dev/null && echo ok'
```

Expected: `ok`

**Step 3: Verify GUI-session env is available**

Run:

```bash
launchctl kickstart -k "gui/$(id -u)/com.shawnmix.op-home-ops-agent-bootstrap"
launchctl getenv OP_SERVICE_ACCOUNT_TOKEN | wc -c
```

Expected: non-zero length output

**Step 4: Check git status**

Run: `git status --short`

Expected: only the intended tracked file changes remain

**Step 5: Final commit**

```bash
git add README.md dot_zshrc.d/07-1password.zsh dot_local/bin/op-home-ops-agent-bootstrap dot_Library/LaunchAgents/com.shawnmix.op-home-ops-agent-bootstrap.plist.tmpl
git commit -m "feat: add 1password-backed home-ops agent auth"
```
