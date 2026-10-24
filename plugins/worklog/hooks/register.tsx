import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { LogEntry } from '../types'

// Side pane: the open "❓ Your turn" block of the last reply, the project's open to-dos (cockpit.json "todo_file",
// section "## <project>"), the project's Status: line, and one log line per turn: its topic in a few words
// (summarised by a small model; until it answers, or if it fails, the start of the prompt)
const PANE = 'worklog'
const TITLE = 'Work log'
const MARKER = '❓ **Your turn:**'
const status = atom({ plugin: 'worklog', key: 'status' } as const, '')
const question = atom({ plugin: 'worklog', key: 'question' } as const, '')
const todos = atom({ plugin: 'worklog', key: 'todos' } as const, [] as string[])
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

// Open to-dos of the session's project: the workspace is the nearest folder up with a cockpit.json, the project
// its path below it cut to "depth" levels (the root: cockpit.json "name"), its items the open "- [ ]" lines under
// "## <project>" (a " — suffix" on the heading is fine) in the to-do file
async function readTodos($: EngineInterface, cwd: string) {
  let ws = cwd
  let conf: { todo_file?: string; name?: string; depth?: number } | undefined
  for (let i = 0; i < 8 && ws.length > 1; i++) {
    try { conf = JSON.parse(await $.fs.read(`${ws}/cockpit.json`)); break } catch { ws = ws.replace(/\/[^/]+$/, '') || '/' }
  }
  if (!conf?.todo_file) return []
  const rel = cwd === ws ? (conf.name || ws.split('/').pop() || '')
    : cwd.slice(ws.length + 1).split('/').slice(0, conf.depth ?? 2).join('/')
  let text = ''
  try { text = await $.fs.read(`${ws}/${conf.todo_file}`) } catch { return [] }
  const items: string[] = []
  let inside = false
  for (const line of text.split('\n')) {
    if (line.startsWith('## ')) inside = line.slice(3).split(' — ')[0].trim() === rel
    else if (inside && line.startsWith('- [ ]'))
      items.push(oneLine(line.slice(5).replace(/\s*\(added \d{4}-\d{2}-\d{2}\)/, '').replace(/\s*→.*$/, '').replace(/^[\s—]+|[\s—]+$/g, ''), 200))
  }
  return items
}

const refresh = ($: EngineInterface, cwd: string) => {
  void readStatus($, cwd).then(s => update($, status, () => s))
  void readTodos($, cwd).then(t => update($, todos, () => t))
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
    await update($, question, () => (i >= 0 ? plain(text.slice(i + MARKER.length)).trim() : ''))
    const asked = prompts.get(e.turnId) ?? ''
    prompts.delete(e.turnId)
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
    const q = await read($, question)
    const td = await read($, todos)
    const entries = await read($, log)
    const qLines = q ? q.split('\n').filter(l => l.trim()) : []
    const room = Math.max(1, (e.viewport?.rows ?? 30) - 11 - qLines.length - td.length - 2)
    return (
      <Box flexDirection="column">
        <Text bold color="red">❓ Your turn</Text>
        {qLines.length === 0 ? <Text dimColor>nothing open</Text>
          : qLines.map(l => <Text wrap="wrap">{l}</Text>)}
        <Text> </Text>
        <Text bold color="magenta">☐ To-dos</Text>
        {td.length === 0 ? <Text dimColor>none</Text>
          : td.map(t => <Text wrap="wrap">• {t}</Text>)}
        <Text> </Text>
        <Text bold color="cyan">Status</Text>
        <Text wrap="wrap">{st || '—'}</Text>
        <Text> </Text>
        <Text bold color="yellow">Log</Text>
        {entries.length === 0 && <Text dimColor>nothing yet</Text>}
        {entries.slice(-room).map(en => (
          <Text wrap="truncate-end"><Text dimColor>{en.time}</Text> {en.topic || en.asked || '(continued)'}</Text>
        ))}
      </Box>
    )
  })
}
