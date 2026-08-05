#!/bin/sh
# Publish Orca's Forgejo/Gitea integration env vars into the GUI (launchd) session
# so Orca.app sees them when launched from Dock/Spotlight.
#
# Orca's Gitea provider reads ORCA_GITEA_API_BASE_URL and ORCA_GITEA_TOKEN from
# its process environment at startup. GUI apps do not inherit the shell env, so
# these have to be set via `launchctl setenv`, which does not survive a reboot.
# This script is run at login by com.shawnmix.orca-gitea-env.plist.
#
# Secrets live ONLY in the local, gitignored file below (mode 0600) — never in
# this repo, which is public. Regenerate it with the wiring steps documented in
# the LifeOS vault note on the Orca/Forgejo integration.
set -eu

ENV_FILE="${HOME}/.config/orca/gitea-env.local"

[ -f "$ENV_FILE" ] || exit 0

# shellcheck source=/dev/null
. "$ENV_FILE"

[ -n "${ORCA_GITEA_API_BASE_URL:-}" ] && launchctl setenv ORCA_GITEA_API_BASE_URL "$ORCA_GITEA_API_BASE_URL"
[ -n "${ORCA_GITEA_TOKEN:-}" ] && launchctl setenv ORCA_GITEA_TOKEN "$ORCA_GITEA_TOKEN"

exit 0
