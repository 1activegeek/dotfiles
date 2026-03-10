# dotfiles

Personal macOS setup managed by [chezmoi](https://www.chezmoi.io/).
One command to set up a new Mac. One command to keep it in sync.

## Quick Start

### Set up a new machine

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"
```

This installs Xcode CLI Tools, Homebrew, and chezmoi, then applies all dotfiles, packages, and system preferences automatically.

### Sync everything (apps + dotfiles)

```bash
chezmoi update && brew-sync
```

Pulls the latest dotfiles and applies them. `brew-sync` installs any missing packages and optionally removes packages not in the catalog (with confirmation prompt).

### Sync dotfiles only

```bash
chezmoi update
```

## What Gets Installed

All packages are defined in `.chezmoidata/packages.yaml` and installed via `brew bundle`:

| Category | Tools |
|---|---|
| Core | chezmoi, 1Password, Brave, Ghostty, Raycast |
| Dev | atuin, bat, eza, fzf, starship, zellij, VS Code, Docker, OrbStack, Claude, Codex |
| Browsers | Chrome, Tor |
| Communication | Slack, Discord, Zoom |
| AI | ChatGPT, Ollama, LM Studio |
| Infra | kubectl, helm, k9s, Terraform |
| 3D Printing | Bambu Studio, OrcaSlicer, PrusaSlicer *(personal only)* |
| Security | LuLu, BlockBlock, KnockKnock |
| Utilities | Obsidian, Tailscale, Keka, Shottr, and more |

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

**Add a package:** Edit `.chezmoidata/packages.yaml`, add the entry, then run `chezmoi apply` — the brew bundle script re-runs automatically when the package list changes.

**Remove a package:** Remove from `packages.yaml`, then run `brew-sync` to uninstall it.

**See what's installed vs what's in the catalog:**

```bash
brew-export   # Dumps current Homebrew state to Brewfile.current for comparison
```

## Managing Dotfiles

```bash
chezmoi add ~/.config/app/config    # Start managing a new file
chezmoi edit ~/.config/app/config   # Edit a managed file
chezmoi diff                        # Preview what would change
chezmoi apply                       # Apply changes to home directory
chezmoi update                      # Pull latest from git and apply
chezmoi cd                          # Open the chezmoi source directory
```

## Secrets

SSH keys and SOPS age keys are stored in 1Password and deployed via chezmoi templates. Before running `chezmoi apply` on a fresh machine:

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

## Structure

```
dotfiles/
├── bootstrap.sh                     # One-line installer for bare machines
├── dot_chezmoi.toml.tmpl            # chezmoi config + profile/name/email prompts
├── dot_chezmoiignore                # Files excluded from home directory deployment
├── .chezmoidata/
│   └── packages.yaml                # All packages (brew/cask/mas) with profile tags
├── run_once_before_01-*             # Installs Homebrew (runs once)
├── run_once_before_02-*             # Installs core packages (runs once)
├── run_onchange_before_03-*         # Runs brew bundle (re-runs when packages change)
├── run_once_after_10-*              # Applies macOS defaults (runs once)
├── run_once_after_11-*              # Configures Dock (runs once)
├── run_once_after_12-*              # Post-install checklist (runs once)
├── dot_zshrc                        # → ~/.zshrc
├── dot_zshrc.d/                     # → ~/.zshrc.d/ (modular ZSH config)
├── dot_zprofile                     # → ~/.zprofile
├── dot_zshenv                       # → ~/.zshenv
├── dot_gitconfig                    # → ~/.gitconfig
├── dot_config/                      # → ~/.config/ (starship, ghostty, atuin, SOPS age key, etc.)
└── private_dot_ssh/                 # → ~/.ssh/ (SSH config + keys via 1Password)
```

## Troubleshooting

### Package install failures (Homebrew / MAS)

Individual package failures during `brew bundle install` are **non-fatal** — the installer warns and continues to the next package. chezmoi will not abort. After bootstrap completes, check the output for any `WARNING:` lines to see what was skipped.

Common causes:
- **MAS packages** — require being signed into the Mac App Store. If not signed in, all `mas` installs will silently fail. Sign in via the App Store app, then re-run bootstrap.
- **Cask name mismatch** — if a cask was renamed upstream, brew will error on that entry only. Update the name in `.chezmoidata/packages.yaml` and re-run.
- **Network / rate limiting** — transient failures. Re-running bootstrap will re-attempt the brew bundle since `run_onchange_` re-runs whenever packages.yaml changes.

### Forcing `run_once_` scripts to re-run

chezmoi marks `run_once_` scripts as done after their first successful execution and never re-runs them, even if you fix a bug in them. To force a re-run:

```bash
# Reset all run_once script state (they will all re-run on next apply)
chezmoi state delete-bucket --bucket=scriptState

# Then re-apply
chezmoi apply
```

To reset a single script, you can delete just its state entry by name using `chezmoi state` — run `chezmoi state dump` to see the current entries.

### bootstrap.sh re-run

The bootstrap command is always safe to re-run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"
```

It detects existing state, pulls the latest dotfiles from origin, and picks up where it left off.
