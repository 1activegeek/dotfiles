# ~/.zshrc.d/03-git.zsh
# Git aliases and helper functions

# ============================================
# Core aliases
# ============================================
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gap='git add --patch'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcb='git checkout -b'
alias gco='git checkout'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch --all --prune'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all'
alias glp='git log --patch'
alias gp='git push'
alias gpu='git push --set-upstream origin HEAD'
alias gpf='git push --force-with-lease'
alias gpl='git pull'
alias gplr='git pull --rebase'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grs='git reset'
alias grsh='git reset --hard'
alias gs='git status'
alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gsw='git switch'
alias gswc='git switch -c'

# ============================================
# Helper functions
# ============================================

# Get the default branch name (main or master)
git_main_branch() {
  git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's@^origin/@@' || echo "main"
}

# Get the current branch name
git_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Delete all merged local branches (except main/master/develop)
gclean() {
  git branch --merged | grep -vE '^\*|main|master|develop' | xargs -r git branch -d
  echo "Merged branches cleaned."
}

# Open current repo in GitHub/GitLab in browser
grepo() {
  local url
  url="$(git remote get-url origin 2>/dev/null)"
  url="${url/git@github.com:/https://github.com/}"
  url="${url/git@gitlab.com:/https://gitlab.com/}"
  url="${url%.git}"
  [[ -n "$url" ]] && open "$url" || echo "No remote 'origin' found."
}
