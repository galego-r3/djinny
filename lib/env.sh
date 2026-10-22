# Sourced by the cockpit's shell scripts. Sets:
#   ws       workspace root: $CLAUDE_WORKSPACE, else ~/.config/claude-cockpit/workspace (written by
#            install.sh), else ~/claude
#   ws_name  its name, used for the root's session, tab and dashboard row (e.g. "claude")
#   conf     the workspace's cockpit.json (tab colours etc., see README.md)
ws=${CLAUDE_WORKSPACE:-$(cat "$HOME/.config/claude-cockpit/workspace" 2>/dev/null)}
ws=${ws:-$HOME/claude}; ws=${ws%/}
ws_name=$(basename "$ws")
conf="$ws/cockpit.json"

# Session name of a directory: its path relative to the workspace ("family/schule"), $ws_name for the
# root itself, empty outside the workspace
ws_rel() {
  case "$1" in
    "$ws") echo "$ws_name" ;;
    "$ws"/*) echo "${1#"$ws"/}" ;;
  esac
}

# Tab colour of a session name from cockpit.json "colors" (longest matching path wins), empty if none
ws_color() {
  local p=$1 c
  while :; do
    c=$(jq -r --arg p "$p" '.colors[$p] // empty' "$conf" 2>/dev/null)
    [ -n "$c" ] && { echo "$c"; return; }
    [[ $p == */* ]] || return
    p=${p%/*}
  done
}
