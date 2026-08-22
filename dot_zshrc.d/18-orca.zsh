# 18-orca.zsh — send agent browser output to Orca's embedded browser.
#
# Orca exports TERM_PROGRAM=Orca into every terminal it manages. Inside Orca the
# system browser opens in a different window than the one being worked in, which
# splits your attention across two apps for no reason.
#
# Two halves make this work:
#   1. This file suppresses Claude Code's automatic artifact browser-open
#      (documented env var), so nothing pops the system browser.
#   2. ~/.agentos/scripts/agent-open.sh then places the page in the Orca browser
#      via `orca tab create --url`.
#
# Outside Orca this block never runs — artifacts auto-open exactly as before.
#
# Note: Orca's browser has its own cookie jar. Pages needing a logged-in
# claude.ai session require a one-time sign-in in that browser profile.
# To override for a single command: AGENT_OPEN_FORCE=system agent-open.sh <url>

if [[ "$TERM_PROGRAM" == "Orca" ]]; then
  export CLAUDE_CODE_ARTIFACT_AUTO_OPEN=0
fi
