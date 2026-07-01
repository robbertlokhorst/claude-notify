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
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // ""')
project=$(basename "${cwd:-unknown}")

# Muted sessions: one session_id per line. Managed by the `claude-notify` CLI.
# If this session is muted, exit silently (still returning valid JSON).
MUTE_FILE="${HOME}/.claude/claude-notify-muted"
if [ -n "$session_id" ] && [ -f "$MUTE_FILE" ] \
   && grep -qxF "$session_id" "$MUTE_FILE" 2>/dev/null; then
  printf '{}'
  exit 0
fi

NOTIFIER=/opt/homebrew/bin/terminal-notifier

# The session UUID is useless to a human. The best human-readable identifier is
# the last prompt you actually typed. In the transcript, a typed prompt is a
# user entry whose .message.content is a STRING (tool results are arrays).
last_prompt=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  last_prompt=$(jq -rs '
    map(select(.type=="user"
               and (.message.content | type) == "string"
               and (.message.content | startswith("<") | not)))
    | last | .message.content // ""' "$transcript" 2>/dev/null | tr '\n' ' ')
fi
# Trim to a notification-friendly length.
if [ -n "$last_prompt" ]; then
  [ "${#last_prompt}" -gt 90 ] && last_prompt="${last_prompt:0:90}…"
else
  last_prompt="Session ${session_id:0:8}"
fi

# Current git branch, if this is a repo — extra context for which checkout.
branch=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
fi

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

# Title shows project (+ branch); subtitle is the prompt you typed; body is the
# event + a click hint. That makes "which session?" answerable at a glance.
title="$project"
[ -n "$branch" ] && title="$project ⎇ $branch"

args=(
  -title   "$title"
  -subtitle "$last_prompt"
  -message "$message · click to focus"
  -sound   "$sound"
  -group   "claude-$session_id"   # collapses repeat notifs per session
)
[ -n "$bundle" ] && args+=(-execute "open -b '$bundle'")

"$NOTIFIER" "${args[@]}" >/dev/null 2>&1 || true

# Hooks must return valid JSON on stdout.
printf '{}'
