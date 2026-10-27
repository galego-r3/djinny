#!/usr/bin/env bash
# UserPromptSubmit hook: keep the cockpit current. On every prompt (at most once a minute) pull the cockpit
# repo in the background, fast-forward only, never over local changes (a history rewritten upstream is
# taken over, the old one kept in a branch pre-rewrite-<date>); re-run install.sh when the pull
# touched install.sh, systemd/ or plugins/, else restart cockpit-web when its code changed. What a pull brought in is reported on the next prompt.
# Log: ~/.cache/claude/cockpit-pull.log
here=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
cache="$HOME/.cache/claude"; mkdir -p "$cache"
stamp="$cache/cockpit-pull.stamp" news="$cache/cockpit-pull.news" log="$cache/cockpit-pull.log"
cat >/dev/null

# Report the previous pull, once
if [ -s "$news" ]; then
  jq -n --arg m "$(cat "$news")" '{systemMessage: $m}'
  rm -f "$news"
fi

[ -f "$stamp" ] && [ $(( $(date +%s) - $(stat -c %Y "$stamp") )) -lt 60 ] && exit 0
touch "$stamp"

setsid bash -c '
  here=$1 news=$2
  exec 9>"$here/.git/cockpit-pull.lock"; flock -n 9 || exit 0
  cd "$here" || exit 0
  [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "$(date -Is) skipped: local changes"; exit 0; }
  old=$(git rev-parse HEAD)
  if ! GIT_TERMINAL_PROMPT=0 timeout 30 git pull -q --ff-only; then
    # History rewritten upstream (no common commit): keep the old one in a branch, take the new one
    up=$(git rev-parse --abbrev-ref "@{u}" 2>/dev/null) && git rev-parse -q --verify "$up" >/dev/null \
      && ! git merge-base HEAD "$up" >/dev/null || { echo "$(date -Is) pull failed"; exit 0; }
    git branch -f "pre-rewrite-$(date +%F)" HEAD && git reset -q --hard "$up" \
      && echo "$(date -Is) history rewritten upstream: old one kept in pre-rewrite-$(date +%F)"
    ./install.sh >/dev/null 2>&1
    echo "Cockpit updated: its history was rewritten upstream; the old one is kept in branch pre-rewrite-$(date +%F)" > "$news"
    exit 0
  fi
  new=$(git rev-parse HEAD)
  [ "$old" = "$new" ] && exit 0
  echo "$(date -Is) $old -> $new"
  msg="Cockpit updated: $(git log --format=%s "$old..$new" | head -5 | paste -sd ";" | sed "s/;/; /g")"
  if git diff --name-only "$old" "$new" | grep -qE "^(install\.sh|systemd/|plugins/)"; then
    ./install.sh >/dev/null 2>&1 && msg="$msg (install.sh re-run; new hooks apply to sessions started from now on)"
  elif git diff --name-only "$old" "$new" | grep -qE "^(bin/dashboard|bin/cockpit-web|lib/)"; then
    systemctl --user try-restart cockpit-web.service 2>/dev/null   # the web dashboard runs the new code
  fi
  echo "$msg" > "$news"
' _ "$here" "$news" </dev/null >>"$log" 2>&1 &
exit 0
