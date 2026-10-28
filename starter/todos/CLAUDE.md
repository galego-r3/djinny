# todos

Status: new — central to-do list, empty

Owns the central to-do list (`TODO.md`) and the daily agenda (`AGENDA.md`). Other sessions only add or tick off
their own items (rule W3); a session started here does the real to-do work: reviewing, prioritising, cleaning
up, reminding, keeping the format consistent. Quick to-dos without a session: `todo` (see `todo --help`).

## `chores.md` format (in each project folder)
One markdown table: `| Chore | Interval | Last done | Next due | Details |`, dates `YYYY-MM-DD`. When a chore
is done, update "Last done" and recompute "Next due".
