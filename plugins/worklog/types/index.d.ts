export type LogEntry = { time: string; asked: string; did: string }

declare module 'claude-code' {
  interface PluginState {
    worklog: { status: string; question: string; log: LogEntry[] }
  }
}
