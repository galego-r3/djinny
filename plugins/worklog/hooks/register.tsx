import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { LogEntry } from '../types'

// Side pane: the open "❓ Your turn" block of the last reply, each action spelled out from the whole reply by a small
// model (what to do, where, why; the bare block until it answers), the project's open to-dos with their detail lines
// (cockpit.json "todo_file", section "## <project>"), the project's Status: line, and one log line per turn: its
// topic in a few words (summarised by a small model; until it answers, or if it fails, the start of the prompt).
// The log gets only the rows left over. cockpit.json "panes": {"<project>": {"title": …, "file": …, "match": …}}
// replaces the log of that project with the lines of a file (path from the workspace) that match the regex "match"
// (default: "## " headings, else the top-level "- " items), re-read each turn.
const PANE = 'worklog'
const TITLE = 'Work log'
const MARKER = '❓ **Your turn:**'
const status = atom({ plugin: 'worklog', key: 'status' } as const, '')
const question = atom({ plugin: 'worklog', key: 'question' } as const, '')
const detail = atom({ plugin: 'worklog', key: 'detail' } as const, '')
const todos = atom({ plugin: 'worklog', key: 'todos' } as const, [] as string[])
const custom = atom({ plugin: 'worklog', key: 'custom' } as const, { title: '', lines: [] as string[] })
const log = atom({ plugin: 'worklog', key: 'log' } as const, [] as LogEntry[])
const prompts = new Map<string, string>()   // turn id -> what was asked

const plain = (s: string) => s.replace(/\*\*|`/g, '').replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
const oneLine = (s: string, n: number) => {
  const t = plain(s).replace(/\s+/g, ' ').trim()
  return t.length > n ? t.slice(0, n - 1) + '…' : t
}
// First sentence of a reply: what was done
const firstSentence = (s: string) => oneLine(s.split(MARKER)[0].split(/(?<=[.!?])\s|\n\n/)[0] ?? '', 160)
const hhmm = () => new Date().toTimeString().slice(0, 5)

// Topic of a turn in a few words, by a small model; undefined if it doesn't answer
async function topicOf($: EngineInterface, asked: string, reply: string) {
  const r = await $.model.complete({
    model: 'haiku', maxTokens: 30,
    system: 'You label conversation turns for a work log. Answer with the topic only: at most 8 words, no ' +
      'full sentence, no quotes, no trailing period, in the language of the request.',
    prompt: `Request:\n${oneLine(asked, 600)}\n\nReply:\n${oneLine(reply.split(MARKER)[0], 800)}`,
  })
  return r.isAnswered ? oneLine(r.text.split('\n')[0].replace(/^["'„]|["'“]$|\.$/g, ''), 70) : undefined
}

// The "Your turn" actions of a reply spelled out, so they can be done without scrolling up; undefined if no answer
async function detailOf($: EngineInterface, asked: string, reply: string, block: string) {
  const r = await $.model.complete({
    model: 'haiku', maxTokens: 600,
    system: 'You turn the "Your turn" actions at the end of an assistant reply into a self-contained to-do for the ' +
      'user, who will not reread the chat. For each action: one line "• <action>", then 1–3 lines starting with ' +
      'two spaces: exactly what to do, where (which session, tab, app, site, file, command) and why, with any ' +
      'names, commands, paths, URLs, dates or values from the reply. Use only facts from the request and reply. ' +
      'Plain text, no markdown, no intro, same language as the block.',
    prompt: `Request:\n${oneLine(asked, 1500)}\n\nReply:\n${reply.slice(0, 6000)}\n\nYour-turn block:\n${block}`,
  })
  return r.isAnswered ? plain(r.text).trim() : undefined
}

// The Status: line of the nearest CLAUDE.md, from the working directory up
async function readStatus($: EngineInterface, cwd: string) {
  let dir = cwd
  for (let i = 0; i < 6 && dir.length > 1; i++) {
    try {
      const text: string = await $.fs.read(`${dir}/CLAUDE.md`)
      const m = text.match(/^Status:\s*(.+)$/m)
      return m ? plain(m[1]) : ''
    } catch { dir = dir.replace(/\/[^/]+$/, '') || '/' }
  }
  return ''
}

type Conf = { todo_file?: string; name?: string; depth?: number; panes?: Record<string, { title?: string; file?: string; match?: string }> }

// The session's project: the workspace is the nearest folder up with a cockpit.json, the project its path below
// it cut to "depth" levels (the root: cockpit.json "name")
async function project($: EngineInterface, cwd: string) {
  let ws = cwd
  let conf: Conf | undefined
  for (let i = 0; i < 8 && ws.length > 1; i++) {
    try { conf = JSON.parse(await $.fs.read(`${ws}/cockpit.json`)); break } catch { ws = ws.replace(/\/[^/]+$/, '') || '/' }
  }
  if (!conf) return undefined
  const rel = cwd === ws ? (conf.name || ws.split('/').pop() || '')
    : cwd.slice(ws.length + 1).split('/').slice(0, conf.depth ?? 2).join('/')
  return { ws, conf, rel }
}

// The project's own pane section instead of the log (cockpit.json "panes"), or none
async function readCustom($: EngineInterface, cwd: string) {
  const p = await project($, cwd)
  const pane = p?.conf.panes?.[p.rel]
  if (!p || !pane?.file) return { title: '', lines: [] as string[] }
  let text = ''
  try { text = await $.fs.read(`${p.ws}/${pane.file}`) } catch { return { title: pane.title || 'Log', lines: ['(file not found)'] } }
  const pick = (re: RegExp) => text.split('\n').filter(l => re.test(l)).map(l => oneLine(l.replace(/^\s*(#+|[-*])\s*/, ''), 200))
  let lines: string[]
  try { lines = pane.match ? pick(new RegExp(pane.match)) : pick(/^## /) } catch { lines = ['(bad "match" regex)'] }
  if (!pane.match && !lines.length) lines = pick(/^[-*] /)
  return { title: pane.title || pane.file.split('/').pop() || '', lines }
}

// Open to-dos of the session's project: the open "- [ ]" lines under "## <project>" (a " — suffix" on the heading
// is fine) in the to-do file
async function readTodos($: EngineInterface, cwd: string) {
  const p = await project($, cwd)
  if (!p?.conf.todo_file) return []
  const { ws, conf, rel } = p
  let text = ''
  try { text = await $.fs.read(`${ws}/${conf.todo_file}`) } catch { return [] }
  // An item: its line without the date, plus its indented detail lines
  const items: string[] = []
  let inside = false, open = false
  for (const line of text.split('\n')) {
    if (line.startsWith('## ')) { inside = line.slice(3).split(' — ')[0].trim() === rel; open = false }
    else if (inside && line.startsWith('- [ ]')) {
      items.push(oneLine(line.slice(5).replace(/\s*\(added \d{4}-\d{2}-\d{2}\)/, '').replace(/^[\s—]+|[\s—]+$/g, ''), 400))
      open = true
    } else if (inside && open && /^\s+\S/.test(line)) items[items.length - 1] += '\n  ' + oneLine(line.replace(/^\s*[-*]\s*/, ''), 300)
    else open = false
  }
  return items
}

const refresh = ($: EngineInterface, cwd: string) => {
  void readStatus($, cwd).then(s => update($, status, () => s))
  void readTodos($, cwd).then(t => update($, todos, () => t))
  void readCustom($, cwd).then(c => update($, custom, () => c))
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'worklog', description: 'Show the work log pane (status, open questions, log)' })
    await update($, status, () => '')
    refresh($, e.cwd)
    void $.ui.open({ id: PANE, title: TITLE })
    return next(e)
  })

  on('command.run', { command: 'worklog' }, async $ => {
    await $.ui.open({ id: PANE, title: TITLE })
    return { text: 'Work log pane opened.' }
  })

  on('turn.start', async ($, e, next) => {
    if (e.agentId === undefined && e.text) prompts.set(e.turnId, e.text)
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    if (e.agentId !== undefined) return done
    const text = done.text ?? ''
    const i = text.indexOf(MARKER)
    const block = i >= 0 ? plain(text.slice(i + MARKER.length)).trim() : ''
    await update($, question, () => block)
    await update($, detail, () => '')
    const asked = prompts.get(e.turnId) ?? ''
    prompts.delete(e.turnId)
    if (block) void detailOf($, asked, text, block).then(d => d && read($, question).then(q =>
      q === block ? update($, detail, () => d) : undefined)).catch(() => {})
    const did = e.reason === 'answer' ? firstSentence(text) : e.reason
    if (asked || did) {
      const time = hhmm()
      await update($, log, l => [...l, { time, asked: oneLine(asked, 100), did }].slice(-100))
      void topicOf($, asked, text).then(topic => topic && update($, log, l =>
        l.map(en => en.time === time && en.did === did && !en.topic ? { ...en, topic } : en))).catch(() => {})
    }
    refresh($, $.session.cwd())
    return done
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const st = await read($, status)
    const q = (await read($, detail)) || (await read($, question))
    const td = await read($, todos)
    const entries = await read($, log)
    const cu = await read($, custom)
    const qLines = q ? q.split('\n').filter(l => l.trim()) : []
    const tLines = td.flatMap(t => t.split('\n'))
    // Rows the wrapped texts take; the log gets what's left
    const width = Math.max(10, (e.viewport?.columns ?? 40) - 2)
    const rows = (ls: string[]) => ls.reduce((n, l) => n + Math.max(1, Math.ceil(l.length / width)), 0)
    const used = 8 + rows(qLines.length ? qLines : ['-']) + rows(tLines.length ? tLines.map(l => '• ' + l) : ['-']) + rows([st || '—'])
    const room = Math.max(1, (e.viewport?.rows ?? 30) - used)
    return (
      <Box flexDirection="column">
        <Text bold color="red">❓ Your turn</Text>
        {qLines.length === 0 ? <Text dimColor>nothing open</Text>
          : qLines.map(l => l.startsWith('  ') ? <Text wrap="wrap">{l}</Text> : <Text wrap="wrap" bold>{l}</Text>)}
        <Text> </Text>
        <Text bold color="magenta">☐ To-dos</Text>
        {td.length === 0 ? <Text dimColor>none</Text>
          : tLines.map(l => l.startsWith('  ') ? <Text wrap="wrap">{l}</Text> : <Text wrap="wrap">• {l}</Text>)}
        <Text> </Text>
        <Text bold color="cyan">Status</Text>
        <Text wrap="wrap">{st || '—'}</Text>
        <Text> </Text>
        <Text bold color="yellow">{cu.title || 'Log'}</Text>
        {cu.title ? (cu.lines.length === 0 ? [<Text dimColor>empty</Text>]
          : cu.lines.slice(0, room).map(l => <Text wrap="truncate-end">• {l}</Text>))
          : entries.length === 0 ? [<Text dimColor>nothing yet</Text>]
          : entries.slice(-room).map(en => (
            <Text wrap="truncate-end"><Text dimColor>{en.time}</Text> {en.topic || en.asked || '(continued)'}</Text>
          ))}
      </Box>
    )
  })
}
