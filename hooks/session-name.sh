#!/usr/bin/env bash
# SessionStart hook: name the session (like /rename) after its folder path relative to the workspace, at most
# "depth" levels (lib/env.sh ws_rel)
# (e.g. "fun/chess"; the root itself is the workspace's name), colour the Konsole tab from the
# workspace's cockpit.json, open the dashboard on a fresh start (unless cockpit.json has
# "dashboard_autostart": false): with "dashboard": "web" the web page (cockpit-web open, if none is open),
# with "window" its own window (dashboard --window --if-closed), else in a new tab if the window has none;
# and re-sort the window's tabs.
. "$(dirname "$(readlink -f "$0")")/../lib/env.sh"
input=$(cat)
name=$(ws_rel "$(jq -r '.cwd // empty' <<<"$input")")
[ -n "$name" ] || exit 0
color=$(ws_color "$name")

if [ -n "$KONSOLE_DBUS_SERVICE" ] && [ -n "$KONSOLE_DBUS_SESSION" ]; then
  # Tab title = folder name only (Konsole's default format "%d : %n" appends ": claude").
  # Context 0 = local, 1 = remote; "%" is escaped as "%%" in the format string.
  for ctx in 0 1; do
    qdbus6 "$KONSOLE_DBUS_SERVICE" "$KONSOLE_DBUS_SESSION" setTabTitleFormat "$ctx" "${name//%/%%}" >/dev/null 2>&1
  done
  [ -n "$color" ] && "$(dirname "$(readlink -f "$0")")/../lib/konsole-color" "$color" >/dev/null 2>&1
  # No DASH tab in this window: open one. Like the dashboard's own tabs, the new shell runs the command
  # it finds in a marker (shell/bashrc.sh); a fresh marker also keeps sessions starting together from
  # opening two. The claude tab stays active.
  m="$HOME/.cache/claude/dashstart"; win=${KONSOLE_DBUS_WINDOW:-}
  fresh=; [ "$(jq -r '.source // "startup"' <<<"$input")" = startup ] \
     && [ "$(jq -r '.dashboard_autostart // true' "$conf" 2>/dev/null)" != false ] && fresh=1
  mode=$(jq -r '.dashboard // "terminal"' "$conf" 2>/dev/null)
  if [ -n "$fresh" ] && [ "$mode" = web ]; then
    setsid "$(dirname "$(readlink -f "$0")")/../bin/cockpit-web" open </dev/null >/dev/null 2>&1 &
  elif [ -n "$fresh" ] && [ "$mode" = window ]; then
    setsid "$(dirname "$(readlink -f "$0")")/../bin/dashboard" --window --if-closed </dev/null >/dev/null 2>&1 &
  elif [ -n "$win" ] && [ -n "$fresh" ] \
     && ! { [ -f "$m" ] && [ $(( $(date +%s) - $(stat -c %Y "$m") )) -lt 15 ]; }; then
    has_dash=
    for s in $(qdbus6 "$KONSOLE_DBUS_SERVICE" "$win" sessionList 2>/dev/null); do
      [ "$(qdbus6 "$KONSOLE_DBUS_SERVICE" "/Sessions/$s" tabTitleFormat 0 2>/dev/null)" = DASH ] && { has_dash=1; break; }
    done
    if [ -z "$has_dash" ]; then
      mkdir -p "${m%/*}"; echo "$ws" > "$m"
      qdbus6 "$KONSOLE_DBUS_SERVICE" "$win" newSession "$(qdbus6 "$KONSOLE_DBUS_SERVICE" "$win" defaultProfile 2>/dev/null)" "$ws" >/dev/null 2>&1
      qdbus6 "$KONSOLE_DBUS_SERVICE" "$win" setCurrentSession "${KONSOLE_DBUS_SESSION##*/}" >/dev/null 2>&1
    fi
  fi
  # Re-sort the window's tabs by name (in the background, so the session start isn't delayed)
  setsid "$(dirname "$(readlink -f "$0")")/sort-tabs.sh" </dev/null >/dev/null 2>&1 &
fi

# First start of the root session in a workspace with nothing but the cockpit (no project CLAUDE.md, never
# greeted): a welcome for the user, and welcome.md (how-to, offer to deploy starter/) as context for Claude
rd=$(jq -r '.rules // "rules"' "$conf" 2>/dev/null); rd=${rd:-rules}
if [ "$name" = "$ws_name" ] && [ ! -e "$ws/.cockpit/welcomed" ] \
   && [ -z "$(find "$ws" -mindepth 2 -maxdepth 3 -name CLAUDE.md -not -path "$ws/cockpit/*" -not -path "$ws/$rd/*" \
                -not -path "$ws/tmp/*" -print -quit 2>/dev/null)" ]; then
  mkdir -p "$ws/.cockpit"; touch "$ws/.cockpit/welcomed"
  here=$(dirname "$(readlink -f "$0")")/..
  jq -nc --arg t "$name" --rawfile w "$here/welcome.md" '{
    systemMessage: "Welcome to the Claude cockpit! Say hi to get a short tour and the option to set up the starter structure.",
    hookSpecificOutput: {hookEventName: "SessionStart", sessionTitle: $t,
      additionalContext: ("First start of the cockpit in this workspace. On the user'"'"'s first message, greet them and do this:\n\n" + $w)}}'
  exit 0
fi
jq -nc --arg t "$name" '{hookSpecificOutput:{hookEventName:"SessionStart",sessionTitle:$t}}'
