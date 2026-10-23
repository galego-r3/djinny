#!/usr/bin/env bash
# Installs the cockpit for the current user; safe to re-run (e.g. after moving the cockpit).
#   ./install.sh [workspace]     workspace defaults to the cockpit's parent folder
# - links bin/ into ~/.local/bin, hooks/ into ~/.claude/hooks, the status line to ~/.claude/statusline.sh
# - registers the hooks, the status line and the mods in plugins/ (env CLAUDE_CODE_PLUGIN_DIRS) in
#   ~/.claude/settings.json (adds only what is missing)
# - installs and starts the systemd user timer claude-jobs.timer
# - sources shell/bashrc.sh from ~/.bashrc
# - remembers the workspace in ~/.config/claude-cockpit/workspace
set -euo pipefail
here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
ws=$(cd "${1:-$here/..}" && pwd)
for cmd in jq python3 qdbus6; do command -v "$cmd" >/dev/null || echo "warning: $cmd not found (needed by the cockpit)" >&2; done

mkdir -p ~/.config/claude-cockpit ~/.local/bin ~/.claude/hooks ~/.config/systemd/user
echo "$ws" > ~/.config/claude-cockpit/workspace
[ -f "$ws/cockpit.json" ] || cp "$here/cockpit.example.json" "$ws/cockpit.json"

for f in "$here"/bin/*; do ln -sfn "$f" ~/.local/bin/"$(basename "$f")"; done
for f in session-name.sh session-state.sh sort-tabs.sh; do ln -sfn "$here/hooks/$f" ~/.claude/hooks/$f; done
ln -sfn "$here/hooks/statusline.sh" ~/.claude/statusline.sh

# settings.json: one hook entry per event, added only if no entry runs that command yet
settings=~/.claude/settings.json
[ -f "$settings" ] || echo '{}' > "$settings"
tmp=$(mktemp)
plugins=$(for d in "$here"/plugins/*/; do [ -d "$d" ] && echo "${d%/}"; done | jq -R . | jq -s .)
jq --argjson plugins "$plugins" '
  def add(ev; cmd): .hooks[ev] = ((.hooks[ev] // []) as $h
    | if any($h[]?.hooks[]?; .command == cmd) then $h else $h + [{hooks: [{type: "command", command: cmd}]}] end);
  add("SessionStart"; "~/.claude/hooks/session-name.sh")
  | reduce ("UserPromptSubmit", "PostToolUse", "Notification", "Stop", "SessionEnd") as $ev
      (.; add($ev; "~/.claude/hooks/session-state.sh"))
  | .statusLine //= {type: "command", command: "~/.claude/statusline.sh", refreshInterval: 30}
  | .env.CLAUDE_CODE_PLUGIN_DIRS = ((.env.CLAUDE_CODE_PLUGIN_DIRS // "" | split(":") | map(select(. != ""))) as $have
      | $have + ($plugins - $have) | join(":"))
' "$settings" > "$tmp"
if ! cmp -s "$tmp" "$settings"; then cp "$settings" "$settings.bak"; mv "$tmp" "$settings"; echo "updated $settings (backup: settings.json.bak)"
else rm -f "$tmp"; fi

cp "$here"/systemd/claude-jobs.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now claude-jobs.timer >/dev/null

line="[ -f \"$here/shell/bashrc.sh\" ] && . \"$here/shell/bashrc.sh\"   # claude cockpit"
touch ~/.bashrc
grep -v '# claude cockpit$' ~/.bashrc > "$tmp" || true
echo "$line" >> "$tmp"
cmp -s "$tmp" ~/.bashrc || cat "$tmp" > ~/.bashrc
rm -f "$tmp"

echo "cockpit installed for workspace $ws"
