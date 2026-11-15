import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import { LABELS, cellsOf, compact, levelColor, snapshotOf, untilReset } from './meter'

const snapshot = atom({ plugin: 'context-meter', key: 'snapshot' } as const, null)
const isKeyShown = atom({ plugin: 'context-meter', key: 'isKeyShown' } as const, false)
const cacheAt = atom({ plugin: 'context-meter', key: 'cacheAt' } as const, null)
const isRunning = atom({ plugin: 'context-meter', key: 'isRunning' } as const, false)
const tick = atom({ plugin: 'context-meter', key: 'tick' } as const, 0)
const toggleKey = ($: EngineInterface) => update($, isKeyShown, v => !v)

async function measure($: EngineInterface) {
  const usage = await $.session.usage({ breakdown: 'summary' })
  await update($, snapshot, () => snapshotOf(usage))
}

export const register: Register = (on, options) => {
  const ttlMs = (Number(options?.ttlMinutes) || 5) * 60_000
  let warned = false
  const deferred = new Map<string, boolean>()

  // Artifact's description is ~6k tokens; keep it behind ToolSearch until it's needed.
  const DEFER = new Set(['Artifact'])

  on('tool.describe', async ($, e, next) => {
    const engine = await next(e)
    const result = DEFER.has(e.tool) ? { ...engine, isDeferred: true as const } : engine
    deferred.set(e.tool, result.isDeferred === true || (result.isDeferred === undefined && e.isDeferred === true))
    return result
  })

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await $.command.register({ name: 'ctx', description: 'Show or hide the context meter key' })
    await $.command.register({ name: 'ctx-audit', description: 'Count every context category, skill, MCP tool and memory file; save the report' })
    await update($, isKeyShown, () => false)
    await measure($)
    $.clock.every(1000, async () => {
      const t = await $.clock.now()
      await update($, tick, () => t)
      const at = await read($, cacheAt)
      const left = at === null ? 0 : ttlMs - (t - at)
      if (!warned && !(await read($, isRunning)) && left > 0 && left <= 60_000) {
        warned = true
        $.ui.toast('Prompt cache expires in under 1 minute')
      }
    })
    return result
  })

  on('command.run', { command: 'ctx' }, async $ => {
    await toggleKey($)
    return { text: (await read($, isKeyShown)) ? 'Context key shown until your next prompt.' : 'Context key hidden.' }
  })

  on('command.run', { command: 'ctx-audit' }, async $ => {
    const usage = await $.session.usage({ breakdown: 'full' })
    const b = usage.context.breakdown
    if (!b) return { text: 'No breakdown available yet; send a prompt first.' }
    const path = `${$.plugin.root}/audit/last.json`
    const tools = (await $.tool.list())
      .map(t => ({ name: t.name, mcp: t.mcp, deferred: deferred.get(t.name), descTokens: Math.round(t.description.length / 4) }))
      .sort((x, y) => y.descTokens - x.descTokens)
    await $.fs.write(path, JSON.stringify({ ...b, tools }, null, 2))
    const rows = b.categories
      .filter(c => c.tokens > 0)
      .map(c => `${c.name}: ${compact(c.tokens)}${c.isDeferred ? ' (deferred)' : ''}`)
    return { text: `${rows.join(' · ')}\nSaved to ${path}` }
  })

  on('turn.start', async ($, e, next) => {
    await update($, isRunning, () => true)
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const t = await $.clock.now()
    warned = false
    await update($, cacheAt, () => t)
    await update($, isRunning, () => false)
    return next(e)
  })

  on('prompt.submit', async ($, e, next) => {
    await update($, isKeyShown, () => false)
    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    await measure($)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const snap = await read($, snapshot)
    if (e.props.hasSurvey || snap === null || snap.segments.length === 0) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const isShown = await read($, isKeyShown)
    const now = await $.clock.now()
    const at = await read($, cacheAt)
    const running = await read($, isRunning)
    await read($, tick)
    const left = at === null ? null : ttlMs - (now - at)
    const mmss = (ms: number) => {
      const x = Math.max(0, Math.ceil(ms / 1000))
      const p = (n: number) => String(n).padStart(2, '0')
      // Minutes only up to 90 min, so a 1h TTL reads 60:00 -> 59:59; hours appear beyond that.
      return x > 5400 ? `${p(Math.floor(x / 3600))}:${p(Math.floor((x % 3600) / 60))}:${p(x % 60)}` : `${p(Math.floor(x / 60))}:${p(x % 60)}`
    }
    const barWidth = Math.max(10, Math.min(40, e.props.bodyColumns - 50))
    const cells = cellsOf(snap.segments, barWidth)
    const used = snap.segments.filter(s => s.kind === 'used')

    return (
      <Box flexDirection="column">
        <Box>
          <Button key="toggle" plain dimColor hotkey="k" label={isShown ? '▾' : '▸'} onPress={() => toggleKey($)} />
          <Text> </Text>
          <Text>
            {cells.map(c => <Text color={c.color} dimColor={c.isDim}>{c.char}</Text>)}
            <Text bold color={levelColor(snap.percent)}>{` ${Math.round(snap.percent)}%`}</Text>
            <Text dimColor>{` ${compact(snap.usedTokens)}/${compact(snap.maxTokens)}`}</Text>
            {snap.limits.map(l => (
              <Text>
                <Text dimColor>{`  ${LABELS[l.kind] ?? l.kind} `}</Text>
                <Text bold color={levelColor(l.percentUsed)}>{`${Math.round(l.percentUsed)}%`}</Text>
                <Text dimColor>{l.resetsAt ? ` ↻${untilReset(l.resetsAt, now)}` : ''}</Text>
              </Text>
            ))}
            {running ? <Text dimColor>{'  CACHE ↻…'}</Text> : left === null ? null : left <= 0 ? (
              <Text>{'  '}<Text bold color="black" backgroundColor="red">{' CACHE EXPIRED '}</Text></Text>
            ) : (
              <Text>{'  '}<Text bold color="black" backgroundColor={left >= 600_000 ? 'green' : left >= 300_000 ? 'yellow' : 'red'}>{` CACHE ${mmss(left)} `}</Text></Text>
            )}
          </Text>
        </Box>
        {isShown ? (<Box>
          <Text wrap="truncate-end">
            {used.map(s => (
              <Text>
                <Text color={s.color}>■</Text>
                <Text dimColor>{` ${s.name} ${compact(s.tokens)}  `}</Text>
              </Text>
            ))}
          </Text>
        </Box>) : null}
      </Box>
    )
  })
}
