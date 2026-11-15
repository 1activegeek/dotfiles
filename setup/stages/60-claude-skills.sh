#!/bin/bash
# setup stage: claude-skills
# Skills live canonically in ~/.agents/skills/ (deployed by chezmoi). Claude Code
# discovers them via symlinks in ~/.claude/skills/. chezmoi does NOT manage those
# symlinks, so this stage creates them. Run by setup/setup.sh only (never by
# chezmoi apply). After adding a skill: setup.sh --only claude-skills Idempotent and offline — no
# dependency on `npx skills`. Mirrors the relative-symlink layout skills.sh uses.
set -euo pipefail

SRC="${HOME}/.agents/skills"
DST="${HOME}/.claude/skills"

[[ -d "$SRC" ]] || { echo "    (no ~/.agents/skills — skipping Claude skill linking)"; exit 0; }
mkdir -p "$DST"

linked=0
for skill in "$SRC"/*/; do
  [[ -d "$skill" ]] || continue
  name="$(basename "$skill")"
  link="$DST/$name"
  # Only create/refresh symlinks — never clobber a real file/dir a user placed here.
  if [[ -L "$link" || ! -e "$link" ]]; then
    ln -sfn "../../.agents/skills/$name" "$link"
    linked=$((linked + 1))
  fi
done

# Prune dangling symlinks left by skills that were removed from ~/.agents/skills.
pruned=0
for link in "$DST"/*; do
  if [[ -L "$link" && ! -e "$link" ]]; then
    rm -f "$link"
    pruned=$((pruned + 1))
  fi
done

echo "==> Claude skills linked: ${linked} ensured, ${pruned} stale removed"
