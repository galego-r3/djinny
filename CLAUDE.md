# Claude cockpit

Status: dashboard, tab handling, status line and job runner work; first shared version

The generic cockpit for running Claude Code sessions per project in Konsole tabs: the dashboard TUI, the hooks,
the status line, the job runner and the session rules (`RULES.md`). What it does, its layout and how to
install it are in `README.md`.

- **Keep it generic.** Colleagues at work use this repo too. Nothing about one person, machine or workspace
  goes in here, no names, paths or colours: those belong in the workspace's `cockpit.json` and `CLAUDE.md`.
- It's worked on from the workspace's root session (`RULES.md` C5). The dashboard counts this folder as the root.
- Shell scripts find the workspace through `lib/env.sh`; the two Python scripts each carry a copy of `workspace()`
  (`python3 -I` can't import from the script's folder).
- After changing `install.sh`, `systemd/` or the hook list, re-run `./install.sh`. Hooks, `bin/` and the status
  line are symlinked, so other edits take effect immediately.
- Test without side effects: `dashboard --once`, `claude-jobs list`, pipe `{"cwd": "…"}` into a hook.
