#!/bin/bash
# Installer for claude-notify: rich, clickable macOS desktop notifications
# for Claude Code. Safe to re-run — it merges into your existing settings.json
# with jq and never touches secrets or other keys.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
SETTINGS="${CLAUDE_DIR}/settings.json"

echo "==> claude-notify installer"

# 1. Dependencies -----------------------------------------------------------
missing=()
command -v brew >/dev/null 2>&1 || { echo "ERROR: Homebrew is required (https://brew.sh)"; exit 1; }
command -v jq  >/dev/null 2>&1 || missing+=(jq)
command -v terminal-notifier >/dev/null 2>&1 || missing+=(terminal-notifier)
if [ "${#missing[@]}" -gt 0 ]; then
  echo "==> Installing: ${missing[*]}"
  brew install "${missing[@]}"
fi

# 2. Copy the hook script ---------------------------------------------------
mkdir -p "$HOOKS_DIR"
cp "${REPO_DIR}/hooks/notify.sh" "${HOOKS_DIR}/notify.sh"
chmod +x "${HOOKS_DIR}/notify.sh"
echo "==> Installed ${HOOKS_DIR}/notify.sh"

# 2b. Link the management CLI onto PATH -------------------------------------
chmod +x "${REPO_DIR}/bin/claude-notify"
BIN_DEST="$(brew --prefix)/bin/claude-notify"
ln -sf "${REPO_DIR}/bin/claude-notify" "$BIN_DEST"
echo "==> Linked 'claude-notify' CLI -> ${BIN_DEST}"

# 3. Merge the hooks block into settings.json -------------------------------
mkdir -p "$CLAUDE_DIR"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

# Back up first.
cp "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d%H%M%S 2>/dev/null || echo backup)"

HOOKS_JSON='{
  "Notification": [
    { "matcher": "idle_prompt",       "hooks": [ { "type": "command", "command": "$HOME/.claude/hooks/notify.sh idle" } ] },
    { "matcher": "permission_prompt", "hooks": [ { "type": "command", "command": "$HOME/.claude/hooks/notify.sh permission" } ] }
  ]
}'

tmp="$(mktemp)"
jq --argjson hooks "$HOOKS_JSON" '.hooks = $hooks' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
echo "==> Merged Notification hooks into ${SETTINGS} (backup saved alongside)"

# 4. Manual follow-ups ------------------------------------------------------
cat <<'EOF'

==> Done. Two manual steps macOS only allows via the UI:

  1. System Settings -> Notifications -> terminal-notifier
       - Allow notifications: ON
       - Alert style: "Alerts" (stays on screen until you click/dismiss)

  2. Make sure Do Not Disturb / Focus is OFF (it silently blocks notifications).

Restart any running Claude Code sessions to load the hook (new sessions get it automatically).

Test it:
  echo '{"session_id":"test123","message":"Hello","cwd":"'"$PWD"'"}' | \
    TERM_PROGRAM="$TERM_PROGRAM" ~/.claude/hooks/notify.sh idle
EOF
