# Claude in Konsole tabs. Sourced from ~/.bashrc (line added by install.sh).
# Leaving an interactive claude session (/exit) closes the tab too, unless claude failed. Only for
# plain interactive runs typed at a prompt: not -p/--print, --version, --help or subcommands.
claude() {
  command claude "$@"; local rc=$?
  if [[ $- == *i* && -t 0 && -n $KONSOLE_DBUS_SESSION && $rc -eq 0 && ( -z $1 || $1 == -* ) ]]; then
    case " $* " in *" -p "*|*" --print "*|*" -v "*|*" --version "*|*" -h "*|*" --help "*) ;; *) exit 0 ;; esac
  fi
  return $rc
}
# A tab opened by the dashboard starts claude: the dashboard writes this folder into the marker
# just before opening the tab (Konsole's D-Bus can't run commands in a tab).
_m="$HOME/.cache/claude/autostart"
if [[ $- == *i* && -f $_m && $(<"$_m") == "$PWD" && $(( $(date +%s) - $(stat -c %Y "$_m") )) -lt 15 ]]; then
  rm -f "$_m"; unset _m; claude
fi
unset _m
