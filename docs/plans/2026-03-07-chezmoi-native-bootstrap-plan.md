# Chezmoi-Native Bootstrap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the custom bootstrap-mac-os shell scripts with chezmoi-native run scripts, profile templates, and YAML-driven package management — all in a single dotfiles repo.

**Architecture:** Everything runs through chezmoi. A minimal `bootstrap.sh` shim installs chezmoi on bare machines, then `chezmoi init --apply` triggers `run_once_before_` scripts (Homebrew, core packages), `run_onchange_` scripts (Brewfile generation from YAML), dotfile deployment, and `run_once_after_` scripts (macOS defaults, dock, post-install). Machine profiles (personal/work) are set during `chezmoi init` and drive conditional package installation and config deployment.

**Tech Stack:** chezmoi, ZSH, Homebrew, 1Password CLI, macOS `defaults`

**Reference repo:** `../bootstrap-mac-os` — use modules/, config/, Brewfile, and profiles/ as reference for content. Do NOT copy the dotfiles/ subfolder from that repo.

---

### Task 1: Update Profile Prompt in chezmoi.toml Template

**Files:**
- Modify: `dot_chezmoi.toml.tmpl`

**Context:** The current template uses `promptStringOnce` with a free-text "Profile overlay" prompt. We need to change it to a structured choice between `personal` and `work`. chezmoi v2.40+ supports `promptChoiceOnce`.

**Step 1: Read the current template**

Read `dot_chezmoi.toml.tmpl` to understand the existing structure.

**Step 2: Update the profile prompt**

Replace the profile prompt line with `promptChoiceOnce`:

```
{{- $profile := promptChoiceOnce . "profile" "Machine profile" (list "personal" "work") -}}
```

Keep the name and email prompts as-is. The full file should be:

```
{{- $profile := promptChoiceOnce . "profile" "Machine profile" (list "personal" "work") -}}
{{- $name    := promptStringOnce . "name"    "Git full name" -}}
{{- $email   := promptStringOnce . "email"   "Git email address" -}}

[data]
  profile = {{ $profile | quote }}
  name    = {{ $name    | quote }}
  email   = {{ $email   | quote }}

[onepassword]
  command = "op"

[edit]
  command = "code"
  args    = ["--wait"]

[diff]
  pager = "less -R"
```

**Step 3: Verify template syntax**

Run: `chezmoi execute-template < dot_chezmoi.toml.tmpl`

This will prompt interactively. Verify it outputs valid TOML with the profile key.

**Step 4: Commit**

```bash
git add dot_chezmoi.toml.tmpl
git commit -m "feat: update profile prompt to personal/work choice"
```

---

### Task 2: Create Package Data File (.chezmoidata/packages.yaml)

**Files:**
- Create: `.chezmoidata/packages.yaml`

**Context:** This YAML file replaces both the Brewfile and config/package-catalog.sh from bootstrap-mac-os. All packages are defined here with `type`, `module`, and optional `profiles` tags. Packages without a `profiles` key install on all profiles.

**Reference files to consult:**
- `../bootstrap-mac-os/Brewfile` — full package list with comments
- `../bootstrap-mac-os/profiles/Brewfile.default` — profile-specific packages
- `../bootstrap-mac-os/config/package-catalog.sh` — module assignments

**Step 1: Create the .chezmoidata directory**

```bash
mkdir -p .chezmoidata
```

**Step 2: Create packages.yaml**

Build the YAML file from the reference Brewfile and package-catalog.sh. The structure:

```yaml
# .chezmoidata/packages.yaml
# All Homebrew packages, casks, and Mac App Store apps.
# Sorted alphabetically within each section.
# Packages without a 'profiles' key install on all profiles.

taps:
  - hashicorp/tap
  - anomalyco/tap
  - oven-sh/bun
  - name: fluxcd/tap
    profiles: [personal]
  - name: go-task/tap
    profiles: [personal]

packages:
  # ── Core (installed first, before other packages) ──────────────
  - { ref: chezmoi,        type: brew, module: core }
  - { ref: gh,             type: brew, module: core }
  - { ref: mas,            type: brew, module: core }
  - { ref: 1password,      type: cask, module: core }
  - { ref: 1password-cli,  type: cask, module: core }
  - { ref: brave-browser,  type: cask, module: core }
  - { ref: ghostty,        type: cask, module: core }
  - { ref: handy,          type: cask, module: core }
  - { ref: raycast,        type: cask, module: core }

  # ── Developer CLI ──────────────────────────────────────────────
  - { ref: atuin,                    type: brew, module: dev-cli }
  - { ref: bat,                      type: brew, module: dev-cli }
  - { ref: bat-extras,               type: brew, module: dev-cli }
  - { ref: carapace,                 type: brew, module: dev-cli }
  - { ref: chroma,                   type: brew, module: dev-cli }
  - { ref: dockutil,                 type: brew, module: dev-cli }
  - { ref: duti,                     type: brew, module: dev-cli }
  - { ref: eza,                      type: brew, module: dev-cli }
  - { ref: fastfetch,                type: brew, module: dev-cli }
  - { ref: fd,                       type: brew, module: dev-cli }
  - { ref: ffmpeg,                   type: brew, module: dev-cli }
  - { ref: fzf,                      type: brew, module: dev-cli }
  - { ref: oven-sh/bun/bun,         type: brew, module: dev-cli }
  - { ref: pygments,                 type: brew, module: dev-cli }
  - { ref: starship,                 type: brew, module: dev-cli }
  - { ref: switchaudio-osx,          type: brew, module: dev-cli }
  - { ref: tmux,                     type: brew, module: dev-cli }
  - { ref: watch,                    type: brew, module: dev-cli }
  - { ref: yt-dlp,                   type: brew, module: dev-cli }
  - { ref: zellij,                   type: brew, module: dev-cli }
  - { ref: zoxide,                   type: brew, module: dev-cli }
  - { ref: zsh-autosuggestions,      type: brew, module: dev-cli }
  - { ref: zsh-syntax-highlighting,  type: brew, module: dev-cli }
  - { ref: anomalyco/tap/opencode,   type: brew, module: dev-cli }

  # ── Developer GUI ──────────────────────────────────────────────
  - { ref: antigravity,       type: cask, module: dev-gui }
  - { ref: claude,            type: cask, module: dev-gui }
  - { ref: claude-code,       type: cask, module: dev-gui }
  - { ref: codex,             type: cask, module: dev-gui }
  - { ref: docker,            type: cask, module: dev-gui }
  - { ref: gcloud-cli,        type: cask, module: dev-gui }
  - { ref: opencode-desktop,  type: cask, module: dev-gui }
  - { ref: orbstack,          type: cask, module: dev-gui }
  - { ref: visual-studio-code, type: cask, module: dev-gui }
  - { ref: yaak,              type: cask, module: dev-gui }

  # ── Browsers ───────────────────────────────────────────────────
  - { ref: google-chrome,  type: cask, module: browsers }
  - { ref: tor-browser,    type: cask, module: browsers }

  # ── Communication ──────────────────────────────────────────────
  - { ref: discord,          type: cask, module: communication }
  - { ref: slack,            type: cask, module: communication }
  - { ref: zoom,             type: cask, module: communication }
  - { ref: microsoft-teams,  type: cask, module: communication, profiles: [work] }

  # ── AI Tools ───────────────────────────────────────────────────
  - { ref: chatgpt,     type: cask, module: ai }
  - { ref: lm-studio,   type: cask, module: ai }
  - { ref: ollama,       type: cask, module: ai }
  - { ref: fabric-ai,   type: brew, module: ai }
  - { ref: gemini-cli,   type: brew, module: ai }

  # ── Media ──────────────────────────────────────────────────────
  - { ref: handbrake, type: cask, module: media }
  - { ref: kap,       type: cask, module: media }
  - { ref: obs,       type: cask, module: media }
  - { ref: vlc,       type: cask, module: media }

  # ── Utilities ──────────────────────────────────────────────────
  - { ref: appcleaner,      type: cask, module: utilities }
  - { ref: balenaetcher,     type: cask, module: utilities }
  - { ref: browserosaurus,   type: cask, module: utilities }
  - { ref: disk-inventory-x, type: cask, module: utilities }
  - { ref: flux,             type: cask, module: utilities }
  - { ref: home-assistant,   type: cask, module: utilities }
  - { ref: keka,             type: cask, module: utilities }
  - { ref: keyboard-cowboy,  type: cask, module: utilities }
  - { ref: knockknock,       type: cask, module: utilities }
  - { ref: leader-key,       type: cask, module: utilities }
  - { ref: lunar,            type: cask, module: utilities }
  - { ref: mactracker,       type: cask, module: utilities }
  - { ref: obsidian,         type: cask, module: utilities }
  - { ref: shottr,           type: cask, module: utilities }
  - { ref: superwhisper,     type: cask, module: utilities }
  - { ref: tailscale,        type: cask, module: utilities }
  - { ref: taskexplorer,     type: cask, module: utilities }
  - { ref: thaw,             type: cask, module: utilities }
  - { ref: the-unarchiver,   type: cask, module: utilities }

  # ── Infrastructure / Kubernetes ────────────────────────────────
  - { ref: age,                       type: brew, module: infra }
  - { ref: awscli,                    type: brew, module: infra }
  - { ref: helm,                      type: brew, module: infra }
  - { ref: k9s,                       type: brew, module: infra }
  - { ref: kube-ps1,                  type: brew, module: infra }
  - { ref: kubectx,                   type: brew, module: infra }
  - { ref: kubernetes-cli,            type: brew, module: infra }
  - { ref: mole,                      type: brew, module: infra }
  - { ref: hashicorp/tap/terraform,   type: brew, module: infra }
  - { ref: azure-cli,                 type: brew, module: infra }
  - { ref: direnv,                    type: brew, module: infra, profiles: [personal] }
  - { ref: fluxcd/tap/flux,           type: brew, module: infra, profiles: [personal] }
  - { ref: go-task/tap/go-task,       type: brew, module: infra, profiles: [personal] }
  - { ref: ipcalc,                    type: brew, module: infra, profiles: [personal] }
  - { ref: jq,                        type: brew, module: infra }
  - { ref: kustomize,                 type: brew, module: infra, profiles: [personal] }
  - { ref: pre-commit,                type: brew, module: infra, profiles: [personal] }
  - { ref: sops,                      type: brew, module: infra, profiles: [personal] }
  - { ref: yamllint,                  type: brew, module: infra, profiles: [personal] }

  # ── 3D Printing / CAD ─────────────────────────────────────────
  - { ref: bambu-studio,      type: cask, module: printing3d, profiles: [personal] }
  - { ref: eufymake-studio,   type: cask, module: printing3d, profiles: [personal] }
  - { ref: openscad@snapshot, type: cask, module: printing3d, profiles: [personal] }
  - { ref: orcaslicer,        type: cask, module: printing3d, profiles: [personal] }
  - { ref: prusaslicer,       type: cask, module: printing3d, profiles: [personal] }
  - { ref: shapr3d,           type: cask, module: printing3d, profiles: [personal] }
  - { ref: thumbhost3mf,      type: cask, module: printing3d, profiles: [personal] }

  # ── Security ───────────────────────────────────────────────────
  - { ref: blockblock,   type: cask, module: security }
  - { ref: lulu,         type: cask, module: security }

  # ── Fonts ──────────────────────────────────────────────────────
  - { ref: font-jetbrains-mono-nerd-font, type: cask, module: fonts }

  # ── Mac App Store ──────────────────────────────────────────────
  # Safari Extensions
  - { ref: "1569813296", type: mas, module: mas, name: "1Password for Safari" }
  - { ref: "1546729687", type: mas, module: mas, name: "Auto HD FPS for YouTube" }
  - { ref: "1482920575", type: mas, module: mas, name: "DuckDuckGo Privacy Essentials" }
  - { ref: "1544743900", type: mas, module: mas, name: "Hush" }
  - { ref: "1472777122", type: mas, module: mas, name: "PayPal Honey" }
  - { ref: "1532579087", type: mas, module: mas, name: "The Camelizer" }
  - { ref: "6745342698", type: mas, module: mas, name: "uBlock Origin Lite" }
  - { ref: "1463298887", type: mas, module: mas, name: "Userscripts" }
  # Obsidian extensions
  - { ref: "6720708363", type: mas, module: mas, name: "Obsidian Web Clipper" }
  # Productivity
  - { ref: "1586435171", type: mas, module: mas, name: "Actions" }
  - { ref: "1453273600", type: mas, module: mas, name: "Data Jar" }
  - { ref: "663592361",  type: mas, module: mas, name: "DuckDuckGo" }
  - { ref: "1295203466", type: mas, module: mas, name: "Microsoft Remote Desktop" }
  - { ref: "6714467650", type: mas, module: mas, name: "Perplexity" }
  - { ref: "6738274497", type: mas, module: mas, name: "Raycast Companion" }
  - { ref: "497799835",  type: mas, module: mas, name: "Xcode" }
  # Work-only MAS
  - { ref: "490179405",  type: mas, module: mas, name: "Okta Verify", profiles: [work] }
```

**Step 3: Verify YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.chezmoidata/packages.yaml'))"`

If python3 doesn't have PyYAML, use: `chezmoi execute-template '{{ .packages | toJson }}' 2>&1 | head -5` — if chezmoi loads the data file, it's valid.

**Step 4: Commit**

```bash
git add .chezmoidata/packages.yaml
git commit -m "feat: add YAML-driven package catalog with profile tags"
```

---

### Task 3: Create Bootstrap Shim (bootstrap.sh)

**Files:**
- Create: `bootstrap.sh`

**Context:** Minimal script that gets chezmoi running on a bare macOS machine. Reference `../bootstrap-mac-os/modules/01-homebrew.sh` for the Homebrew install pattern and `../bootstrap-mac-os/bootstrap.sh` for the Xcode CLI tools pattern.

**Step 1: Create bootstrap.sh**

```bash
#!/usr/bin/env bash
# bootstrap.sh — Minimal bootstrap for a bare macOS machine.
# Installs Xcode CLI Tools, Homebrew, and chezmoi, then hands off
# to chezmoi for everything else.
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"

set -euo pipefail

echo "==> Installing Xcode Command Line Tools (if needed)..."
if ! xcode-select -p &>/dev/null; then
  xcode-select --install
  echo "    Waiting for Xcode CLI tools..."
  until xcode-select -p &>/dev/null; do sleep 5; done
fi

echo "==> Installing Homebrew (if needed)..."
if ! command -v brew &>/dev/null; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "==> Installing chezmoi..."
brew install chezmoi

echo "==> Initializing dotfiles..."
chezmoi init --apply https://github.com/1activegeek/dotfiles.git

echo "==> Done! Restart your shell or run: exec zsh -l"
```

**Step 2: Make it executable**

```bash
chmod +x bootstrap.sh
```

**Step 3: Add to .chezmoiignore**

The bootstrap.sh file should NOT be deployed to the home directory. Add it to `.chezmoiignore`:

```
bootstrap.sh
docs/
```

**Step 4: Commit**

```bash
git add bootstrap.sh dot_chezmoiignore
git commit -m "feat: add minimal bootstrap shim for bare machine setup"
```

---

### Task 4: Create run_once_before_01 — Install Homebrew

**Files:**
- Create: `run_once_before_01-install-homebrew.sh.tmpl`

**Context:** This chezmoi run script ensures Homebrew is installed before any packages. It also shows a one-time pre-install checklist. The `.tmpl` extension lets chezmoi process it as a template (needed for the checklist to reference `.chezmoi.os`). Reference `../bootstrap-mac-os/modules/01-homebrew.sh` functions `ensure_xcode_cli` and `ensure_homebrew`.

**Step 1: Create the run script**

```bash
#!/bin/bash
# chezmoi:template:left-delimiter="{{" right-delimiter="}}"
# run_once_before_01-install-homebrew.sh.tmpl
# Ensures Xcode CLI Tools and Homebrew are installed.
# Runs once per machine (chezmoi tracks this).

set -euo pipefail

{{ if eq .chezmoi.os "darwin" -}}

echo ""
echo "══════════════════════════════════════════════"
echo "  PRE-INSTALL CHECKLIST"
echo "══════════════════════════════════════════════"
echo ""
echo "  Before continuing, please ensure:"
echo "  [ ] Signed into Apple ID"
echo "  [ ] Signed into Mac App Store"
echo "  [ ] iCloud sync complete (Documents/Desktop)"
echo ""

# Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
  echo "==> Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "    Waiting for installation to complete..."
  until xcode-select -p &>/dev/null; do sleep 5; done
fi
echo "==> Xcode CLI Tools: OK"

# Homebrew
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

echo "==> Disabling Homebrew analytics..."
brew analytics off

echo "==> Updating Homebrew..."
brew update --quiet

echo "==> Homebrew: OK"

{{ end -}}
```

**Step 2: Verify the template renders**

Run: `chezmoi cat run_once_before_01-install-homebrew.sh.tmpl 2>/dev/null || chezmoi execute-template < run_once_before_01-install-homebrew.sh.tmpl`

Verify the output is valid bash with the conditional resolved.

**Step 3: Commit**

```bash
git add run_once_before_01-install-homebrew.sh.tmpl
git commit -m "feat: add run_once script to install Homebrew"
```

---

### Task 5: Create run_once_before_02 — Install Core Packages

**Files:**
- Create: `run_once_before_02-install-core.sh.tmpl`

**Context:** Installs the bare minimum packages needed before chezmoi can deploy secrets and configs: 1Password, 1Password CLI, gh, mas. These must be installed before the full Brewfile run because chezmoi needs `op` for secret templates. Reference the `core` module in `../bootstrap-mac-os/config/package-catalog.sh`.

**Step 1: Create the run script**

```bash
#!/bin/bash
# run_once_before_02-install-core.sh.tmpl
# Installs core packages needed before chezmoi can deploy secrets.

set -euo pipefail

{{ if eq .chezmoi.os "darwin" -}}

eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"

echo "==> Installing core packages..."

CORE_FORMULAE=(chezmoi gh mas)
CORE_CASKS=(1password 1password-cli brave-browser ghostty handy raycast)

for formula in "${CORE_FORMULAE[@]}"; do
  if ! brew list --formula "$formula" &>/dev/null; then
    echo "    Installing formula: $formula"
    brew install "$formula" || echo "    WARNING: Failed to install $formula"
  fi
done

for cask in "${CORE_CASKS[@]}"; do
  if ! brew list --cask "$cask" &>/dev/null; then
    echo "    Installing cask: $cask"
    HOMEBREW_CASK_OPTS="--no-quarantine" brew install --cask "$cask" || echo "    WARNING: Failed to install $cask"
  fi
done

echo "==> Core packages: OK"

echo ""
echo "══════════════════════════════════════════════"
echo "  1PASSWORD SETUP"
echo "══════════════════════════════════════════════"
echo ""
echo "  To deploy SSH keys and secrets, you need to:"
echo "  1. Open 1Password and sign in"
echo "  2. Enable CLI integration (Settings > Developer > CLI)"
echo "  3. Run: op signin"
echo ""
echo "  Then re-run: chezmoi apply"
echo ""

{{ end -}}
```

**Step 2: Commit**

```bash
git add run_once_before_02-install-core.sh.tmpl
git commit -m "feat: add run_once script to install core packages"
```

---

### Task 6: Create run_onchange_before_03 — Brew Bundle from YAML

**Files:**
- Create: `run_onchange_before_03-brew-bundle.sh.tmpl`

**Context:** This is the key script. It templates `packages.yaml` into a Brewfile and runs `brew bundle install`. The `run_onchange_` prefix means chezmoi re-runs it whenever the template output changes (i.e., when packages.yaml is modified). The template filters packages by the active profile.

chezmoi's `run_onchange_` mechanism: chezmoi hashes the script content after template expansion. If the hash changes, the script re-runs. So we embed the generated Brewfile content as a comment block at the top — when packages change, the hash changes, triggering a re-run.

**Step 1: Create the run script**

```bash
#!/bin/bash
# run_onchange_before_03-brew-bundle.sh.tmpl
# Generates a Brewfile from .chezmoidata/packages.yaml and runs brew bundle.
# Re-runs automatically when the package list changes.

set -euo pipefail

{{ if eq .chezmoi.os "darwin" -}}

eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"

BREWFILE="$(mktemp)"
trap 'rm -f "$BREWFILE"' EXIT

cat > "$BREWFILE" << 'BREWFILE_CONTENT'
# Auto-generated from .chezmoidata/packages.yaml
# Profile: {{ .profile }}

# Taps
{{ range .taps -}}
  {{ if kindIs "string" . -}}
tap "{{ . }}"
  {{ else -}}
    {{ if or (not (hasKey . "profiles")) (has $.profile .profiles) -}}
tap "{{ .name }}"
    {{ end -}}
  {{ end -}}
{{ end -}}

# Packages
{{ range .packages -}}
  {{ if or (not (hasKey . "profiles")) (has $.profile .profiles) -}}
    {{ if eq .type "brew" -}}
brew "{{ .ref }}"
    {{ else if eq .type "cask" -}}
cask "{{ .ref }}"
    {{ else if eq .type "mas" -}}
mas "{{ .name }}", id: {{ .ref }}
    {{ end -}}
  {{ end -}}
{{ end -}}
BREWFILE_CONTENT

echo "==> Running brew bundle install..."
brew bundle install --file="$BREWFILE" --no-lock || {
  echo "    WARNING: Some packages failed to install. Continuing..."
}

echo "==> Cleaning up..."
brew cleanup --prune=all -q 2>/dev/null || true

echo "==> Brew bundle: OK"

{{ end -}}
```

**Important implementation note:** The template references `.taps` and `.packages` which come from `.chezmoidata/packages.yaml`. chezmoi automatically merges `.chezmoidata/` files into the template data. The `.profile` comes from `dot_chezmoi.toml.tmpl`. Verify this works by checking `chezmoi data` output includes both.

**Step 2: Verify template data is accessible**

Run: `chezmoi data | grep -A2 '"profile"'`

This should show the profile value. Then check packages are loaded:

Run: `chezmoi data | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('packages',[])), 'packages')" 2>/dev/null`

**Step 3: Verify the template renders a valid Brewfile**

Run: `chezmoi execute-template < run_onchange_before_03-brew-bundle.sh.tmpl`

Inspect the output — it should be a bash script with an embedded Brewfile containing `tap`, `brew`, `cask`, and `mas` lines. Only packages matching the active profile should appear.

**Step 4: Commit**

```bash
git add run_onchange_before_03-brew-bundle.sh.tmpl
git commit -m "feat: add run_onchange script for YAML-driven brew bundle"
```

---

### Task 7: Create Brew Helper Functions (brew-export, brew-sync)

**Files:**
- Create: `dot_zshrc.d/17-brew-helpers.zsh`

**Context:** Two shell functions for day-to-day Homebrew management. `brew-export` dumps current state for comparison. `brew-sync` installs missing packages and optionally removes untracked ones (with confirmation).

**Step 1: Create the file**

```bash
# 17-brew-helpers.zsh — Homebrew sync and export helpers

# Export current Homebrew state to chezmoi source for comparison
brew-export() {
  local output
  output="$(chezmoi source-path)/Brewfile.current"
  echo "Exporting current Homebrew state to: $output"
  brew bundle dump --file="$output" --force
  echo "Done. Compare with packages.yaml to see drift."
}

# Sync installed packages with the chezmoi-managed Brewfile
brew-sync() {
  local brewfile
  brewfile="$(chezmoi source-path)/Brewfile.current"

  # First generate the current target Brewfile
  echo "==> Generating Brewfile from chezmoi data..."
  chezmoi execute-template < "$(chezmoi source-path)/run_onchange_before_03-brew-bundle.sh.tmpl" \
    | sed -n '/^cat > "\$BREWFILE"/,/^BREWFILE_CONTENT$/p' \
    | sed '1d;$d' > "$brewfile" 2>/dev/null

  # If that didn't work, fall back to re-applying the script
  if [[ ! -s "$brewfile" ]]; then
    echo "    Falling back to chezmoi apply for brew bundle..."
    chezmoi apply --include=scripts
    return
  fi

  # Install missing packages
  echo "==> Installing missing packages..."
  brew bundle install --file="$brewfile" --no-lock || true

  # Check for packages to remove
  echo "==> Checking for packages not in Brewfile..."
  local cleanup_output
  cleanup_output="$(brew bundle cleanup --file="$brewfile" 2>/dev/null)"

  if [[ -n "$cleanup_output" ]]; then
    echo ""
    echo "The following packages are NOT in your Brewfile:"
    echo "$cleanup_output"
    echo ""
    read -rp "Remove these packages? [y/N]: " confirm
    if [[ "$(echo "${confirm:-n}" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
      brew bundle cleanup --file="$brewfile" --force
      echo "==> Cleanup complete."
    else
      echo "==> Skipped cleanup."
    fi
  else
    echo "==> All packages match the Brewfile."
  fi

  rm -f "$brewfile"
}
```

**Step 2: Commit**

```bash
git add dot_zshrc.d/17-brew-helpers.zsh
git commit -m "feat: add brew-export and brew-sync shell functions"
```

---

### Task 8: Create run_once_after_10 — macOS Defaults

**Files:**
- Create: `run_once_after_10-macos-defaults.sh`

**Context:** Port `../bootstrap-mac-os/modules/03-macos-defaults.sh` as a standalone chezmoi run script. Remove the `log_info`/`log_substep`/`log_success`/`log_warn` calls (those were from the bootstrap lib/utils.sh) and replace with plain `echo`. Keep all the `defaults write` commands exactly as-is.

**Step 1: Read the source module**

Read `../bootstrap-mac-os/modules/03-macos-defaults.sh` for the full content.

**Step 2: Create the run script**

Copy the content from the reference module. Replace all logging calls:
- `log_info "..."` → `echo "==> ..."`
- `log_substep "..."` → `echo "    ..."`
- `log_success "..."` → `echo "==> ✓ ..."`
- `log_warn "..."` → `echo "    ⚠ ..."`
- `log_debug "..."` → remove (or `echo` with a `# debug` comment)

Add the shebang and set flags at the top:

```bash
#!/bin/bash
# run_once_after_10-macos-defaults.sh
# Applies macOS system preferences via defaults write.
# Runs once per machine.

set -euo pipefail

[[ "$(uname)" != "Darwin" ]] && exit 0

# [paste all defaults write commands from 03-macos-defaults.sh with updated logging]
```

Keep the `killall Dock`, `killall Finder`, `killall SystemUIServer` at the end.

**Step 3: Commit**

```bash
git add run_once_after_10-macos-defaults.sh
git commit -m "feat: add run_once script for macOS defaults"
```

---

### Task 9: Create run_once_after_11 — Dock Configuration

**Files:**
- Create: `run_once_after_11-dock.sh`

**Context:** Port `../bootstrap-mac-os/modules/04-dock.sh`. Replace logging calls. Replace `command_exists` with `command -v`. Keep the `dockutil` commands exactly as-is.

**Step 1: Read the source module**

Read `../bootstrap-mac-os/modules/04-dock.sh`.

**Step 2: Create the run script**

```bash
#!/bin/bash
# run_once_after_11-dock.sh
# Configures the macOS Dock via dockutil.
# Runs once per machine.

set -euo pipefail

[[ "$(uname)" != "Darwin" ]] && exit 0

if ! command -v dockutil &>/dev/null; then
  echo "    ⚠ dockutil not installed, skipping Dock configuration"
  exit 0
fi

# [paste all dockutil commands from 04-dock.sh with updated logging]
```

Replace `log_*` calls the same way as Task 8. Replace `command_exists` with `command -v ... &>/dev/null`. Replace `return 1` with `exit 1`.

**Step 3: Commit**

```bash
git add run_once_after_11-dock.sh
git commit -m "feat: add run_once script for Dock configuration"
```

---

### Task 10: Create run_once_after_12 — Post-Install Checklist

**Files:**
- Create: `run_once_after_12-post-install.sh`

**Context:** Port `../bootstrap-mac-os/modules/10-post-install.sh`. Simplify — remove the tool-checking logic (it used bootstrap-specific helpers). Keep the manual steps checklist and app settings notes. Replace `command_exists` with `command -v`.

**Step 1: Create the run script**

```bash
#!/bin/bash
# run_once_after_12-post-install.sh
# Prints post-install validation and manual checklist.
# Runs once per machine.

set -euo pipefail

[[ "$(uname)" != "Darwin" ]] && exit 0

echo ""
echo "══════════════════════════════════════════════"
echo "  POST-INSTALL VALIDATION"
echo "══════════════════════════════════════════════"
echo ""

# Tool status check
TOOLS=(brew chezmoi starship atuin zoxide eza fzf zellij op dockutil fastfetch git)
NAMES=(Homebrew chezmoi Starship Atuin Zoxide eza fzf Zellij "1Password CLI" dockutil fastfetch Git)

echo "  Tool Status:"
echo "  ─────────────────────────────────────────"

pass=0
fail=0
for i in "${!TOOLS[@]}"; do
  if command -v "${TOOLS[$i]}" &>/dev/null; then
    printf "  ✓  %-20s\n" "${NAMES[$i]}"
    (( pass++ ))
  else
    printf "  ?  %-20s  (not found)\n" "${NAMES[$i]}"
    (( fail++ ))
  fi
done

echo "  ─────────────────────────────────────────"
echo "  ${pass} available, ${fail} not found"
echo ""

# System summary
echo "  System Summary:"
echo "  ─────────────────────────────────────────"
printf "  %-18s %s\n" "Hostname:" "$(scutil --get ComputerName 2>/dev/null || echo 'unknown')"
printf "  %-18s %s\n" "macOS:" "$(sw_vers -productVersion)"
printf "  %-18s %s\n" "Shell:" "${SHELL}"
printf "  %-18s %s\n" "Chezmoi:" "$(chezmoi --version 2>/dev/null | head -1 || echo 'n/a')"

managed="$(chezmoi managed 2>/dev/null | wc -l | tr -d ' ')"
printf "  %-18s %s files\n" "Managed files:" "$managed"
echo "  ─────────────────────────────────────────"

# fastfetch
if command -v fastfetch &>/dev/null; then
  echo ""
  fastfetch
fi

# Manual steps
echo ""
echo "  Manual steps remaining:"
echo ""
echo "  [ ] Open 1Password — verify SSH agent is working"
echo "  [ ] Sign into iCloud and verify Obsidian/sync"
echo "  [ ] Open Raycast and import settings backup"
echo "  [ ] Configure Kap: set global shortcut Cmd+Shift+3"
echo "  [ ] Set desktop wallpaper in System Settings > Wallpaper"
echo "  [ ] Set mouse cursor color in Accessibility > Display"
echo "  [ ] Configure app-specific settings (Slack, Discord)"
echo "  [ ] Restart to complete all system changes"
echo ""
echo "  App Settings Restore Notes:"
echo ""
echo "  Raycast    — Settings > Advanced > Import"
echo "  Ghostty    — Managed by chezmoi (~/.config/ghostty/config)"
echo "  Zellij     — Managed by chezmoi (~/.config/zellij/config.kdl)"
echo "  VS Code    — Settings Sync (sign in with GitHub)"
echo "  Slack      — File > Sign in to another workspace"
echo "  Discord    — Sign in; servers rejoin automatically"
echo "  Obsidian   — Open vault from iCloud Drive"
echo "  Atuin      — Run: atuin login"
echo "  1Password  — Sign in to restore vault access"
echo ""
```

**Step 2: Commit**

```bash
git add run_once_after_12-post-install.sh
git commit -m "feat: add run_once script for post-install checklist"
```

---

### Task 11: Add Additional Dotfiles from Live System

**Files:**
- Create: `dot_config/atuin/` (from `~/.config/atuin/`)
- Create: `dot_config/ghostty/` (from `~/.config/ghostty/`)
- Create: `dot_config/gh/config.yml` (from `~/.config/gh/config.yml`)
- Create: `dot_config/keyboardcowboy/` (from `~/.config/keyboardcowboy/`)
- Create: `dot_config/leaderkey/` (from `~/.config/leaderkey/`)
- Create: `dot_config/zellij/` (from `~/.config/zellij/`)
- Create: `dot_config/1Password/` (from `~/.config/1Password/`)

**Context:** Use `chezmoi add` to bring each config under management. This is the correct way — chezmoi handles the `dot_` prefix renaming and places files in the source directory. Before adding each file, inspect it for secrets (API keys, tokens, passwords). If secrets are found, use `chezmoi add --template` instead and replace secrets with `{{ onepasswordRead }}` calls.

**Step 1: Check which configs exist on the live system**

```bash
ls -la ~/.config/atuin/ 2>/dev/null
ls -la ~/.config/ghostty/ 2>/dev/null
ls -la ~/.config/gh/config.yml 2>/dev/null
ls -la ~/.config/keyboardcowboy/ 2>/dev/null
ls -la ~/.config/leaderkey/ 2>/dev/null
ls -la ~/.config/zellij/ 2>/dev/null
ls -la ~/.config/1Password/ 2>/dev/null
ls -la ~/.config/zoxide/ 2>/dev/null
```

**Step 2: For each existing config, inspect for secrets**

Read each config file. Look for patterns like:
- `key = "..."` with long hex/base64 strings
- `token`, `secret`, `password`, `api_key` fields
- URLs with embedded credentials

**Step 3: Add non-sensitive configs with chezmoi**

For each directory/file that's clean:

```bash
chezmoi add ~/.config/atuin/config.toml
chezmoi add ~/.config/ghostty/config
chezmoi add ~/.config/gh/config.yml
chezmoi add ~/.config/keyboardcowboy/  # Add whole directory
chezmoi add ~/.config/leaderkey/
chezmoi add ~/.config/zellij/
chezmoi add ~/.config/1Password/
```

Skip runtime data files (*.db, *.log, history files). Only add config files.

**Step 4: For configs with secrets, add as templates**

If any file contains secrets:

```bash
chezmoi add --template ~/.config/<app>/config.toml
```

Then edit the template to replace secret values with 1Password lookups:

```bash
chezmoi edit ~/.config/<app>/config.toml
```

Replace: `key = "actual-secret-value"` with `key = "{{ onepasswordRead "op://vault/item/field" }}"`

**Step 5: Verify**

```bash
chezmoi diff
```

Should show the managed files ready to deploy.

**Step 6: Commit**

```bash
cd "$(chezmoi source-path)"
git add dot_config/
git commit -m "feat: add additional app configs (atuin, ghostty, gh, zellij, etc.)"
```

---

### Task 12: Add SOPS Age Key Template

**Files:**
- Create: `private_dot_config/private_sops/private_age/keys.txt.tmpl`

**Context:** The SOPS age private key must come from 1Password. chezmoi's `private_` prefix sets restrictive file permissions (0600). The `.tmpl` extension triggers template processing. You need to know the 1Password vault, item, and field names for the age key.

**Step 1: Identify the 1Password item**

Run: `op item list --vault Private | grep -i sops` (or whatever vault it's in)

Note the item name and field structure.

**Step 2: Create the directory structure**

```bash
mkdir -p private_dot_config/private_sops/private_age
```

**Step 3: Create the template**

```
# keys.txt.tmpl
# AGE secret key — pulled from 1Password at apply time.
{{ onepasswordRead "op://Private/SOPS Age Key/private key" }}
```

Replace `Private`, `SOPS Age Key`, and `private key` with the actual vault, item, and field names from Step 1.

**Step 4: Test (requires op signin)**

```bash
chezmoi diff --include=files | grep -A5 sops
```

If `op` is authenticated, this should show the age key content. If not, it will fail gracefully.

**Step 5: Commit**

```bash
git add private_dot_config/
git commit -m "feat: add SOPS age key template (1Password-backed)"
```

---

### Task 13: Update .chezmoiignore for Profiles and New Files

**Files:**
- Modify: `dot_chezmoiignore`

**Context:** Add profile-conditional ignores and exclude repo-only files (bootstrap.sh, docs/, TODO.md, .chezmoidata/). Also add the `Brewfile.current` to the ignore (it's a temp file from brew-export).

**Step 1: Read the current file**

Read `dot_chezmoiignore` for the current content.

**Step 2: Update with new entries**

```
# .chezmoiignore
# Files/patterns to exclude from chezmoi management.

# Repo-only files (not deployed to home directory)
README.md
LICENSE
TODO.md
bootstrap.sh
docs/
.DS_Store
Brewfile.current

# Exclude non-macOS files on non-macOS
{{- if ne .chezmoi.os "darwin" }}
dot_zshrc.d/11-kube-ps1.zsh
dot_config/ghostty/
{{- end }}

# Profile-conditional ignores
{{- if eq .profile "work" }}
# Skip personal-only app configs on work machines
# (add paths here as needed when personal-only configs exist)
{{- end }}
```

**Step 3: Commit**

```bash
git add dot_chezmoiignore
git commit -m "feat: update chezmoiignore with repo-only files and profile conditionals"
```

---

### Task 14: Rewrite README

**Files:**
- Modify: `README.md`

**Context:** Replace the current minimal README with a user-friendly guide covering the 3 commands, what gets installed, profiles, package management, secrets, and structure. Keep it concise — usage-focused, not implementation-focused.

**Step 1: Read the current README**

Read `README.md`.

**Step 2: Rewrite**

```markdown
# dotfiles

Personal macOS setup managed by [chezmoi](https://www.chezmoi.io/).
One command to set up a new Mac. One command to keep it in sync.

## Quick Start

### Set up a new machine

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/1activegeek/dotfiles/main/bootstrap.sh)"
```

This installs Xcode CLI Tools, Homebrew, and chezmoi, then applies all dotfiles, packages, and system preferences.

### Sync everything (apps + dotfiles)

```bash
chezmoi update && brew-sync
```

Pulls latest dotfiles and applies them. `brew-sync` installs missing packages and optionally removes ones not in the Brewfile (with confirmation).

### Sync dotfiles only

```bash
chezmoi update
```

## What Gets Installed

Packages are defined in `.chezmoidata/packages.yaml` and installed via `brew bundle`:

- **Core** — chezmoi, 1Password, Brave, Ghostty, Raycast
- **Dev CLI** — atuin, bat, eza, fd, fzf, starship, zellij, zoxide
- **Dev GUI** — VS Code, Docker, OrbStack, Claude, Codex
- **Browsers** — Chrome, Tor
- **Communication** — Slack, Discord, Zoom
- **AI** — ChatGPT, Ollama, LM Studio
- **Infra** — kubectl, helm, k9s, Terraform
- **3D Printing** — Bambu Studio, OrcaSlicer, PrusaSlicer *(personal only)*
- **And more** — media, utilities, security, fonts, Mac App Store apps

## Machine Profiles

During `chezmoi init`, you choose a profile: **personal** or **work**.

- **personal** — everything: homelab tools, 3D printing, personal apps
- **work** — skips personal-only packages, adds work apps (Teams, Okta Verify)

To change your profile:

```bash
chezmoi edit-config   # Change profile value
chezmoi apply         # Re-apply with new profile
```

## Managing Packages

### Add a package

Edit `.chezmoidata/packages.yaml`, add the entry, then:

```bash
chezmoi apply   # Triggers brew bundle automatically
```

### Remove a package

Remove from `packages.yaml`, then run `brew-sync` to uninstall.

### Export current Homebrew state

```bash
brew-export   # Dumps to chezmoi source for comparison
```

## Managing Dotfiles

```bash
chezmoi add ~/.config/app/config    # Start managing a new file
chezmoi edit ~/.config/app/config   # Edit in your editor
chezmoi diff                        # Preview changes
chezmoi apply                       # Apply changes
chezmoi cd                          # Jump to chezmoi source directory
```

## Secrets

SSH keys and SOPS age keys are stored in 1Password and deployed via chezmoi templates. Before applying secrets:

1. Open 1Password and sign in
2. Enable CLI integration (Settings > Developer > CLI)
3. Run `op signin`
4. Run `chezmoi apply`

## Structure

```
dotfiles/
├── bootstrap.sh                    # Bare machine setup shim
├── dot_chezmoi.toml.tmpl           # chezmoi config + profile prompt
├── .chezmoidata/packages.yaml      # All packages (brew/cask/mas)
├── run_once_before_*               # Homebrew + core package install
├── run_onchange_before_*           # Brew bundle (re-runs on changes)
├── run_once_after_*                # macOS defaults, Dock, post-install
├── dot_zshrc + dot_zshrc.d/        # Modular ZSH configuration
├── dot_config/                     # App configs (starship, ghostty, etc.)
├── private_dot_config/             # Secret configs (SOPS age key)
└── private_dot_ssh/                # SSH config + keys (1Password)
```
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README with quick start, profiles, and usage guide"
```

---

### Task 15: Clean Up and Final Verification

**Files:**
- Delete: `TODO.md` (all items addressed or documented as deferred)

**Context:** Verify the entire system works end-to-end with a dry-run.

**Step 1: Run chezmoi diff to verify all files**

```bash
chezmoi diff
```

Review the output. All managed files should appear with the correct target paths.

**Step 2: Run chezmoi doctor**

```bash
chezmoi doctor
```

Fix any warnings.

**Step 3: Verify template data merges correctly**

```bash
chezmoi data | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Profile:', d.get('profile'))
print('Packages:', len(d.get('packages', [])))
print('Taps:', len(d.get('taps', [])))
"
```

**Step 4: Verify the Brewfile template renders**

```bash
chezmoi execute-template < run_onchange_before_03-brew-bundle.sh.tmpl | head -40
```

Inspect the output for correct Brewfile syntax.

**Step 5: Delete TODO.md**

```bash
rm TODO.md
```

**Step 6: Final commit**

```bash
git add -A
git commit -m "cleanup: remove TODO.md, all items addressed in chezmoi migration"
```

---

## Execution Notes

- **Tasks 1-7** can be done without affecting the live system (creating files, no side effects).
- **Task 8-10** create run scripts that only execute during `chezmoi apply` (safe to commit without triggering).
- **Task 11** uses `chezmoi add` which reads from the live system — run this on your primary machine.
- **Task 12** requires knowing 1Password item names — may need interactive exploration.
- **After all tasks:** Run `chezmoi apply --dry-run` to preview what would happen, then `chezmoi apply` to deploy.
