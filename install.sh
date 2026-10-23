#!/usr/bin/env bash
# Installs the cockpit for the current user; safe to re-run (e.g. after moving the cockpit).
#   ./install.sh [workspace]     workspace defaults to the cockpit's parent folder
# - links bin/ into ~/.local/bin, hooks/ into ~/.claude/hooks, the status line to ~/.claude/statusline.sh
# - registers the hooks, the status line and the mods in plugins/ (env CLAUDE_CODE_PLUGIN_DIRS) in
#   ~/.claude/settings.json (adds only what is missing)
# - installs and starts the systemd user timer claude-jobs.timer
# - sources shell/bashrc.sh from ~/.bashrc
# - remembers the workspace in ~/.config/claude-cockpit/workspace
# - rules: if <workspace>/rules/ is missing, asks whether to use the shared ruleset (clone of $CLAUDE_RULES_REPO)
#   or start your own (its cockpit.md plus an empty RULES.md, new git repo); answer ahead with
#   CLAUDE_RULES=shared|own. Makes sure the workspace's CLAUDE.md loads @rules/RULES.md.
set -euo pipefail
here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
ws=$(cd "${1:-$here/..}" && pwd)
mkdir -p ~/.local/bin
# the cockpit calls qdbus6 (Debian/Ubuntu name); other distros name it differently, e.g. Fedora qdbus-qt6
if ! command -v qdbus6 >/dev/null; then
  for q in qdbus-qt6 /usr/lib64/qt6/bin/qdbus /usr/lib/qt6/bin/qdbus; do
    q=$(command -v "$q" || true)
    [ -n "$q" ] && { ln -sfn "$q" ~/.local/bin/qdbus6; echo "linked ~/.local/bin/qdbus6 -> $q"; break; }
  done
fi
for cmd in jq python3 qdbus6; do command -v "$cmd" >/dev/null || echo "warning: $cmd not found (needed by the cockpit)" >&2; done

mkdir -p ~/.config/claude-cockpit ~/.local/bin ~/.claude/hooks ~/.config/systemd/user
echo "$ws" > ~/.config/claude-cockpit/workspace
[ -f "$ws/cockpit.json" ] || cp "$here/cockpit.example.json" "$ws/cockpit.json"

rules_repo=${CLAUDE_RULES_REPO:-git@github.com:stemiwe/claude-rules.git}
if [ ! -f "$ws/rules/RULES.md" ]; then
  choice=${CLAUDE_RULES:-}
  if [ -z "$choice" ] && [ -t 0 ]; then
    echo "Rules for the sessions (<workspace>/rules/):"
    echo "  1) use the shared ruleset ($rules_repo)"
    echo "  2) create your own (starts from its cockpit conventions)"
    read -rp "Choice [1/2]: " choice
  fi
  case "$choice" in
    1|shared) git clone -q "$rules_repo" "$ws/rules" && echo "cloned the rules into $ws/rules" ;;
    2|own)
      src=$(mktemp -d)
      git clone -q --depth 1 "$rules_repo" "$src"
      mkdir -p "$ws/rules"; cp "$src/cockpit.md" "$ws/rules/"; rm -rf "$src"
      printf '# Rules\n\nRules for every Claude session in this workspace.\n\n@cockpit.md\n' > "$ws/rules/RULES.md"
      git -C "$ws/rules" init -q -b main && echo "created your own rules in $ws/rules (push them to a repo of yours)" ;;
    *) echo "warning: no rules installed; re-run with CLAUDE_RULES=shared or own" >&2 ;;
  esac
fi
if [ -f "$ws/rules/RULES.md" ] && ! grep -qxF "@rules/RULES.md" "$ws/CLAUDE.md" 2>/dev/null; then
  if grep -qxF "@cockpit/RULES.md" "$ws/CLAUDE.md" 2>/dev/null; then sed -i 's#^@cockpit/RULES.md$#@rules/RULES.md#' "$ws/CLAUDE.md"
  else printf '\n@rules/RULES.md\n' >> "$ws/CLAUDE.md"; fi
  echo "$ws/CLAUDE.md now loads @rules/RULES.md"
fi

for f in "$here"/bin/*; do ln -sfn "$f" ~/.local/bin/"$(basename "$f")"; done
for f in session-name.sh session-state.sh sort-tabs.sh cockpit-pull.sh repo-pull.sh; do ln -sfn "$here/hooks/$f" ~/.claude/hooks/$f; done
ln -sfn "$here/hooks/statusline.sh" ~/.claude/statusline.sh
"$here/lib/konsole-color" --profiles '#FF0096'   # tab colour profiles (Konsole without setTabColor); #FF0096 = dashboard

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
  | add("UserPromptSubmit"; "~/.claude/hooks/cockpit-pull.sh")
  | add("UserPromptSubmit"; "~/.claude/hooks/repo-pull.sh")
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
