# Welcome (first start of the cockpit)

Read by the root session on its first start in a workspace that has nothing but the cockpit
(`hooks/session-name.sh`). Greet the user and walk them through this in the session's normal reply style,
then offer the starter. Run `cockpit-starter --dry-run` first if you want to show exactly what it would create.

## What to explain
- **One workspace, one session per project.** The workspace is one folder (this one). Every project is a
  folder with its own `CLAUDE.md` and gets its own Claude session in its own Konsole tab, coloured per project.
  Projects are grouped in category folders, at most two levels (`work/reports`, `home/garden`).
- **The root session** (this one) is the operator: it sets up rules, projects, the folder map and the
  cockpit. Real work happens in the project sessions; sessions talk to each other directly (`SendMessage`).
- **The dashboard** shows every project with its `Status:` line and live state (busy, question, idle);
  click a project to open or switch to its session. Tabs for to-dos, the agenda and jobs.
- **Rules** in `rules/` (`RULES.md` loads the cockpit conventions C1–C7, plus your own) apply to every session.
- **Shared lists**: one central to-do list for all projects (`todos/TODO.md`, `todo` command, dashboard tab),
  a daily agenda, and an idea inbox (`ideas/IDEAS.md`) every session adds to.
- **Jobs**: a script in `<project>/jobs/` with `# every: 5h` runs on its own (`claude-jobs list`).
- **Secrets** in the keyring (`secret set <name>`), never in files. Scratch files in `tmp/`.

## The offer
Ask with `AskUserQuestion`:
- "Deploy the starter structure (Recommended)": run `cockpit-starter`. It creates an empty shell, no data:
  the root `CLAUDE.md` (operator tasks, folder map), `rules/workflow.md` (how sessions work: short replies,
  central to-dos and ideas, git, …, loaded from `RULES.md`), `todos/`, `ideas/`, `projects/`, `tmp/`,
  `jobs/git-sync`, a `.gitignore`, and the to-do settings in `cockpit.json`. It never overwrites a file.
- "Just explain, I'll build my own": nothing to do; they can run `cockpit-starter` any time later.
After deploying, report what was created in a few bullets and suggest the next step: "tell me your first
project" (then create it as `CLAUDE.md` describes).
