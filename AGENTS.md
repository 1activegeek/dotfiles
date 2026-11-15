# AGENTS.md — Bootstrap & Dotfiles System Reference

> For AI agents working on this repo. Covers architecture, execution flow,
> failure modes, and troubleshooting.

## System Overview

This is a chezmoi-managed macOS dotfiles repo with a one-command bootstrap
(`bootstrap.sh`) that takes a bare Mac from zero to fully configured. The
system is idempotent and designed to complete in a single session, with
interactive retry loops for recoverable failures.

**Entry point:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"
```

**Key tools:** chezmoi (dotfile manager), Homebrew (packages), 1Password CLI
(secrets), dockutil (Dock config).

---

## Execution Flow

### bootstrap.sh (the orchestrator)

```
1. Source brew shellenv        ← Ensures PATH has brew/op on re-runs
2. Pre-flight checklist        ← Apple ID + Mac App Store signed in?
3. Xcode CLI Tools             ← Install + accept license
4. Homebrew                    ← Install if missing (skips if already in PATH)
5. chezmoi                     ← Install via brew
6. 1Password                   ← Install app + CLI, interactive auth loop
7. Machine configuration       ← Profile (personal/work), hostname, git identity
8. chezmoi apply               ← Dotfiles ONLY. Retry loop (max 2), skip option
9. setup/setup.sh              ← One-time machine setup stages (skips stamped ones)
10. setup.sh --report          ← Package status, manual tasks, app notes
11. Shell reload               ← exec zsh -l
```

### `chezmoi apply` runs no scripts

There is no `.chezmoiscripts/` directory. `chezmoi apply` / `chezmoi update` only
deploy files, so they are always safe to run on any machine. Do not add
`run_*` scripts back; put machine setup in `setup/stages/` instead.

### setup/setup.sh (one-time machine setup)

`setup/` is in `.chezmoiignore`, so chezmoi never deploys or runs it.
`bootstrap.sh` calls it after `chezmoi apply`; you can also run it by hand.

| Order | Stage | What it does |
|-------|-------|--------------|
| 10 | `homebrew` | Xcode CLT + Homebrew, analytics off, `brew update` |
| 20 | `core` | 1Password, 1Password CLI, Brave, Ghostty, Raycast, chezmoi, gh, mas |
| 30 | `packages` | Renders `setup/Brewfile.tmpl` from `packages.yaml` + profile, `brew bundle install`. Removes unlisted packages ONLY with `--prune`, after a prompt. |
| 40 | `macos-defaults` | ~100 `defaults write` commands, restarts Dock/Finder/SystemUIServer |
| 50 | `dock` | Wipes and rebuilds the Dock with dockutil |
| 60 | `claude-skills` | Symlinks `~/.agents/skills/*` into `~/.claude/skills/` |

**Stamps:** `~/.local/state/dotfiles/setup/<stage>.done`, written only on success.
A stamped stage never runs again unless you ask:

```bash
setup/setup.sh --list                    # status of every stage
setup/setup.sh --only dock               # re-run one stage (comma list allowed)
setup/setup.sh --only packages --prune   # also offer to remove unlisted packages
setup/setup.sh --force                   # re-run everything
setup/setup.sh --mark-done               # stamp all stages without running (existing machine)
```

**Warning for agents:** these stages change the real machine (install apps,
rewrite preferences, wipe the Dock). Never run them to "test". To test the runner,
build a tree that holds only dummy stages.

---

## File Map

### Scripts & Templates

| File | Purpose |
|------|---------|
| `bootstrap.sh` | Main entry point. Not managed by chezmoi (in `.chezmoiignore`). |
| `setup/setup.sh` | Stage runner with stamps. Not managed by chezmoi. |
| `setup/stages/10..60-*.sh` | Homebrew, core apps, packages, macOS defaults, Dock, Claude skill links |
| `setup/Brewfile.tmpl` | Brewfile template rendered from `packages.yaml` + profile |
| `setup/report.sh.tmpl` | Post-install report (`setup.sh --report`) |

### Data Files

| File | Purpose |
|------|---------|
| `.chezmoidata/packages.yaml` | All packages in four sections: taps, formulae, casks, mas. Sorted alphabetically. Profile-filtered. |
| `.chezmoidata/post_install_notes.yaml` | Per-app post-install instructions |
| `.chezmoidata/post_install_tasks.yaml` | Manual checklist shown in report |

### Secrets (1Password-backed templates)

| File | 1Password reference |
|------|---------------------|
| `private_dot_ssh/private_config.tmpl` | `op://Private/SSH Config/notesPlain` |
| `private_dot_kube/private_config.tmpl` | `op://Private/Kube Config/notesPlain` |
| `dot_config/private_sops/private_age/private_home-ops.key.tmpl` | `op://Private/SOPS Age Key - home-ops/private key` |
| `dot_config/atuin/config.toml.tmpl` (sync block only) | `op://Private/Dotfiles - atuin sync address/notesPlain` (personal + `privateNotes`) |

### Private files (1Password Secure Notes)

`.chezmoidata/private_notes.yaml` maps each private file (accounts.yaml, CLAUDE.md,
Claude settings.json, scheduled tasks, jarvis-git, op-session, homarr-mcp-headers)
to a note in the `Private` vault. Each source template calls
`.chezmoitemplates/private-note`. `.chezmoiignore` skips them unless
`profile == personal` and `[data] privateNotes = true`. Push edits with
`op-sync-private`. Never commit these files' content to this public repo.

### Secret Sync Functions

The `07-1password.zsh` file provides two functions for pushing local edits back to 1Password:

| Function | What it syncs |
|----------|---------------|
| `op-sync-ssh` | `~/.ssh/config` → 1Password "SSH Config" Secure Note |
| `op-sync-kube` | `~/.kube/config` → 1Password "Kube Config" Secure Note |
| `op-sync-private` | Files in `.chezmoidata/private_notes.yaml` → their "Dotfiles - …" Secure Notes (creates missing ones) |

**Workflow:** Edit the file locally → run `op-sync-{ssh,kube}` → the 1Password vault item is updated → next `chezmoi apply` on any machine pulls the new version.

### Config Templates

| File | Purpose |
|------|---------|
| `dot_chezmoi.toml.tmpl` | chezmoi config (profile, git identity, editor) |
| `dot_gitconfig.tmpl` | Git config (name, email, aliases, merge settings) |

### Shell Configuration

`dot_zshrc` sources everything in `dot_zshrc.d/` alphabetically:

| File | What it sets up |
|------|-----------------|
| `01-history.zsh` | History size, dedup, search |
| `02-aliases.zsh` | ls→eza, cat→bat, general aliases |
| `03-git.zsh` | Git shortcuts |
| `04-brew.zsh` | Homebrew helpers |
| `05-macos.zsh` | macOS functions (lock, hidden files, etc.) |
| `06-docker.zsh` | Docker shortcuts |
| `07-1password.zsh` | 1Password CLI integration, SSH agent, sync functions (`op-sync-ssh`, `op-sync-kube`) |
| `08-extract.zsh` | Universal archive extraction |
| `09-colorize.zsh` | Colored output for less, grep, diff, man |
| `10-kubectl.zsh` | Kubernetes aliases |
| `11-kube-ps1.zsh` | K8s context in prompt (macOS only) |
| `12-kubectx.zsh` | Context/namespace switching |
| `13-sudo.zsh` | Sudo completions |
| `14-fzf.zsh` | Fuzzy finder bindings |
| `15-zoxide.zsh` | Smart directory nav (z/zi) |
| `16-carapace.zsh` | Completion engine |
| `17-brew-helpers.zsh` | brew-export, brew-sync (runs the `packages` setup stage), brew-diff |
| `19-lifeos.zsh` | LifeOS vault paths and tools on PATH |

---

## Profile System

Two profiles: **personal** and **work**. Stored in `~/.config/chezmoi/chezmoi.toml`.

- Simple entries are bare strings and install on all profiles.
- Entries with `profiles: [personal]` use flow-mapping: `{ name: foo, profiles: [personal] }`.
- MAS entries always use flow-mapping: `{ id: "123", name: "App Name" }`.
- Work machines skip SSH config (`.chezmoiignore`).
- Profile is set once during initial bootstrap and cached.

---

## State & Stamp Files

| File | Purpose |
|------|---------|
| `~/.config/chezmoi/chezmoi.toml` | Machine config (profile, identity) |
| `~/.local/share/chezmoi/` | chezmoi source dir (clone of this repo) |
| `~/.local/state/dotfiles/setup/<stage>.done` | Setup stage success stamps (date) |
| `~/.local/log/dotfiles-brew-bundle.log` | Last brew bundle output |

---

## Resilience Mechanisms

### Problem → Solution mapping

| Failure | Mechanism | Location |
|---------|-----------|----------|
| Xcode license not accepted | Auto-accept before brew bundle + retry if license errors in log | `setup/stages/30-packages.sh` |
| `brew`/`op` not in PATH on re-run | Source brew shellenv at top of bootstrap | `bootstrap.sh` lines 18-25 |
| Homebrew re-installs unnecessarily | Early PATH sourcing makes `command -v brew` succeed | `bootstrap.sh` lines 18-25 |
| 1Password not authenticated | Interactive retry loop with skip option | `bootstrap.sh` lines 150-179 |
| `chezmoi apply` fails | Retry up to 2x, detect 1Password errors specifically, skip option | `bootstrap.sh` lines 305-350 |
| Any setup stage fails | No stamp is written; bootstrap offers a retry, and the next `setup.sh` run retries it | `setup/setup.sh` + `bootstrap.sh` |
| `brew bundle` reports false "OK" | Checks log for `has failed!$` pattern, reports actual count | `setup/stages/30-packages.sh` |
| Safari defaults fail (no container) | Already handled gracefully — cosmetic warnings only | `setup/stages/40-macos-defaults.sh` |

### Interactive retry pattern

When a recoverable failure occurs, scripts:
1. Explain what went wrong
2. Tell the user what to do
3. Wait (`read -r -p "Press Enter when ready (or 's' to skip)..."`)
4. Re-check the condition
5. Loop or skip based on user input

### Skip propagation

If user skips 1Password auth → `SKIP_1PASSWORD=true` → chezmoi runs with
`--exclude=encrypted` → secrets are not deployed → user must re-run bootstrap
later to deploy them.

---

## Troubleshooting Guide

### "95 packages failed" on first run

**Cause:** Xcode was installed by MAS but license wasn't accepted before
`brew bundle` ran.

**Fix (now automatic):** `setup/stages/30-packages.sh` accepts the license before
running and retries the full bundle if license errors appear in the log.

**Manual fix:** `sudo xcodebuild -license accept` then re-run bootstrap.

### "command not found: op" after installing 1Password CLI

**Cause:** Shell session started before brew was installed. `/opt/homebrew/bin`
not in PATH.

**Fix (now automatic):** `bootstrap.sh` sources brew shellenv at the top,
before any `command -v` checks.

**Manual fix:** Run `eval "$(/opt/homebrew/bin/brew shellenv)"` or start a new
terminal.

### Homebrew re-installs on every re-run

**Cause:** Same PATH issue — `command -v brew` fails because brew isn't in
PATH yet.

**Fix (now automatic):** Early shellenv sourcing in bootstrap.sh.

### Dock only partially configured

**Cause:** `dockutil` failed partway through, or an app was not installed yet.

**Fix:** The `dock` stage has no stamp after a failure, so the next
`setup/setup.sh` run (or bootstrap) retries it. To rebuild on purpose:
```bash
~/.local/share/chezmoi/setup/setup.sh --only dock
```

### 1Password blocks the entire bootstrap

**Cause:** User hasn't opened 1Password or enabled CLI integration yet.

**Fix (now automatic):** Retry loop with skip option. User can press `s` to
skip secrets and continue with everything else.

### chezmoi apply fails with 1Password errors

**Cause:** Templates like `private_dot_ssh/private_config.tmpl` call
`onepasswordRead` which fails if CLI isn't authenticated.

**Fix:** Bootstrap retries up to 2x. On skip, uses `--exclude=encrypted` to
skip all 1Password-backed templates.

### macOS defaults didn't apply / need to re-apply

```bash
~/.local/share/chezmoi/setup/setup.sh --only macos-defaults
```

### Adding a new package

1. Edit `.chezmoidata/packages.yaml` — add the entry to the correct section (`formulae`, `casks`, or `mas`) in alphabetical order. Use a bare string for simple entries, or flow-mapping (`{ name: ..., profiles: [...] }`) if profile-restricted.
2. Run `brew-sync` (or `setup/setup.sh --only packages`). `chezmoi apply` never installs packages.
3. Optionally add post-install notes to `.chezmoidata/post_install_notes.yaml`

---

## Design Plans & History

| Document | What it covers |
|----------|----------------|
| `docs/plans/2026-03-07-chezmoi-native-bootstrap-plan.md` | Initial migration from bootstrap-mac-os to chezmoi |
| `docs/plans/2026-03-07-chezmoi-native-bootstrap-design.md` | Technical design: script ordering, data model, templates |
| `docs/plans/2026-03-09-home-ops-agent-1password-plan.md` | 1Password integration for home-ops secrets |

### Key design decisions

- **chezmoi over bare git** — Templates and secrets integration.
- **Dotfiles and machine setup are separate (2026-11-15)** — `chezmoi apply` runs no scripts; `setup/setup.sh` runs one-time stages with stamps. Package prune is opt-in (`--prune`).
- **1Password as secret store** — No encrypted files in repo; `onepasswordRead` at apply time.
- **Single YAML for packages** — One file to edit, profile-filtered, generates Brewfile at runtime.
- **Modular shell config** — 19 files in `dot_zshrc.d/` vs one monolithic `.zshrc`.
- **Interactive retry over hard fail** — Bootstrap pauses for user action rather than exiting.
- **Stamp files for every setup stage** — a stage runs once; re-run on purpose with `--only`.

### Fresh install experience (post-resilience fixes, 2026-03-18)

A fresh install should now complete in a **single bootstrap session**:
1. Xcode license is auto-accepted before brew bundle
2. brew/op are in PATH even on re-runs (no unnecessary reinstalls)
3. 1Password auth is an interactive loop (skip to continue without secrets)
4. chezmoi failures retry with user guidance
5. Dock failures are detected and retried
6. Brew bundle reports honest failure counts
