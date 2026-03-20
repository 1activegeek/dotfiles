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
8. chezmoi apply               ← Retry loop (max 2), skip option on failure
9. Dock retry check            ← Detects partial dock failure via stamp file
10. Post-install report        ← Package status, manual tasks, app notes
11. Shell reload               ← exec zsh -l
```

### chezmoi script execution order

chezmoi runs `before` scripts first (alphabetically), then applies dotfiles,
then runs `after` scripts (alphabetically).

| Order | Script | Type | Runs when |
|-------|--------|------|-----------|
| 01 | `run_once_before_01-install-homebrew.sh.tmpl` | once | First run only |
| 02 | `run_once_before_02-install-core.sh.tmpl` | once | First run only |
| 03 | `run_onchange_before_03-brew-bundle.sh.tmpl` | onchange | `packages.yaml` changes |
| — | *dotfiles applied here* | — | — |
| 10 | `run_once_after_10-macos-defaults.sh` | once | First run only |
| 11 | `run_onchange_after_11-dock.sh` | onchange | Script content changes |

**Naming convention:** `run_{once,onchange}_{before,after}_{NN}-{name}.{sh,sh.tmpl}`

- `once` = chezmoi tracks completion in its state DB, never re-runs
- `onchange` = chezmoi hashes template output, re-runs when hash changes
- `before` = runs before dotfile deployment
- `after` = runs after dotfile deployment
- `.tmpl` = chezmoi renders Go templates before execution

### Forcing script re-runs

```bash
# Reset all run_once state (forces every script to re-run)
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

---

## File Map

### Scripts & Templates

| File | Purpose |
|------|---------|
| `bootstrap.sh` | Main entry point. Not managed by chezmoi (in `.chezmoiignore`). |
| `.chezmoiscripts/run_once_before_01-*` | Installs Xcode CLT + Homebrew |
| `.chezmoiscripts/run_once_before_02-*` | Installs core packages (chezmoi, gh, mas, 1password, etc.) |
| `.chezmoiscripts/run_onchange_before_03-*` | Generates Brewfile from `packages.yaml`, runs `brew bundle` |
| `.chezmoiscripts/run_once_after_10-*` | ~100 `defaults write` commands for macOS prefs |
| `.chezmoiscripts/run_onchange_after_11-*` | Dock layout via dockutil |
| `post-install-report.sh.tmpl` | Final report (rendered by bootstrap, not a chezmoi script) |

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
| `dot_config/private_sops/private_age/private_home-ops.key.tmpl` | `op://Private/Age Encryption Key/private key` |

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
| `07-1password.zsh` | 1Password CLI integration |
| `08-extract.zsh` | Universal archive extraction |
| `09-colorize.zsh` | Colored output for less, grep, diff, man |
| `10-kubectl.zsh` | Kubernetes aliases |
| `11-kube-ps1.zsh` | K8s context in prompt (macOS only) |
| `12-kubectx.zsh` | Context/namespace switching |
| `13-sudo.zsh` | Sudo completions |
| `14-fzf.zsh` | Fuzzy finder bindings |
| `15-zoxide.zsh` | Smart directory nav (z/zi) |
| `16-carapace.zsh` | Completion engine |
| `17-brew-helpers.zsh` | brew-export, brew-sync functions |

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
| `~/.local/state/dotfiles/dock-configured` | Dock script success stamp (contains script hash) |
| `~/.local/log/dotfiles-brew-bundle.log` | Last brew bundle output |

---

## Resilience Mechanisms

### Problem → Solution mapping

| Failure | Mechanism | Location |
|---------|-----------|----------|
| Xcode license not accepted | Auto-accept before brew bundle + retry if license errors in log | `03-brew-bundle.sh.tmpl` |
| `brew`/`op` not in PATH on re-run | Source brew shellenv at top of bootstrap | `bootstrap.sh` lines 18-25 |
| Homebrew re-installs unnecessarily | Early PATH sourcing makes `command -v brew` succeed | `bootstrap.sh` lines 18-25 |
| 1Password not authenticated | Interactive retry loop with skip option | `bootstrap.sh` lines 150-179 |
| `chezmoi apply` fails | Retry up to 2x, detect 1Password errors specifically, skip option | `bootstrap.sh` lines 305-350 |
| Dock script fails partway | Stamp file only written on success; bootstrap detects and offers retry | `11-dock.sh` + `bootstrap.sh` lines 352-371 |
| `brew bundle` reports false "OK" | Checks log for `has failed!$` pattern, reports actual count | `03-brew-bundle.sh.tmpl` lines 125-131 |
| Safari defaults fail (no container) | Already handled gracefully — cosmetic warnings only | `10-macos-defaults.sh` |

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

**Fix (now automatic):** `03-brew-bundle.sh.tmpl` accepts the license before
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

**Cause:** `dockutil` failed partway through. Since the script is
`run_onchange`, chezmoi won't re-run it unless the script content changes.

**Fix (now automatic):** Stamp file `~/.local/state/dotfiles/dock-configured`
is only written after full success. Bootstrap detects missing stamp and offers
retry.

**Manual fix:** `bash ~/.local/share/chezmoi/.chezmoiscripts/run_onchange_after_11-dock.sh`

**Force chezmoi to re-run it:** Delete the stamp file:
```bash
rm ~/.local/state/dotfiles/dock-configured
chezmoi apply
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

**Cause:** `run_once_after_10-macos-defaults.sh` only runs once.

**Fix:**
```bash
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

Or run the script directly:
```bash
bash ~/.local/share/chezmoi/.chezmoiscripts/run_once_after_10-macos-defaults.sh
```

### Adding a new package

1. Edit `.chezmoidata/packages.yaml` — add the entry to the correct section (`formulae`, `casks`, or `mas`) in alphabetical order. Use a bare string for simple entries, or flow-mapping (`{ name: ..., profiles: [...] }`) if profile-restricted.
2. Run `chezmoi apply` — the brew bundle script auto-reruns (hash changed)
3. Optionally add post-install notes to `.chezmoidata/post_install_notes.yaml`

---

## Design Plans & History

| Document | What it covers |
|----------|----------------|
| `docs/plans/2026-03-07-chezmoi-native-bootstrap-plan.md` | Initial migration from bootstrap-mac-os to chezmoi |
| `docs/plans/2026-03-07-chezmoi-native-bootstrap-design.md` | Technical design: script ordering, data model, templates |
| `docs/plans/2026-03-09-home-ops-agent-1password-plan.md` | 1Password integration for home-ops secrets |

### Key design decisions

- **chezmoi over bare git** — Templates, secrets integration, idempotent scripts.
- **1Password as secret store** — No encrypted files in repo; `onepasswordRead` at apply time.
- **Single YAML for packages** — One file to edit, profile-filtered, generates Brewfile at runtime.
- **Modular shell config** — 17 files in `dot_zshrc.d/` vs one monolithic `.zshrc`.
- **Interactive retry over hard fail** — Bootstrap pauses for user action rather than exiting.
- **Stamp files for non-idempotent scripts** — Dock script tracks its own success independently of chezmoi's `run_onchange` hash.

### Fresh install experience (post-resilience fixes, 2026-03-18)

A fresh install should now complete in a **single bootstrap session**:
1. Xcode license is auto-accepted before brew bundle
2. brew/op are in PATH even on re-runs (no unnecessary reinstalls)
3. 1Password auth is an interactive loop (skip to continue without secrets)
4. chezmoi failures retry with user guidance
5. Dock failures are detected and retried
6. Brew bundle reports honest failure counts
