export type LogEntry = { time: string; asked: string; did: string; topic?: string }
export type PanePart = { title: string; lines: string[] }

declare module 'claude-code' {
  interface PluginState {
    worklog: { status: string; question: string; detail: string; todos: string[]; custom: PanePart[]; log: LogEntry[] }
  }
}
