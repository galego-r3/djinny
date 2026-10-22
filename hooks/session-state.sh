#!/usr/bin/env bash
# Hook for several events: records each session's live state for the dashboard in
# ~/.cache/claude/sessions/<session_id>.json:
#   busy       — working (prompt submitted, tool finished)
#   question   — waiting for the user: permission/question dialog, or the turn ended with a question
#   idle       — turn ended without a question (dashboard shows nothing)
#   monitoring — turn ended but a wakeup/monitor/cron/background task is pending
# The dashboard ignores files whose Claude process ($pid) is gone.
dir="$HOME/.cache/claude/sessions"
mkdir -p "$dir"
in=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$in"); [ -z "$sid" ] && exit 0
event=$(jq -r '.hook_event_name // empty' <<<"$in")
f="$dir/$sid.json"

if [ "$event" = SessionEnd ]; then rm -f "$f"; exit 0; fi

# PID of the claude process that runs this hook (first "claude" ancestor)
pid=$PPID
for _ in 1 2 3 4 5; do
  [ "$(ps -o comm= -p "$pid" 2>/dev/null)" = claude ] && break
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' '); [ -z "$pid" ] && break
done

watch=$(jq -r '.watch // false' "$f" 2>/dev/null || echo false)
case "$event" in
  UserPromptSubmit) state=busy; watch=false ;;   # a scheduled wakeup that fires also lands here
  PostToolUse)
    state=busy
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
      case "$msg" in *\?*|*"Your turn:"*) state=question ;; *) state=idle ;; esac
    fi ;;
  *) exit 0 ;;
esac

jq -nc --arg state "$state" --argjson watch "$watch" --arg cwd "$(jq -r '.cwd // empty' <<<"$in")" \
  --argjson pid "${pid:-0}" --argjson ts "$(date +%s)" \
  '{state:$state, watch:$watch, cwd:$cwd, pid:$pid, ts:$ts}' > "$f.tmp" && mv "$f.tmp" "$f"
exit 0
