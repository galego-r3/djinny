export type LogEntry = { time: string; asked: string; did: string; topic?: string }

declare module 'claude-code' {
  interface PluginState {
    worklog: { status: string; question: string; todos: string[]; log: LogEntry[] }
  }
}
