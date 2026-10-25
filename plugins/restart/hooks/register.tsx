import type { Register } from 'claude-code'

// /restart: ends this claude process and resumes the conversation in the same tab, e.g. to load changed mods,
// hooks or settings. bin/claude-restart does it, the claude() wrapper in shell/bashrc.sh starts it again.
export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'restart', description: 'Restart this session in the same tab (resumes it)' })
    return next(e)
  })

  on('command.run', { command: 'restart' }, async $ => {
    const r = await $.process.run(['claude-restart', await $.session.id()])
    return { text: r.exitCode === 0 ? 'Restarting…' : `Restart failed: ${r.stderr.trim() || r.stdout.trim()}` }
  })
}
