---
name: op-session
description: >
  Manages authenticated 1Password sessions for CLI-based agentic workflows
  (Claude Code, aider, etc.) so the agent can access secrets without ever seeing
  them. INVOKE THIS SKILL BEFORE any `op item get`, `op read`, or `op run` call —
  never call those commands raw. Also invoke proactively at the start of any task
  that involves: Home Assistant API access, Kubernetes/Helm authentication, SSH
  connections using 1P credentials, or any external API/service where credentials
  live in 1Password. If a session is already active this skill is a no-op. If a
  command fails with auth errors, invoke this skill to check and reinitialize the
  session before retrying.
---

# 1Password Session Manager for Agentic Workflows

## Overview

This skill provides a secure, session-based approach for AI agents (Claude Code,
Open Code, etc.) to use secrets stored in 1Password — without the agent ever
seeing the actual secret values and without requiring repeated biometric prompts.

### How it works

1. A 1Password **Service Account** token is stored in the user's personal vault
2. At session start, `op-session init` fetches that SA token via one biometric
   prompt
3. The SA token is cached in a temp file (mode 0600, under /tmp) with a rolling
   inactivity timeout
4. All secret-consuming commands run via `op-session exec`, which injects the SA
   token into only the child process environment
5. The agent never sees token values — it only sees command output
6. When done, `op-session end` destroys the cached token

### Security properties

- **Secrets never enter the conversation context.** The agent calls
  `op-session exec op run ...` and sees the *output* of the program, not the
  injected secret values.
- **The SA token is never exported to the agent's environment.** It's loaded from
  a file and injected per-subprocess.
- **Rolling timeout.** Every use resets the inactivity clock. If the agent goes
  idle, the session auto-expires.
- **Scoped access.** The SA is configured with read-only access to specific vaults
  only — not the user's entire 1Password account.
- **No persistence.** The session file lives in /tmp and is overwritten + deleted
  on session end.

---

## Proactive Invocation Contexts

Invoke this skill **immediately** — before any other tool calls — when any of
the following contexts apply:

| Context | Why |
|---------|-----|
| Home Assistant API access | HA token lives in 1P `ha-agent-access` |
| Kubernetes / Helm / kubectl | kubeconfig or bearer tokens in 1P |
| SSH connections | SSH keys or jump-host passwords in 1P |
| Any `op item get` / `op read` / `op run` call | These ARE the credential calls |
| Any external API where creds are in 1P | Covers GitHub tokens, cloud provider keys, DB passwords, etc. |

The rule: **if the task would ever cause you to write `op item get` or `op read`,
invoke this skill first instead.**

---

## Session Check Preamble

**This is always the first action when the skill is invoked.**

```bash
op-session status || op-session init
```

- If the session is already active → silent no-op, proceed immediately
- If the session is expired or absent → `op-session init` runs, triggering one
  biometric prompt; inform the user: "Initializing 1Password session — one
  biometric prompt expected."

Never skip this check. The session may still be valid from earlier in the
conversation (or from a previous conversation if the timeout hasn't elapsed).

---

## WRONG vs RIGHT: Credential Access Patterns

```bash
# WRONG — calls `op` directly, triggers biometric on every Bash block
HA_TOKEN=$(op item get "ha-agent-access" --reveal --fields label=credential)

# RIGHT — routes through the session; no biometric after init
HA_TOKEN=$(op-session exec op item get "ha-agent-access" --reveal --fields label=credential)
```

```bash
# WRONG — raw op read, triggers biometric
DB_PASS=$(op read "op://Private/Postgres/password")

# RIGHT — session-wrapped
DB_PASS=$(op-session exec op read "op://Private/Postgres/password")
```

The pattern: replace every bare `op` call with `op-session exec op`.

---

## First-Time Setup

If the user hasn't set up the op-session skill yet, guide them through it. The
setup script handles everything interactively:

```bash
bash /path/to/op-session-skill/scripts/op-session-setup.sh
```

The setup will:
1. Verify `op` CLI and desktop app integration
2. Help create or configure a Service Account
3. Store the SA token in the user's personal vault
4. Create `~/.config/op-session/config`
5. Install the `op-session` command to `~/.local/bin/`

**Prerequisites the user needs before setup:**
- 1Password 8 desktop app, signed in
- 1Password CLI (`op`) installed
- Desktop integration enabled (Settings → Developer → Integrate with CLI)
- A Service Account with read access to the needed vault(s)

Service Accounts are created at: https://my.1password.com → Settings → Service Accounts

---

## Usage Patterns

### Pattern 1: Initialize at session start

At the beginning of any task that will need secrets, initialize the session.
This is the ONLY step that triggers a biometric prompt.

```bash
op-session init
```

If the session is already active, this is a no-op (safe to call multiple times).

### Pattern 2: Run commands with injected secrets

Use `op-session exec` to run any command that needs secrets. The SA token is
injected into the subprocess environment as `OP_SERVICE_ACCOUNT_TOKEN`, which the
`op` CLI automatically picks up.

**Fetching a single field (e.g. HA token):**
```bash
HA_TOKEN=$(op-session exec op item get "ha-agent-access" --reveal --fields label=credential)
```

**Running a command with secrets from an .env template:**
```bash
op-session exec op run --env-file=.env -- ./deploy.sh
```

**Running a curl with an API token:**
```bash
op-session exec op run --env-file=.env -- curl -H "Authorization: Bearer $API_TOKEN" https://api.example.com/status
```

**Running a script that uses `op read` internally:**
```bash
op-session exec ./my-script.sh
# Inside my-script.sh, `op read "op://Vault/Item/field"` will work
# because OP_SERVICE_ACCOUNT_TOKEN is in the environment
```

### Pattern 3: Check session status

```bash
op-session status
# Output: "active" or "inactive"
# Also prints time remaining to stderr
```

### Pattern 4: End session when done

```bash
op-session end
```

This overwrites and deletes the cached token file.

---

## Critical Rules for Agent Behavior

0. **NEVER write `op item get`, `op read`, or `op run` directly.** Always route
   through `op-session exec op ...`. Raw `op` calls trigger biometric auth on
   every Bash block, defeating the purpose of this skill.

1. **NEVER use `op-session read` and capture its output in a variable or log it.**
   If you need a secret value for a command, use `op-session exec op run` instead
   so the value is injected into the subprocess environment without passing
   through the agent's context.

2. **NEVER echo, print, or log the contents of the session token file.**
   The file at /tmp/op-session/sa-token is off-limits for reading or displaying.

3. **ALWAYS use `op-session exec` as the wrapper for any command that needs
   secrets.** Don't try to export OP_SERVICE_ACCOUNT_TOKEN yourself.

4. **If `op-session status` returns "inactive", run `op-session init` and inform
   the user they'll see a biometric prompt.** Don't try to work around it.

5. **At the end of a major task or when the user says "done", run
   `op-session end`.** Don't leave sessions hanging.

6. **If a command fails with auth errors, check `op-session status` first.**
   The session may have timed out — reinit rather than retrying raw `op` calls.

7. **NEVER pass secret values as command-line arguments.** They show up in
   `ps` output. Use environment variable injection via `op run` instead.

8. **Fetch credentials ONCE per session** — store in a shell variable for the
   duration of a Bash block. Don't call `op-session exec op item get` on every
   API call.

---

## .env File Pattern

The most common pattern for injecting secrets is via an `.env` file template
that references 1Password secret URIs:

```env
# .env (committed to repo — safe, contains only references)
HA_TOKEN=op://HomeAutomation/HomeAssistant/api-token
K8S_TOKEN=op://Infrastructure/Kubernetes/bearer-token
DB_PASSWORD=op://Infrastructure/PostgreSQL/password
```

Then run:
```bash
op-session exec op run --env-file=.env -- ./your-command.sh
```

`op run` replaces the `op://...` references with real values in the subprocess
environment only.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `op-session init` fails with "Cannot communicate with desktop app" | 1P desktop not running or CLI integration off | Open 1P desktop, enable Settings → Developer → CLI integration |
| Biometric prompt appears but token validation fails | SA token expired or SA deleted | Recreate the SA and re-run setup |
| `op-session exec` says "No active session" | Session timed out | Run `op-session init` again |
| Commands work but return wrong/empty secrets | SA doesn't have access to that vault | Add vault access to the SA at my.1password.com |
| Session expires too quickly | Timeout too short | Edit `~/.config/op-session/config`, increase `OP_SESSION_TIMEOUT` |
| Getting biometric prompts on every Bash block | Calling `op` directly instead of via `op-session exec` | Replace raw `op` calls with `op-session exec op` |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│  Claude Code / Agent                                     │
│                                                          │
│  0. op-session status || op-session init                 │
│     └→ [if inactive] op read "op://Private/SA-Token/..."│
│        └→ [BIOMETRIC PROMPT — user authenticates once]   │
│        └→ SA token written to /tmp/op-session/sa-token   │
│     └→ [if active] silent no-op                         │
│                                                          │
│  1. op-session exec op item get "ha-agent-access" ...    │
│     └→ Reads SA token from file (agent never sees it)    │
│     └→ Injects OP_SERVICE_ACCOUNT_TOKEN into child env   │
│     └→ op retrieves item without biometric               │
│     └→ Agent sees item value only                        │
│                                                          │
│  2. op-session exec op run --env-file=.env -- cmd        │
│     └→ Reads SA token from file (agent never sees it)    │
│     └→ Injects OP_SERVICE_ACCOUNT_TOKEN into child env   │
│     └→ op run resolves op:// refs in .env                │
│     └→ cmd runs with real secrets in its env             │
│     └→ Agent sees cmd's stdout/stderr only               │
│                                                          │
│  3. op-session end                                       │
│     └→ Overwrites + deletes /tmp/op-session/sa-token     │
└─────────────────────────────────────────────────────────┘
```
