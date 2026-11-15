# LifeOS vault (live since 2026-11-11): roots for the vault's tools, and its CLI on PATH.
export LIFEOS_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/lifeOS"
export LIFEOS_STORE="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
# Appended, not prepended: this folder syncs through iCloud, so it must never
# shadow system commands (git, ssh, op, ...).
path+=("$LIFEOS_VAULT/.lifeos/tools")
