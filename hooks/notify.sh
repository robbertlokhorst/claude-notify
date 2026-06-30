#!/bin/bash
# Claude Code Notification hook -> rich, clickable macOS notification.
# Fires when Claude finishes a turn / waits for input (idle_prompt) or
# needs permission (permission_prompt). Clicking the notification activates
# the terminal app the session is running in (VS Code or Warp).
set -euo pipefail

input=$(cat)

# First arg is the notification kind, passed in from the matcher in settings.json.
kind="${1:-idle}"

session_id=$(printf '%s' "$input" | jq -r '.session_id // ""')
message=$(printf '%s' "$input" | jq -r '.message // "Needs your attention"')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
project=$(basename "${cwd:-unknown}")

NOTIFIER=/opt/homebrew/bin/terminal-notifier

# Distinct sound per kind: a calm chime for "done", an attention-grabbing
# tone for "needs your approval".
case "$kind" in
  permission) sound="Sosumi" ;;   # needs approval / action
  *)          sound="Glass" ;;    # finished / waiting for input
esac

# Pick which app to bring forward WHEN (and only when) the notification is
# clicked, based on the terminal the session runs in. Ignoring or dismissing
# the notification does nothing. -execute is more reliable than -activate on
# recent macOS.
#
# To support another terminal, add a case with its bundle ID. Find the ID with:
#   osascript -e 'id of app "YourTerminalName"'
case "${TERM_PROGRAM:-}" in
  vscode)       bundle="com.microsoft.VSCode" ;;
  WarpTerminal) bundle="dev.warp.Warp-Stable" ;;
  iTerm.app)    bundle="com.googlecode.iterm2" ;;
  Apple_Terminal) bundle="com.apple.Terminal" ;;
  *)            bundle="" ;;
esac

args=(
  -title   "Claude Code · $project"
  -subtitle "$message"
  -message "Session ${session_id:0:8} · click to focus"
  -sound   "$sound"
  -group   "claude-$session_id"   # collapses repeat notifs per session
)
[ -n "$bundle" ] && args+=(-execute "open -b '$bundle'")

"$NOTIFIER" "${args[@]}" >/dev/null 2>&1 || true

# Hooks must return valid JSON on stdout.
printf '{}'
