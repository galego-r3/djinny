#!/usr/bin/env bash
# UserPromptSubmit hook: a prompt "clear" or "clear: <message>" (also "clear, …", "clear - …", "clear then …",
# "clear, then …", "clear and then …"; not "clear the …"; short: "c", "c: <message>") clears the session and then sends <message>
# into the fresh one. Claude can't run /clear itself, so the prompt is blocked and the hook types /clear + Enter
# (then the message + Enter) into the Konsole tab over D-Bus. Konsole only; elsewhere the prompt goes through.
prompt=$(jq -r '.prompt // empty')
shopt -s nocasematch
re='^[[:space:]]*clear[[:space:]]*(([:,;-][[:space:]]*(then[[:space:]]+)?|[[:space:]]+(and[[:space:]]+)?then[[:space:]]+)(.*))?$'
short='^[[:space:]]*c[[:space:]]*(:[[:space:]]*(.*))?$'   # short form: "c" or "c: <message>" (colon needed)
if [[ $prompt =~ $re ]]; then msg=${BASH_REMATCH[5]}
elif [[ $prompt =~ $short ]]; then msg=${BASH_REMATCH[2]}
else exit 0; fi
[[ -n $KONSOLE_DBUS_SERVICE && -n $KONSOLE_DBUS_SESSION ]] && command -v qdbus6 >/dev/null || exit 0
q() { qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.sendText "$1" >/dev/null; }
# Probe with an empty text: Konsole 26.08+ refuses sendText unless EnableSecuritySensitiveDBusAPI is on (install.sh)
if ! err=$(qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" org.kde.konsole.Session.sendText "" 2>&1 >/dev/null) || [[ -n $err ]]; then
  jq -n --arg e "${err:-sendText failed}" '{decision: "block", reason: ("cannot clear: Konsole refused to type /clear (\($e)). Run cockpit/install.sh and restart Konsole, or type /clear yourself.")}'
  exit 0
fi
# In the background, after Claude Code has handled the block and is back at the prompt
(
  sleep 1; q /clear; sleep 0.3; q $'\r'
  if [[ -n $msg ]]; then sleep 3; q "$msg"; sleep 0.3; q $'\r'; fi
) </dev/null >/dev/null 2>&1 &
disown
jq -n '{decision: "block", reason: "clearing…"}'
