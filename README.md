# dotfiles

Personal macOS setup managed by [chezmoi](https://www.chezmoi.io/).
One command to set up a new Mac. One command to keep it in sync.

The repo has two separate parts:

| Part | Command | What it does | When it runs |
|---|---|---|---|
| Dotfiles | `chezmoi apply` / `chezmoi update` | Deploys config files only. **No scripts run.** | Any time — safe |
| Machine setup | `~/.local/share/chezmoi/setup/setup.sh` | Homebrew, packages + MAS apps, macOS defaults, Dock, Claude skill links | Once, from `bootstrap.sh` on a new machine. Each stage leaves a stamp and never re-runs by itself. |

## Quick Start

### Set up a new machine

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"
```

This installs Xcode CLI Tools, Homebrew, chezmoi and 1Password, applies the dotfiles, and then runs the one-time machine setup (`setup/setup.sh`). The bootstrap script clones via HTTPS first (SSH keys aren't available yet) and switches the remote to SSH after the dotfiles are applied. `autoCommit` and `autoPush` are **off** — this repo is public, so review and push by hand.

### Machine setup stages

```bash
S=~/.local/share/chezmoi/setup/setup.sh
$S --list                 # which stages are done
$S --only dock            # re-run one stage on purpose (comma list allowed)
$S --only packages --prune  # install packages.yaml, then offer to remove unlisted packages
$S --force                # re-run every stage
$S --mark-done            # existing, already set-up machine: stamp all stages, run nothing
$S --report               # post-install report only
```

Stages: `homebrew`, `core`, `packages`, `macos-defaults`, `dock`, `claude-skills`.
Stamps live in `~/.local/state/dotfiles/setup/`. A failed stage has no stamp, so the next run retries it.

**Existing machine, first time on this version:** run `$S --mark-done` once, so a later bootstrap does not re-apply defaults or rebuild the Dock.

### Use chezmoi directly on an existing machine

If you're setting up chezmoi on a device without the full bootstrap, **use the SSH URL** so pushes work:

```bash
chezmoi init --apply git@github.com:1activegeek/dotfiles.git
```

Do **not** use the shorthand `chezmoi init 1activegeek` — it defaults to HTTPS, which will fail on push without a credential helper.

### Sync everything (apps + dotfiles)

```bash
chezmoi update && brew-sync
```

Pulls the latest dotfiles and applies them. `brew-sync` runs the `packages` setup stage: it installs missing packages, then lists packages not in the catalog and asks before it removes them.

### Sync dotfiles only

```bash
chezmoi update
```

## What Gets Installed

All packages are defined in `.chezmoidata/packages.yaml` and installed via `brew bundle`:

| Section | Examples |
|---|---|
| Formulae | chezmoi, atuin, bat, eza, fzf, starship, kubectl, helm, Terraform |
| Casks | 1Password, Ghostty, VS Code, Docker, OrbStack, Claude, Brave, Slack, Obsidian |
| Mac App Store | Xcode, 1Password for Safari, DuckDuckGo, Perplexity |

## Machine Profiles

During `chezmoi init`, you choose a profile: **personal** or **work**.

- **personal** — full install including homelab tools, 3D printing apps, personal utilities
- **work** — skips personal-only packages; adds work apps (Teams, Okta Verify)

To change your profile after init:

```bash
# Edit ~/.config/chezmoi/chezmoi.toml and update the profile value
chezmoi apply
```

## Managing Packages

**Add a package:** Edit `.chezmoidata/packages.yaml`, add the entry, then run `brew-sync` (or `setup.sh --only packages`). `chezmoi apply` never installs packages.

**Remove a package:** Remove from `packages.yaml`, then run `brew-sync` to uninstall it.

**See what's installed vs what's in the catalog:**

```bash
brew-export   # Dumps current Homebrew state to Brewfile.current for comparison
```

## Managing Dotfiles

### Pulling changes from the repo

```bash
chezmoi update                      # Pull latest from git and apply to home directory
```

### Making local changes and pushing to the repo

With `autoCommit` and `autoPush` enabled (configured by bootstrap), most chezmoi commands that modify the source directory will automatically commit and push to the remote. This means changes propagate to all machines without manual git operations.

```bash
chezmoi add ~/.config/app/config    # Start managing a new file (auto-commits + pushes)
chezmoi edit ~/.config/app/config   # Edit a managed file (auto-commits + pushes on save)
chezmoi re-add                      # Re-add all modified managed files (auto-commits + pushes)
```

If you edit files directly in the source directory (`chezmoi cd`), you'll need to commit and push manually:

```bash
chezmoi cd
# make your changes...
git add -A && git commit -m "description" && git push
```

### Other useful commands

```bash
chezmoi diff                        # Preview what chezmoi would change in your home directory
chezmoi apply                       # Apply source state to home directory (does not pull)
chezmoi managed                     # List all files managed by chezmoi
chezmoi status                      # Show differences between source and home directory
chezmoi cd                          # Open the chezmoi source directory
chezmoi git -- status               # Run git commands against the source repo
```

### Verify remote is using SSH

If `autoPush` fails silently, check that the chezmoi source repo is using SSH (not HTTPS):

```bash
chezmoi git -- remote -v
# Should show: git@github.com:1activegeek/dotfiles.git
# If it shows https://, fix with:
chezmoi git -- remote set-url origin git@github.com:1activegeek/dotfiles.git
```

## Secrets

SSH keys, kube config, and SOPS age keys are stored in 1Password and deployed via chezmoi templates. Before running `chezmoi apply` on a fresh machine:

1. Open 1Password and sign in
2. Enable CLI integration (Settings → Developer → CLI)
3. Run `eval $(op signin)`
4. Run `chezmoi apply`

If 1Password isn't ready, chezmoi will error when it hits a secret template. The bootstrap script detects this and prints next steps — re-run bootstrap after signing in and it will pick up where it left off.

## SSH Config

`~/.ssh/config` is managed via a Secure Note in 1Password (`op://Private/SSH Config/notesPlain`) and deployed by chezmoi as a private file (600). The vault item is the source of truth — chezmoi just pulls and applies it.

### Sync after updating SSH config

When you need to add or change a host entry:

1. Edit the **SSH Config** Secure Note in 1Password directly
2. Pull the change to your machine:

```bash
chezmoi apply ~/.ssh/config
```

### Verify the vault item is readable

```bash
op read 'op://Private/SSH Config/notesPlain'
```

### Manual one-off copy from 1Password (work machines)

Work machines don't have `~/.ssh/config` managed by chezmoi. To pull the personal config from the vault temporarily (e.g. to diff and merge host entries):

```bash
cp ~/.ssh/config ~/.ssh/config.bak
op read 'op://Private/SSH Config/notesPlain' > ~/.ssh/config
diff ~/.ssh/config.bak ~/.ssh/config
# Manually merge any work-specific entries back in, then restore:
cp ~/.ssh/config.bak ~/.ssh/config
```

### Initial setup on a new machine

On a fresh machine, `chezmoi apply` handles this automatically once 1Password CLI is authenticated. No manual step needed — the config will be deployed along with everything else.

## Private Files (1Password notes)

This repo is public. Files with private details (agent identity map, global
`CLAUDE.md`, Claude `settings.json`, scheduled-task prompts, a few scripts in
`~/.local/bin`) are stored as 1Password Secure Notes in the `Private` vault. The
repo holds only the list of note names: `.chezmoidata/private_notes.yaml`.

- They deploy only on **personal** machines with `privateNotes = true` under
  `[data]` in `~/.config/chezmoi/chezmoi.toml`. Bootstrap sets it for personal machines.
- After you edit one of these files, push it back before the next `chezmoi apply`:

```bash
op-sync-private                         # every listed file (creates missing notes)
op-sync-private .claude/settings.json   # one file
```

- The atuin sync address also comes from a note (`Dotfiles - atuin sync address`),
  so the homelab domain is not in this repo. Without the opt-in, atuin gets no sync block.
- If you skip 1Password during bootstrap, `DOTFILES_SKIP_1PASSWORD=1` makes chezmoi
  skip every 1Password-backed file. Re-run bootstrap later to deploy them.
- To add a file: add an entry to `private_notes.yaml` and a source template
  that calls `{{ template "private-note" (dict "target" "<path>" "notes" .private_notes) }}`.

## Syncing Secrets Back to 1Password

If you edit `~/.ssh/config` or `~/.kube/config` locally and want to push the changes back to 1Password (so the next `chezmoi apply` on another machine picks them up):

```bash
op-sync-ssh    # Push ~/.ssh/config → 1Password "SSH Config" Secure Note
op-sync-kube   # Push ~/.kube/config → 1Password "Kube Config" Secure Note
```

These functions are available when 1Password CLI is installed (defined in `~/.zshrc.d/07-1password.zsh`).

## Structure

```
dotfiles/
├── bootstrap.sh                     # One-line installer for bare machines
├── dot_chezmoi.toml.tmpl            # chezmoi config + profile/name/email prompts
├── dot_chezmoiignore                # Files excluded from home directory deployment
├── .chezmoidata/
│   └── packages.yaml                # All packages: taps, formulae, casks, mas (sorted alphabetically)
├── setup/                           # One-time machine setup (NOT run by chezmoi apply)
│   ├── setup.sh                     # Stage runner with stamps (--list/--only/--force/--mark-done)
│   ├── Brewfile.tmpl                # Brewfile rendered from packages.yaml + profile
│   ├── report.sh.tmpl               # Post-install report
│   └── stages/                      # 10-homebrew, 20-core, 30-packages, 40-macos-defaults, 50-dock, 60-claude-skills
├── dot_zshrc                        # → ~/.zshrc
├── dot_zshrc.d/                     # → ~/.zshrc.d/ (modular ZSH config)
├── dot_zprofile                     # → ~/.zprofile
├── dot_zshenv                       # → ~/.zshenv
├── dot_gitconfig                    # → ~/.gitconfig
├── dot_config/                      # → ~/.config/ (starship, ghostty, atuin, nvim, zed, SOPS age key, etc.)
├── dot_agents/                      # → ~/.agents/ (agent skills + skill lock)
├── dot_claude/                      # → ~/.claude/ (keybindings, status line, output styles, context-meter mod)
├── dot_local/bin/                   # → ~/.local/bin/ (agent-git, claude-sa, helper scripts)
├── private_dot_kube/                 # → ~/.kube/ (kube config via 1Password)
└── private_dot_ssh/                 # → ~/.ssh/ (SSH config + keys via 1Password)
```

## Troubleshooting

### Package install failures (Homebrew / MAS)

Individual package failures during `brew bundle install` are **non-fatal** — the installer warns and continues to the next package. chezmoi will not abort. After bootstrap completes, check the output for any `WARNING:` lines to see what was skipped.

Common causes:
- **MAS packages** — require being signed into the Mac App Store. If not signed in, all `mas` installs will silently fail. Sign in via the App Store app, then re-run bootstrap.
- **Cask name mismatch** — if a cask was renamed upstream, brew will error on that entry only. Update the name in `.chezmoidata/packages.yaml` and re-run.
- **Network / rate limiting** — transient failures. Re-run `setup.sh --only packages` (or bootstrap; a failed stage has no stamp and runs again).

### Re-running a setup stage

Setup stages never re-run by themselves. Run one on purpose:

```bash
~/.local/share/chezmoi/setup/setup.sh --only macos-defaults
~/.local/share/chezmoi/setup/setup.sh --only dock
```

### bootstrap.sh re-run

The bootstrap command is always safe to re-run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"
```

It detects existing state, pulls the latest dotfiles from origin, and picks up where it left off.
