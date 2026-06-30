# claude-notify

Rich, clickable **macOS desktop notifications** for [Claude Code](https://claude.com/claude-code).

Get pinged when Claude finishes a turn or needs your approval — even when you've
switched to another window. Each notification shows **which project/session** it
came from, and **clicking it brings that session's terminal forward**. Ignoring or
dismissing the notification does nothing — no apps get switched unless you click.

| Event | When it fires | Sound |
|-------|---------------|-------|
| `idle_prompt` | Claude finished / is waiting for your input | Glass (calm chime) |
| `permission_prompt` | Claude needs your approval to proceed | Sosumi (attention tone) |

## Requirements

- macOS
- [Homebrew](https://brew.sh)
- A terminal that sets `TERM_PROGRAM` (Warp, VS Code, iTerm2, Apple Terminal are
  supported out of the box; others fall back to a non-clickable notification)

`jq` and `terminal-notifier` are installed automatically by the installer.

## Install

```bash
git clone <your-repo-url> claude-notify
cd claude-notify
./install.sh
```

The installer:
1. Installs `jq` and `terminal-notifier` via Homebrew if missing.
2. Copies `hooks/notify.sh` to `~/.claude/hooks/notify.sh`.
3. Merges the `Notification` hooks into `~/.claude/settings.json` using `jq`
   (it backs the file up first and only touches the `.hooks` key — your other
   settings and any secrets are left untouched).

### Two manual steps (macOS only allows these in the UI)

1. **System Settings → Notifications → terminal-notifier**
   - Allow notifications: **ON**
   - Alert style: **Alerts** (stays on screen until you click or dismiss; the
     alternative, "Banners", auto-disappears after a few seconds)
2. Make sure **Do Not Disturb / Focus is OFF** — a Focus mode silently swallows
   all notifications (commands still succeed, nothing appears on screen). To keep
   notifications during a Focus mode, add your terminal app to that Focus's
   **Allowed Apps** list.

Restart any running Claude Code sessions to load the hook. New sessions pick it
up automatically.

## Test

```bash
echo '{"session_id":"test123","message":"Hello","cwd":"'"$PWD"'"}' | \
  TERM_PROGRAM="$TERM_PROGRAM" ~/.claude/hooks/notify.sh idle
```

## Customizing

- **Sounds** — edit the `case "$kind"` block in `hooks/notify.sh`. Any name from
  `/System/Library/Sounds/` works (Glass, Sosumi, Ping, Hero, Funk, Submarine,
  Blow, Tink, …).
- **More terminals** — add a case to the `case "${TERM_PROGRAM:-}"` block. Find an
  app's bundle ID with `osascript -e 'id of app "YourTerminalName"'`.

## How it works

Claude Code fires a [`Notification` hook](https://docs.claude.com/en/docs/claude-code/hooks)
with JSON on stdin (`session_id`, `cwd`, `message`, …). The matcher in
`settings.json` routes `idle_prompt` and `permission_prompt` events to
`notify.sh`, passing a `kind` argument so each gets its own sound. The script
reads `TERM_PROGRAM` to decide which app a click should focus (via
`terminal-notifier -execute "open -b <bundle-id>"`).

## Uninstall

Remove the `"hooks"` block from `~/.claude/settings.json` (or restore a
`settings.json.bak.*` backup) and delete `~/.claude/hooks/notify.sh`.
