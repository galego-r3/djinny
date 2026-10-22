#!/usr/bin/env bash
# SessionStart hook: name the session (like /rename) after its folder path relative to the workspace
# (e.g. "fun/chess"; the root itself is the workspace's name), colour the Konsole tab from the
# workspace's cockpit.json and re-sort the window's tabs.
. "$(dirname "$(readlink -f "$0")")/../lib/env.sh"
name=$(ws_rel "$(jq -r '.cwd // empty')")
[ -n "$name" ] || exit 0
color=$(ws_color "$name")

if [ -n "$KONSOLE_DBUS_SERVICE" ] && [ -n "$KONSOLE_DBUS_SESSION" ]; then
  # Tab title = folder name only (Konsole's default format "%d : %n" appends ": claude").
  # Context 0 = local, 1 = remote; "%" is escaped as "%%" in the format string.
  for ctx in 0 1; do
    qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" setTabTitleFormat "$ctx" "${name//%/%%}" >/dev/null 2>&1
  done
  [ -n "$color" ] && qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" setTabColor "$color" >/dev/null 2>&1
  # Re-sort the window's tabs by name (in the background, so the session start isn't delayed)
  setsid "$(dirname "$(readlink -f "$0")")/sort-tabs.sh" </dev/null >/dev/null 2>&1 &
fi

jq -nc --arg t "$name" '{hookSpecificOutput:{hookEventName:"SessionStart",sessionTitle:$t}}'
