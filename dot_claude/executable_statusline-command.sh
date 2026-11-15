#!/bin/sh
# Status line: model | effort | cwd | worktree badge.
# Context and 5h/7d usage meters live in the context-meter mod (~/.claude/mods/context-meter).
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
effort=$(echo "$input" | jq -r '.effort.level // empty')
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')

# Catppuccin Mocha palette (true color)
YELLOW='\033[38;2;249;226;175m'  # Yellow   #f9e2af
MAUVE='\033[38;2;203;166;247m'   # Mauve    #cba6f7
CYAN='\033[38;2;116;199;236m'    # Sapphire #74c7ec
DIM='\033[38;2;108;112;134m'     # Overlay0 #6c7086
RESET='\033[0m'

line1="${CYAN}${model}${RESET}"
if [ -n "$effort" ]; then
  line1="$line1 ${DIM}|${RESET} ${MAUVE}󰧑 ${effort}${RESET}"
fi
if [ -n "$cwd" ]; then
  line1="$line1 ${DIM}|${RESET} $cwd"
fi

# Worktree badge: a linked worktree's git dir is always <repo>/.git/worktrees/<name>,
# whereas the main checkout's is just <repo>/.git. Flag it loudly so uncommitted
# worktree work isn't forgotten (it's never auto-committed by obsidian-git).
if [ -n "$cwd" ]; then
  gitdir=$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null)
  case "$gitdir" in
    */worktrees/*)
      branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
      line1="$line1 ${DIM}|${RESET} ${YELLOW}⎇ worktree${RESET}"
      [ -n "$branch" ] && line1="$line1 ${YELLOW}:${branch}${RESET}"
      ;;
  esac
fi

printf '%b\n' "$line1"
