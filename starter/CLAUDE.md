# Workspace root

Status: new — starter structure deployed, no projects yet

This is the workspace's root. Each project is a folder with its own `CLAUDE.md`; see the folder map below.
The root session (the operator) only sets up the Claudes: rules, the folder map, the `~/.claude` config and
the cockpit. Project work, to-dos and chores happen in the project folders, each in its own session.
Keep this file short; update it when folders change.

@RULES_DIR/RULES.md

## Operator tasks
- **New project**: ask the user what it is for if unclear; create `<category>/<name>/CLAUDE.md` (title,
  `Status: new — …` line, 1–3 lines of purpose), give it a colour (`tab-color <colour> <category>/<name>`,
  shades of one hue per category), add it to the folder map below, then open its session:
  `curl -s -X POST -H 'X-Cockpit: 1' -H 'Content-Type: application/json' -d '{"project":"<path>"}' http://127.0.0.1:8765/api/open`.
- **New category**: just a folder that groups projects (no files of its own); add it to the map.
- **Rules**: general rules in `RULES_DIR/`; a project's own facts and allowed exceptions in its `CLAUDE.md`.
- **Git** (optional): with a remote set (`git remote add origin …`), the job `jobs/git-sync` commits and pushes
  the workspace and every nested repo every 5h. A project that should have its own repo gets `git init` in its
  folder; the workspace repo leaves it out.

## Folders
- `RULES_DIR/` — rules for every session (`RULES.md`, cockpit conventions `cockpit.md`, workflow `workflow.md`).
- `cockpit/` — the cockpit (dashboard, hooks, jobs); its own repo.
- `cockpit.json` — this workspace's cockpit settings (tab colours, to-do file, …).
- `todos/` — central to-do list (`TODO.md`) and daily agenda (`AGENDA.md`).
- `ideas/` — idea inbox for every project (`IDEAS.md`).
- `jobs/` — root jobs (`git-sync`).
- `projects/` — category for projects (add more categories as needed, e.g. `work/`, `home/`, `family/`).
- `tmp/` — scratch space (rule C3); not versioned.
