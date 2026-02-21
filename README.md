# dotfiles

Reference files for the chezmoi-managed dotfiles repo.

These files live in a **separate private/public repo** at `github.com/1activegeek/dotfiles`
and are managed by [chezmoi](https://www.chezmoi.io/).

## Structure

```
dotfiles/
├── dot_zprofile           → ~/.zprofile
├── dot_zshrc              → ~/.zshrc
├── dot_zshrc.d/           → ~/.zshrc.d/ (15 modular ZSH files)
├── dot_gitconfig          → ~/.gitconfig (chezmoi template)
├── dot_chezmoi.toml.tmpl  → ~/.config/chezmoi/chezmoi.toml
├── dot_chezmoiignore      → ~/.chezmoiignore
├── dot_config/
│   └── starship.toml      → ~/.config/starship.toml
└── private_dot_ssh/       → ~/.ssh/ (1Password-templated, encrypted)
    ├── config.tmpl
    └── id_ed25519.tmpl
```

## Usage

```bash
# Initialise on a new machine
chezmoi init https://github.com/1activegeek/dotfiles.git

# Apply dotfiles
chezmoi apply

# Edit a managed file
chezmoi edit ~/.zshrc

# See what would change
chezmoi diff

# Pull latest and apply
chezmoi update
```

## Secrets

Sensitive files (SSH keys) use chezmoi templates that pull secrets from 1Password.
Run `op signin` before `chezmoi apply` to deploy these files.
