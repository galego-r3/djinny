"""The workspace's to-do file and chores, shared by bin/todo and bin/dashboard (format: README.md).

To-do file (cockpit.json "todo_file"): `## <section>` headings (a project path, optionally with " — note",
or a free name like "Priority"); items `- [ ] **What** — context → link (added YYYY-MM-DD)`, ticked as
`- [x] … (done YYYY-MM-DD)`. Chores: a markdown table `| Chore | Interval | Last done | Next due | Details |`
in any project's `chores.md`.
Agenda file (cockpit.json "agenda_file"): the day's focus, one `## YYYY-MM-DD` section per day, newest first,
items `- [ ] What` (ticked `- [x]`).
"""
import datetime, os, re
from pathlib import Path

ITEM = re.compile(r"^- \[( |x)\] (.*)$")

def todo_file(root, conf):
    f = conf.get("todo_file")
    return root / f if f else None

def section_project(name):
    """Heading text -> the project path it belongs to ("family/schule — Nela" -> "family/schule")."""
    return name.split(" — ")[0].strip()

def parse(text):
    """[(section, [(line index, done, item text)])] in file order."""
    sections, cur = [], None
    for i, line in enumerate(text.splitlines()):
        if line.startswith("## "):
            cur = (line[3:].strip(), [])
            sections.append(cur)
        elif cur is not None:
            m = ITEM.match(line)
            if m:
                cur[1].append((i, m.group(1) == "x", m.group(2)))
    return sections

def open_items(path):
    """[(section, line index, item text)] of all open items, in file order."""
    try:
        text = path.read_text()
    except OSError:
        return []
    return [(sec, i, t) for sec, items in parse(text) for i, done, t in items if not done]

def plain(item):
    """Item text for display: no markdown, no link and no (added …) date."""
    t = re.sub(r"\s*\(added \d{4}-\d{2}-\d{2}\)", "", item)
    t = re.sub(r"\s*→.*$", "", t)
    return t.replace("**", "").replace("`", "").strip(" —")

def _write(path, lines):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text("\n".join(lines) + "\n")
    tmp.replace(path)

def add(path, section, text, today=None):
    """Adds an open item under `## section` (created if missing). "What — context" makes "What" bold."""
    today = today or datetime.date.today().isoformat()
    what, _, ctx = text.partition(" — ")
    item = f"- [ ] **{what.strip()}**" + (f" — {ctx.strip()}" if ctx.strip() else "") + f" (added {today})"
    lines = path.read_text().splitlines() if path.exists() else []
    heads = [(i, l[3:].strip()) for i, l in enumerate(lines) if l.startswith("## ")]
    at = next((i for i, h in heads if section_project(h) == section or h == section), None)
    if at is None:
        # New section: before the first later section in A–Z order (fixed sections like "Priority" and
        # headings with a " — note" stay where they are), else at the end
        later = [i for i, h in heads if " — " in h or ("/" in h and h > section)]
        pos = later[0] if later else len(lines)
        block = [f"## {section}", item, ""]
        if pos == len(lines) and lines and lines[-1].strip():
            block.insert(0, "")
        lines[pos:pos] = block
    else:
        end = next((i for i, _ in heads if i > at), len(lines))
        last = max((i for i in range(at + 1, end) if ITEM.match(lines[i])), default=at)
        lines.insert(last + 1, item)
    _write(path, lines)

def tick(path, index, text, today=None):
    """Marks the open item at line `index` done, if that line still holds `text`. Returns True on success."""
    today = today or datetime.date.today().isoformat()
    lines = path.read_text().splitlines()
    if index >= len(lines) or lines[index] != f"- [ ] {text}":
        return False
    lines[index] = f"- [x] {text} (done {today})"
    _write(path, lines)
    return True

def agenda_file(root, conf):
    f = conf.get("agenda_file")
    return root / f if f else None

def agenda(path):
    """(date, [(line index, done, item text)]) of the newest dated section, or (None, [])."""
    try:
        text = path.read_text()
    except OSError:
        return None, []
    days = [s for s in parse(text) if re.fullmatch(r"\d{4}-\d{2}-\d{2}", s[0])]
    return max(days, key=lambda s: s[0]) if days else (None, [])

def set_agenda(path, items, today=None):
    """Writes today's agenda (replacing an earlier one of today) as the first section."""
    today = today or datetime.date.today().isoformat()
    lines = path.read_text().splitlines() if path.exists() else ["# Agenda", ""]
    heads = [i for i, l in enumerate(lines) if l.startswith("## ")]
    at = next((i for i in heads if lines[i][3:].strip() == today), None)
    if at is not None:
        end = next((i for i in heads if i > at), len(lines))
        del lines[at:end]
        heads = [i for i, l in enumerate(lines) if l.startswith("## ")]
    pos = heads[0] if heads else len(lines)
    if pos == len(lines) and lines and lines[-1].strip():
        lines.append(""); pos += 1
    lines[pos:pos] = [f"## {today}", *(f"- [ ] {t.strip()}" for t in items if t.strip()), ""]
    _write(path, lines)

def chores(root, hidden=(), skip=(".git", ".venv", "node_modules")):
    """[(next due date, project, chore, last done)] from every project's chores.md table."""
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel = os.path.relpath(dirpath, root)
        dirnames[:] = [d for d in dirnames if d not in skip and not d.startswith(".")
                       and os.path.normpath(os.path.join(rel, d)) not in hidden]
        if "chores.md" not in filenames:
            continue
        project = root.name if rel == "." else rel
        try:
            text = (Path(dirpath) / "chores.md").read_text(errors="replace")
        except OSError:
            continue
        for line in text.splitlines():
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) >= 4 and re.fullmatch(r"\d{4}-\d{2}-\d{2}", cells[3]):
                out.append((cells[3], project, cells[0].replace("**", ""), cells[2]))
    return sorted(out)
