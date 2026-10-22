#!/usr/bin/env bash
# Sort the tabs of the current Konsole window: DASH (the dashboard) first, then the workspace root's
# tab, then the other named tabs A–Z, unnamed tabs (title format still Konsole's default with "%")
# last. Called by session-name.sh and the dashboard. Konsole can only move the active tab, so focus
# briefly jumps through the tabs; the tab that was active before is re-selected at the end.
svc=${KONSOLE_DBUS_SERVICE:-}; win=${KONSOLE_DBUS_WINDOW:-}
[ -n "$svc" ] && [ -n "$win" ] || exit 0
q() { qdbus6 "$svc" "$@" 2>/dev/null; }
. "$(dirname "$(readlink -f "$0")")/../lib/env.sh"

exec 9>"$HOME/.cache/claude/sort-tabs.lock"
flock -w 10 9 || exit 0

key() {   # sort key of one session
  local fmt; fmt=$(q "/Sessions/$1" tabTitleFormat 0)
  case "$fmt" in
    DASH) echo "0" ;;
    "$ws_name") echo "1" ;;
    *%*) echo "3 $1" ;;      # unnamed: keep their relative order (session id)
    *) echo "2 $fmt" ;;
  esac
}

mapfile -t cur < <(q "$win" sessionList)     # current tab order
[ "${#cur[@]}" -gt 1 ] || exit 0
mapfile -t want < <(for s in "${cur[@]}"; do printf '%s\t%s\n' "$(key "$s")" "$s"; done | LC_ALL=C sort -t$'\t' -k1,1 | cut -f2)
[ "${cur[*]}" = "${want[*]}" ] && exit 0

active=$(q "$win" currentSession)
for ((i = 0; i < ${#want[@]}; i++)); do
  for ((j = i; j < ${#cur[@]}; j++)); do [ "${cur[j]}" = "${want[i]}" ] && break; done
  [ "$j" -gt "$i" ] || continue
  q "$win" setCurrentSession "${want[i]}" >/dev/null
  for ((k = j; k > i; k--)); do q "$win" moveSessionLeft >/dev/null; done
  cur=("${cur[@]:0:i}" "${want[i]}" "${cur[@]:i:j-i}" "${cur[@]:j+1}")
done
q "$win" setCurrentSession "$active" >/dev/null
