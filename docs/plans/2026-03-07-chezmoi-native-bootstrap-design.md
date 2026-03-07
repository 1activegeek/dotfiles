# Chezmoi-Native Bootstrap System Design

**Date:** 2026-03-07
**Status:** Approved

## Goal

Consolidate dotfiles management and macOS bootstrap into a single chezmoi-managed repository. Replace the custom bootstrap-mac-os shell scripts with chezmoi's native `run_` script system. The bootstrap-mac-os repo becomes reference-only; this dotfiles repo becomes the single source of truth.

## Constraints

- Dependencies limited to: chezmoi, 1Password CLI, GitHub CLI, MAS, ZSH native functions
- All secrets stored in 1Password, never in the repo
- Must support two machine profiles: `personal` and `work`
- AI agent config unification (.claude, .codex, .opencode) deferred to a later phase

## The 3 Commands

1. **Fresh device:** `curl ... | bash` — installs Homebrew + chezmoi, runs `chezmoi init --apply`
2. **Sync apps + dotfiles:** `chezmoi update && brew-sync`
3. **Sync dotfiles only:** `chezmoi update`

## Repository Structure

```
dotfiles/
├── bootstrap.sh                                  # Minimal shim: Homebrew + chezmoi + init --apply
├── dot_chezmoi.toml.tmpl                         # Profile prompt (personal/work) + 1Password config
├── dot_chezmoiignore                             # Profile-conditional ignores
├── .chezmoidata/
│   └── packages.yaml                             # All brew/cask/mas packages with profile/module tags
│
├── run_once_before_01-install-homebrew.sh.tmpl    # Install Homebrew if missing
├── run_once_before_02-install-core.sh.tmpl        # Install core packages (1Password, gh, mas)
├── run_onchange_before_03-brew-bundle.sh.tmpl     # Generate Brewfile from packages.yaml, brew bundle
├── run_once_after_10-macos-defaults.sh            # macOS system preferences
├── run_once_after_11-dock.sh                      # Dock layout via dockutil
├── run_once_after_12-post-install.sh              # Print post-install checklist
│
├── dot_zprofile                                   # → ~/.zprofile
├── dot_zshrc                                      # → ~/.zshrc
├── dot_zshenv                                     # → ~/.zshenv
├── dot_zshrc.d/                                   # → ~/.zshrc.d/
│   ├── 01-history.zsh ... 16-carapace.zsh
│   └── 17-brew-helpers.zsh                        # brew-export and brew-sync functions
├── dot_gitconfig                                  # → ~/.gitconfig
│
├── dot_config/
│   ├── starship.toml
│   ├── 1Password/
│   ├── atuin/
│   ├── gh/config.yml
│   ├── ghostty/
│   ├── keyboardcowboy/
│   ├── leaderkey/
│   ├── zellij/
│   └── zoxide/                                    # Only if static config exists
│
├── private_dot_config/
│   └── sops/age/keys.txt.tmpl                    # 1Password template for SOPS age key
│
├── private_dot_ssh/
│   ├── config.tmpl                                # 1Password template
│   └── ...                                        # SSH keys via 1Password
│
└── docs/plans/
```

## Profile System

### Selection

During `chezmoi init`, the template prompts for the machine profile:

```toml
# dot_chezmoi.toml.tmpl
[data]
    name = "{{ promptString "Your full name" }}"
    email = "{{ promptString "Your email" }}"
    profile = "{{ promptChoice "Machine profile" "personal" "work" }}"
```

### Package Data (.chezmoidata/packages.yaml)

All packages defined in a single YAML file with module and profile tags:

```yaml
taps:
  - hashicorp/tap
  - anomalyco/tap
  - oven-sh/bun
  - name: fluxcd/tap
    profiles: [personal]
  - name: go-task/tap
    profiles: [personal]

packages:
  - ref: chezmoi
    type: brew
    module: core
  - ref: 1password
    type: cask
    module: core
  # ...
  - ref: bambu-studio
    type: cask
    module: printing3d
    profiles: [personal]
  - ref: microsoft-teams
    type: cask
    module: communication
    profiles: [work]
```

Packages without a `profiles` key install on all profiles. A chezmoi template in the `run_onchange_` script generates the Brewfile from this data, filtering by the active profile.

### Conditional Ignoring

The `.chezmoiignore` file uses templates to exclude profile-specific configs:

```
{{ if eq .profile "work" }}
# Skip personal-only configs on work machines
dot_config/some-personal-app/
{{ end }}
```

## Run Script Execution Order

| Script | Trigger | Purpose |
|--------|---------|---------|
| `run_once_before_01-install-homebrew.sh.tmpl` | Once | Install Homebrew; print pre-install checklist reminder |
| `run_once_before_02-install-core.sh.tmpl` | Once | Install core packages (1Password, 1Password CLI, gh, mas, chezmoi) |
| `run_onchange_before_03-brew-bundle.sh.tmpl` | On package list change | Template packages.yaml → Brewfile, run `brew bundle install` |
| *(chezmoi deploys dotfiles and configs)* | | |
| `run_once_after_10-macos-defaults.sh` | Once | Finder, trackpad, keyboard, security defaults |
| `run_once_after_11-dock.sh` | Once | Dock layout via `dockutil` |
| `run_once_after_12-post-install.sh` | Once | Print manual follow-up checklist |

### Idempotent Convergence

Instead of explicit phase gates, chezmoi's design handles partial failures naturally:
- If 1Password isn't authenticated, templated secrets fail but everything else succeeds
- Re-run `chezmoi apply` after `op signin` to deploy secrets
- `run_once_` scripts won't re-run on subsequent applies
- `run_onchange_` scripts only re-run when their template output changes

## Brew Helper Functions

Managed in `dot_zshrc.d/17-brew-helpers.zsh`:

### brew-export

Dumps current Homebrew state for review/comparison:

```bash
brew bundle dump --file="$(chezmoi source-path)/Brewfile.current" --force
```

### brew-sync

Ensures installed packages match the Brewfile:

1. Run `brew bundle cleanup` (dry-run) to show what would be removed
2. If packages would be removed, prompt for confirmation
3. Run `brew bundle cleanup --force` if confirmed
4. Run `brew bundle install` for any missing packages

## Secrets Management

### 1Password Templates

Files containing secrets use chezmoi's `.tmpl` extension with `onepasswordRead` or `onepassword` template functions:

- `private_dot_ssh/config.tmpl` — SSH config (already exists)
- `private_dot_ssh/*.tmpl` — SSH private keys
- `private_dot_config/sops/age/keys.txt.tmpl` — SOPS age private key

### Secret Detection

During implementation, each new config file will be inspected for tokens, keys, or passwords. If found, it becomes a template with 1Password lookups.

### Not Tracked

- `~/.config/gh/hosts.yml` — OAuth tokens managed by `gh auth login`
- `~/.config/atuin/history.db` — runtime data
- `~/.config/zoxide/db.zo` — runtime data
- Any `*.log`, `*.db`, cache files

## Bootstrap Shim (bootstrap.sh)

A minimal ~30-line script:

1. Install Xcode Command Line Tools (if missing)
2. Install Homebrew (if missing)
3. `brew install chezmoi`
4. `chezmoi init --apply https://github.com/1activegeek/dotfiles.git`

No menus, no phases, no flags. Just get chezmoi running and let it handle everything.

## README

The README will be rewritten to cover:
- The 3 one-liner commands (prominent, at the top)
- What gets installed (brief category list)
- Machine profiles (how to choose, how to switch)
- Managing packages (add/remove, brew-export, brew-sync)
- Managing dotfiles (chezmoi edit, diff, cd, add)
- Secrets (1Password integration)
- Repository structure

Kept brief and practical — focused on usage, not implementation.

## Deferred

- AI agent config unification (.claude, .codex, .opencode shared skills/agents)
- Windows machine adaptation
- Automated periodic Brewfile export (LaunchAgent)
