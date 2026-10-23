#!/usr/bin/env bash
# Hook for several events: records each session's live state for the dashboard in
# ~/.cache/claude/sessions/<session_id>.json:
#   busy       — working (prompt submitted, tool finished)
#   question   — waiting for the user: permission/question dialog, or the turn ended with a question
#   idle       — turn ended without a question (dashboard shows nothing)
#   monitoring — turn ended but a wakeup/monitor/cron/background task is pending
# The dashboard drops files whose Claude process ($pid) is gone.
# A turn that ends with a question is also saved, independent of the session, in
# <workspace>/.cockpit/questions/<session_id>.json ({project, text, asked, session, host}; project = path
# relative to the workspace, "." for the root). It's versioned with the workspace, so it survives restarts and
# moves to other machines, and stays until the user writes in that project (any session there that isn't
# running elsewhere) or dismisses it on the dashboard.
. "$(dirname "$(readlink -f "$0")")/../lib/env.sh"
dir="$HOME/.cache/claude/sessions"
qdir="$ws/.cockpit/questions"
mkdir -p "$dir"
in=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$in"); [ -z "$sid" ] && exit 0
event=$(jq -r '.hook_event_name // empty' <<<"$in")
f="$dir/$sid.json"
cwd=$(jq -r '.cwd // empty' <<<"$in")

if [ "$event" = SessionEnd ]; then rm -f "$f"; exit 0; fi

# PID of the claude process that runs this hook (first "claude" ancestor)
pid=$PPID
for _ in 1 2 3 4 5; do
  [ "$(ps -o comm= -p "$pid" 2>/dev/null)" = claude ] && break
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' '); [ -z "$pid" ] && break
done

# The project is where the session was started (Claude Code's registry), not where it has cd'ed to since
start=$(jq -r '.cwd // empty' "$HOME/.claude/sessions/$pid.json" 2>/dev/null); [ -n "$start" ] || start=$cwd
case "$start" in "$ws") rel=. ;; "$ws"/*) rel=${start#"$ws"/} ;; *) rel= ;; esac

watch=$(jq -r '.watch // false' "$f" 2>/dev/null || echo false)
case "$event" in
  UserPromptSubmit)
    state=busy; watch=false   # a scheduled wakeup that fires also lands here
    # The user is at this project again: its saved questions are answered, except those of other
    # sessions still running on this machine
    if [ -n "$rel" ] && [ -d "$qdir" ]; then
      for q in "$qdir"/*.json; do
        [ -f "$q" ] && [ "$(jq -r '.project // empty' "$q" 2>/dev/null)" = "$rel" ] || continue
        qs=$(basename "$q" .json)
        if [ "$qs" != "$sid" ]; then
          qp=$(jq -r '.pid // 0' "$dir/$qs.json" 2>/dev/null)
          [ "$(cat "/proc/${qp:-0}/comm" 2>/dev/null)" = claude ] && continue
        fi
        rm -f "$q"
      done
    fi
    rm -f "$qdir/$sid.json" ;;
  PostToolUse)
    state=busy; rm -f "$qdir/$sid.json"   # working again (e.g. on a message from another session)
    tool=$(jq -r '.tool_name // empty' <<<"$in")
    case "$tool" in
      ScheduleWakeup|Monitor|CronCreate) watch=true ;;
      Bash) [ "$(jq -r '.tool_input.run_in_background // false' <<<"$in")" = true ] && watch=true ;;
    esac ;;
  Notification)
    case "$(jq -r '.notification_type // empty' <<<"$in")" in
      permission_prompt|elicitation_dialog) state=question ;;
      *) exit 0 ;;
    esac ;;
  Stop)
    if [ "$watch" = true ]; then state=monitoring
    else
      # Last reply asks something ("?" or the "Your turn:" marker in its last 300 chars) -> question, else idle
      msg=$(jq -r '.last_assistant_message // empty' <<<"$in")
      tp=$(jq -r '.transcript_path // empty' <<<"$in")
      [ -z "$msg" ] && [ -f "$tp" ] && msg=$(tail -n 200 "$tp" | jq -rs \
        '[.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text] | last // ""')
      if [ "${#msg}" -gt 300 ]; then msg=${msg: -300}; fi
      case "$msg" in *\?*|*"Your turn:"*) state=question ;; *) state=idle; rm -f "$qdir/$sid.json" ;; esac
      if [ "$state" = question ] && [ -n "$rel" ]; then
        mkdir -p "$qdir"
        jq -nc --arg project "$rel" --arg text "$msg" --argjson asked "$(date +%s)" --arg session "$sid" \
          --arg host "$(hostname)" '{project:$project, text:$text, asked:$asked, session:$session, host:$host}' \
          > "$qdir/.$sid.tmp" && mv "$qdir/.$sid.tmp" "$qdir/$sid.json"
      fi
    fi ;;
  *) exit 0 ;;
esac

jq -nc --arg state "$state" --argjson watch "$watch" --arg cwd "$cwd" \
  --argjson pid "${pid:-0}" --argjson ts "$(date +%s)" \
  '{state:$state, watch:$watch, cwd:$cwd, pid:$pid, ts:$ts}' > "$f.tmp" && mv "$f.tmp" "$f"
exit 0
