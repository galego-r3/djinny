# Cockpit rules

Rules for every session in a workspace run by the Claude cockpit. The workspace's root `CLAUDE.md` loads
this file (`@cockpit/RULES.md`); its own rules come on top. "Workspace" = the folder the cockpit was
installed for (here: the parent of this file's folder).

- **C1. Projects.** A project is a folder with its own `CLAUDE.md` and no project below it. Parent folders
  only group projects: they hold no files and no `CLAUDE.md`. Work happens inside the project folder; read
  its `CLAUDE.md` first. Every project `CLAUDE.md` starts with a **`Status:` line** right under its title:
  one short line on where the project stands now. Update it whenever that changes; the dashboard shows it.
  **Archiving**: a finished project gets `Status: archived YYYY-MM-DD — <one line on the outcome>`. It stays
  where it is, but the dashboard no longer lists it and its jobs stop. Remove the word to bring it back.
- **C2. Session names and tab colours.** Session name = folder path relative to the workspace (e.g.
  `family/schule`); the root's name is the workspace folder's name. The SessionStart hook sets it, along with
  the Konsole tab title, tab colour and the status-line logo, and re-sorts the tabs. Don't rename sessions.
  Colours come from `colors` in the workspace's `cockpit.json` (longest matching path wins). Every project
  has its own colour; projects in the same parent folder get shades of one hue. A new project gets a
  colour that fits these rules (add it to `cockpit.json`).
- **C3. Temporary files** go in `<workspace>/tmp/<project>/` (screenshots, downloads, test output), never
  in `~`, `/tmp` or other places outside the workspace, so no extra permissions are needed. `tmp/` is not
  versioned; anything in it may be deleted. Keep files that matter in the project folder.
- **C4. Regular jobs** never get their own cron/systemd setup. A project puts an executable in
  `<project>/jobs/<name>` with a line `# every: 5h` (m/h/d) in its first 20 lines; it runs with the project
  folder as working directory, 30 min timeout, retried after 15 min when it fails (non-zero exit). The
  runner `claude-jobs` (systemd user timer, every 5 min) runs whatever is due: `claude-jobs list` shows
  status, `claude-jobs run <project>/<name>` runs one now; logs in `~/.local/state/claude-jobs/logs/`.
  Jobs in the workspace root are named `<workspace name>/<name>`. Jobs run unattended: no prompts,
  secrets from the keyring (`secret-tool`) or env vars, output files in the project folder.
- **C5. The cockpit itself** lives in `<workspace>/cockpit/` (its own git repo, generic: nothing about one
  person or workspace in it). It is changed from the workspace's root session; project sessions that need a
  change tell the user to do it there. Workspace-specific settings go in `<workspace>/cockpit.json`.
