# Cockpit rules

Rules for every session in a workspace run by the Claude cockpit. The workspace's root `CLAUDE.md` loads
this file (`@cockpit/RULES.md`); its own rules come on top. "Workspace" = the folder the cockpit was
installed for (here: the parent of this file's folder).

- **C1. Projects.** A project is a folder with its own `CLAUDE.md` and no project below it. Parent folders
  only group projects: they hold no files and no `CLAUDE.md`. Work happens inside the project folder; read
  its `CLAUDE.md` first. The dashboard shows projects at most two levels deep (`group/project`, setting
  `depth` in `cockpit.json`): a project further down (e.g. one worktree per session in `code/wba/wba-31`) is
  counted toward its ancestor at that depth (`code/wba`), whose `CLAUDE.md` then holds the `Status:` line.
  Every project `CLAUDE.md` starts with a **`Status:` line** right under its title:
  one short line on where the project stands now. Update it whenever that changes; the dashboard shows it.
  **Archiving**: a finished project gets `Status: archived YYYY-MM-DD — <one line on the outcome>`. It stays
  where it is, but the dashboard no longer lists it and its jobs stop. Remove the word to bring it back.
- **C2. Session names and tab colours.** Session name = folder path relative to the workspace, at most
  two levels like the dashboard rows (e.g. `family/schule`; `code/wba/wba-31` is `code/wba`); the root's name is the workspace folder's name. The SessionStart hook sets it, along with
  the Konsole tab title, tab colour and the status-line logo, and re-sorts the tabs. Don't rename sessions.
  Colours come from `colors` in the workspace's `cockpit.json` (longest matching path wins). Every project
  has its own colour; projects in the same parent folder get shades of one hue. A new project gets a
  colour that fits these rules: `tab-color <colour> [<project>]` adds it to `cockpit.json` and colours
  the tab now. When the user names a colour for a session ("use red"), run `tab-color red` there.
- **C3. Temporary files** go in `<workspace>/tmp/<project>/` (screenshots, downloads, test output), never
  in `~`, `/tmp` or other places outside the workspace, so no extra permissions are needed. `tmp/` is not
  versioned; anything in it may be deleted. Keep files that matter in the project folder.
- **C4. Regular jobs** never get their own cron/systemd setup. A project puts an executable in
  `<project>/jobs/<name>` with a line `# every: 5h` (m/h/d) in its first 20 lines; it runs with the project
  folder as working directory, 30 min timeout, retried after 15 min when it fails (non-zero exit). The
  runner `claude-jobs` (systemd user timer, every 5 min) runs whatever is due: `claude-jobs list` shows
  status, `claude-jobs run <project>/<name>` runs one now; logs in `~/.local/state/claude-jobs/logs/`.
  Jobs in the workspace root are named `<workspace name>/<name>`. Jobs run unattended: no prompts,
  secrets from the keyring or env vars, output files in the project folder.
- **C6. Secrets** (API keys, passwords) live in the keyring, never in files or repos. To have the user store one,
  ask for the short form `! secret set <service> [attr value]…` (e.g. `! secret set aligulac`; it prompts for
  the value hidden), not a long `secret-tool store --label=…` line. Scripts read it with
  `secret get <service> […]` or `secret-tool lookup service <service> […]` (same entry).
- **C5. The cockpit itself** lives in `<workspace>/cockpit/` (its own git repo, generic: nothing about one
  person or workspace in it). It is changed from the workspace's root session; project sessions that need a
  change tell the user to do it there. Workspace-specific settings go in `<workspace>/cockpit.json`.
- **C7. Sessions talk to each other directly.** Never make the user relay messages between sessions. A session
  that needs another project's session uses `ListAgents` / `SendMessage` (the receiving session's name is
  shown there) and asks it itself; the receiver answers the same way. Only ask the user for a decision or
  for what only they can do (a login, a payment, a secret, a confirmation the session must not click itself).
