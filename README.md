# Claude cockpit

A terminal cockpit for running many Claude Code sessions side by side, one per project, in KDE Konsole tabs.

- **Dashboard** (`dashboard`): a full-screen TUI with one row per project. Each row shows the tab colour,
  the live state (busy / question / monitoring), the project's `Status:` line, the last tool call of a running
  session ("bash: git push", "edit: lib.php") and tokens used (5h / 7d / all time). Click a project to switch to its tab, or to open a new tab that starts `claude`. Press 1–9 to
  dismiss a question row (marks it idle, no tokens used). `q` quits.
- **Tabs**: each session is named after its folder (at most two levels deep, like the dashboard rows) and gets its tab title and colour automatically. Tabs
  are kept sorted: DASH, the root, projects A–Z, unnamed tabs last. Leaving `claude` closes its tab.
- **Status line**: model, context use, rate limits (▲ = used faster than the window passes), estimated
  cost, plus a big two-line logo of the project name in its tab
  colour.
- **Tab colours** (`tab-color`): `tab-color red` saves the current project's colour in `cockpit.json` and
  colours its tab now; sessions run it when the user names a colour.
- **Jobs** (`claude-jobs`): runs `<project>/jobs/<name>` scripts on their interval (systemd user timer).
- **Archive**: a project whose `Status:` line starts with `archived` is hidden from the dashboard and its
  jobs stop (rules C1).
- **Secrets** (`secret`): `secret set aligulac` stores an API key in the keyring (hidden prompt), `secret get`
  reads it. A shorter way to type `secret-tool store --label=… service …`. With `vault` set in `cockpit.json`
  and the 1Password CLI (`op`, app integration on), every secret is also kept in that 1Password vault:
  `secret push` copies the keyring into it, `secret pull` fills a new machine's keyring from it, and
  `secret get` falls back to it. Jobs still read the keyring, so they run without 1Password.
- **Updates**: every prompt pulls the cockpit in the background, so a change pushed from another machine
  arrives without doing anything; the next prompt says what came in.
- **Rules**: not in here. They're a separate repo in `<workspace>/rules/` ([claude-rules](https://github.com/stemiwe/claude-rules));
  `install.sh` asks whether to use the shared ruleset or start your own, and the workspace's `CLAUDE.md` loads it.

## Layout

| Path | What |
| --- | --- |
| `bin/dashboard` | the TUI (Python 3, no dependencies) |
| `bin/claude-jobs` | job runner |
| `bin/tab-color` | set a project's tab colour in `cockpit.json` and apply it to the tab |
| `bin/secret` | short form of `secret-tool`: `secret set/get/del <service> [attr value]…`, `push`/`pull` to 1Password |
| `hooks/session-name.sh` | SessionStart hook: session/tab name, tab colour, tab sorting |
| `hooks/session-state.sh` | records each session's live state for the dashboard (`~/.cache/claude/sessions/`) and saves open questions apart from the session in `<workspace>/.cockpit/questions/` (versioned, so they move between machines) |
| `hooks/cockpit-pull.sh` | UserPromptSubmit hook: pulls the cockpit in the background (at most once a minute, fast-forward only, never over local changes), re-runs `install.sh` when the pull touched it, `systemd/` or `plugins/`, reports the update on the next prompt; log `~/.cache/claude/cockpit-pull.log` |
| `hooks/sort-tabs.sh` | sorts the Konsole tabs of the current window |
| `hooks/statusline.sh` | Claude Code status line |
| `plugins/worklog/` | Claude Code mod: side pane with the project's status, the open `Your turn:` questions and a work log; `/worklog` reopens it |
| `shell/bashrc.sh` | sourced from `~/.bashrc`: dashboard-opened tabs start `claude`; `/exit` closes the tab |
| `lib/env.sh` | shared shell helpers: workspace location, session names, colours |
| `lib/konsole-color` | colours a Konsole tab: `setTabColor`, or on Konsole 26.08+ (no `setTabColor`) a generated profile `cockpit-RRGGBB` per colour in `~/.local/share/konsole/` (new colours show after a Konsole restart) |
| `systemd/` | `claude-jobs.service` / `.timer` |
| `cockpit.example.json` | template for the workspace's `cockpit.json` |

## Install

Needs Linux, KDE Konsole (D-Bus via `qdbus6`; Fedora: package `qt6-qttools`, whose `qdbus-qt6` the
installer links as `qdbus6`), Claude Code, `jq`, Python 3, systemd (user units) and
`secret-tool` (`libsecret-tools`).

1. Clone this repo into your workspace as `cockpit/`, e.g. `git clone … ~/claude/cockpit`.
2. Run `cockpit/install.sh`. It takes the parent folder as the workspace, or pass a path as the first
   argument. You can re-run it at any time. It:
   - links `bin/*` into `~/.local/bin`, the hooks into `~/.claude/hooks` and the status line to
     `~/.claude/statusline.sh`
   - adds whatever is missing to `~/.claude/settings.json` (backup in `settings.json.bak`): hooks, status line, and
     every folder in `plugins/` in `env.CLAUDE_CODE_PLUGIN_DIRS`, so each session loads them
   - installs and starts `claude-jobs.timer`
   - adds a line to `~/.bashrc` that loads `shell/bashrc.sh`
   - writes `<workspace>/cockpit.json` from the example if it doesn't exist
3. `install.sh` sets up the rules (shared or your own) and adds `@rules/RULES.md` to the workspace's root `CLAUDE.md`.
4. Optional: in `cockpit.json`, set tab colours (`colors`) and folders to skip (`hidden`).
5. Start `dashboard` in a Konsole tab and open projects by clicking them.

## Workspace config: `<workspace>/cockpit.json`

```json
{
  "name":      "claude",
  "vault":     "cockpit",
  "colors":    { "claude": "#7EC8F7", "work/reports": "#FFD600" },
  "hidden":    ["cockpit", "tmp"],
  "aliases":   { "old-name": "new-name" },
  "old_roots": ["~/old/workspace/location"],
  "depth":     2,
  "job_host":  "my-desktop"
}
```

- `name`: the root's session, tab and dashboard row name; default: the workspace folder's name.
- `vault`: a 1Password vault that `secret` mirrors every secret into (see Secrets); optional.
- `colors`: Konsole tab colour per folder path, relative to the workspace. The longest match wins, so a
  colour on a parent folder covers all its projects. The root is listed under its `name`.
- `hidden`: folders that the dashboard and the job runner skip.
- `depth` (default 2): how deep dashboard rows go. Deeper projects, e.g. worktrees in `group/repo/worktree`,
  count toward their ancestor at that depth.
- `job_host`: with several machines on one workspace, the hostname that runs the jobs; others run only
  jobs marked `# machines: all`, and take over the rest if the job host's heartbeat
  (`.cockpit/job-host.json`) is older than a day. Unset: every machine runs every job.
- `aliases` / `old_roots`: renamed folders and earlier workspace locations, so that older transcripts
  still count toward the right project's token use.

The workspace location comes from `$CLAUDE_WORKSPACE`, or else from `~/.config/claude-cockpit/workspace`
(written by `install.sh`), or else defaults to `~/claude`.

## How it fits together

- **Live state**: the hooks `UserPromptSubmit`, `PostToolUse`, `Notification`, `Stop` and `SessionEnd`
  write `~/.cache/claude/sessions/<session id>.json`. A session counts as **question** when its last reply
  contains a `?` or `Your turn:` in its last 300 characters, or a permission dialog is open. It counts as
  **monitoring** when a wakeup, monitor or background task is pending. Sessions without a state file (started
  before the hooks were installed) fall back to Claude Code's own registry in `~/.claude/sessions/<pid>.json`
  (`busy`, `shell` = monitoring, `waiting` = question unless only a dialog the user opened).
- **Last action**: the last `tool_use` in the tail of a running session's transcript, worded as what was done,
  never prompt text.
- **Token use**: comes from the transcripts in `~/.claude/projects`, counting input + cache writes +
  output (cache reads are left out). The 5h / 7d windows line up with the subscription limits that the
  status line caches.
- **Konsole**: the cockpit only uses D-Bus calls that work while Konsole's "security sensitive D-Bus API" is
  off. That setting blocks sending commands into a tab, so a dashboard-opened tab starts `claude` through a
  marker file (`~/.cache/claude/autostart`) that `shell/bashrc.sh` reads.
