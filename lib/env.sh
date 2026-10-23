# Sourced by the cockpit's shell scripts. Sets:
#   ws       workspace root: $CLAUDE_WORKSPACE, else ~/.config/claude-cockpit/workspace (written by
#            install.sh), else ~/claude
#   conf     the workspace's cockpit.json (tab colours etc., see README.md)
#   ws_name  the root's session, tab and dashboard row name: cockpit.json "name", else the folder's name
ws=${CLAUDE_WORKSPACE:-$(cat "$HOME/.config/claude-cockpit/workspace" 2>/dev/null)}
ws=${ws:-$HOME/claude}; ws=${ws%/}
conf="$ws/cockpit.json"
ws_name=$(jq -r '.name // empty' "$conf" 2>/dev/null); ws_name=${ws_name:-$(basename "$ws")}

# Session name of a directory: its path relative to the workspace, cut to cockpit.json "depth" levels
# (default 2, as the dashboard rows: code/wba/wba-31 -> "code/wba"), $ws_name for the root itself, empty
# outside the workspace
ws_rel() {
  local rel depth
  case "$1" in
    "$ws") echo "$ws_name"; return ;;
    "$ws"/*) rel=${1#"$ws"/} ;;
    *) return ;;
  esac
  depth=$(jq -r '.depth // 2' "$conf" 2>/dev/null); [[ $depth =~ ^[1-9][0-9]*$ ]] || depth=2
  echo "$rel" | cut -d/ -f"1-$depth"
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
