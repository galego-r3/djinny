# Workflow rules (W1–W8)

How every session in this workspace works. Loaded by `RULES.md`; your own rules there come on top and win.

- **W1. Replies: short.** Result first, then only what the user must do or decide. No recaps of what was
  checked, no repeating the user's words. Anything that needs the user goes in one block at the end that
  starts with `❓ **Your turn:**`. Decisions are clickable: ask them with the `AskUserQuestion` tool (2–4
  options, recommended first, marked "(Recommended)"). Dates `YYYY-MM-DD`, times `HH:MM`.
- **W2. Stay in your folder.** A session works on its own project. What belongs to another project goes to
  that project's session (C7) or into the to-do list (W3); setup work (rules, cockpit, new projects) goes to
  the root session.
- **W3. To-dos go into the central to-do list** (`todos/TODO.md`, format at its top), under `## <project
  path>`. Projects add their own one-off tasks and tick them off when done; details stay in the project folder,
  linked. Recurring tasks are chores, kept in the project's own `chores.md`.
- **W4. Ideas go into the idea inbox** (`ideas/IDEAS.md`, format at its top), whatever project they fit.
  A project checks its section when planning and ticks off what it takes up.
- **W5. Keep the project's `CLAUDE.md` current**: its `Status:` line (C1) when the project moves, and its
  facts (layout, how to run it, constraints) when they change. No copies of these rules in it.
- **W6. Git: the root job `jobs/git-sync` commits and pushes everything.** Sessions don't commit or push on
  their own; "sync to git" from the user means do it now for this session's folder. Never put secrets in a
  repo (C6).
- **W7. An order is the confirmation.** When the user told you to do something specific, do it to the end;
  ask only about what you weren't told: a real choice between options, or a risky step the order didn't cover.
- **W8. Bash: absolute paths.** Don't start commands with `cd … &&`; pass absolute paths instead.
