#!/usr/bin/env bash
# UserPromptSubmit hook: a prompt "clear" or "clear: <message>" clears the session and then sends <message>
# into the fresh one. Claude can't run /clear itself, so the prompt is blocked and the hook types /clear + Enter
# (then the message + Enter) into the Konsole tab over D-Bus. Konsole only; elsewhere the prompt goes through.
prompt=$(jq -r '.prompt // empty')
shopt -s nocasematch
[[ $prompt =~ ^[[:space:]]*clear[[:space:]]*(:[[:space:]]*(.*))?$ ]] || exit 0
[[ -n $KONSOLE_DBUS_SERVICE && -n $KONSOLE_DBUS_SESSION ]] && command -v qdbus6 >/dev/null || exit 0
msg=${BASH_REMATCH[2]}
q() { qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.sendText "$1" >/dev/null; }
# In the background, after Claude Code has handled the block and is back at the prompt
(
  sleep 1; q /clear; sleep 0.3; q $'\r'
  if [[ -n $msg ]]; then sleep 3; q "$msg"; sleep 0.3; q $'\r'; fi
) </dev/null >/dev/null 2>&1 &
disown
jq -n '{decision: "block", reason: "clearing…"}'
