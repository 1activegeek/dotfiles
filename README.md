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
| Dev CLI | atuin, bat, eza, fd, fzf, starship, zellij, zoxide |
| Dev GUI | VS Code, Docker, OrbStack, Claude, Codex |
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

If 1Password isn't ready, chezmoi skips secret-templated files and continues — re-run `chezmoi apply` after signing in.

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
├── dot_config/                      # → ~/.config/ (starship, ghostty, atuin, etc.)
├── private_dot_config/              # → ~/.config/ (SOPS age key — secret)
└── private_dot_ssh/                 # → ~/.ssh/ (SSH config + keys via 1Password)
```
