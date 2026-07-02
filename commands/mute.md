---
description: Mute desktop notifications for THIS Claude Code session
disable-model-invocation: true
allowed-tools: Bash(PATH=*), Bash(claude-notify:*)
---

Muting notifications for the current session:

!`PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" claude-notify mute this`
