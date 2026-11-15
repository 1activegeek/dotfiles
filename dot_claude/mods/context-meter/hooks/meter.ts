import type { SessionUsage } from 'claude-code'

import type { Segment, Snapshot } from '../types'

export type Cell = { color: string; char: string; isDim: boolean }

const CHARS = { used: '█', free: '·', buffer: '░' } as const

export const LABELS: Record<string, string> = { five_hour: '5h', seven_day: '7d', spend_limit: '$' }

export function snapshotOf(usage: SessionUsage): Snapshot {
  const b = usage.context.breakdown
  const segments: Segment[] = (b?.categories ?? [])
    .filter(c => c.kind !== 'deferred' && c.tokens > 0)
    .map(c => ({ name: c.name, color: c.color, tokens: c.tokens, kind: c.kind as Segment['kind'] }))
    .sort((x, y) => order(x.kind) - order(y.kind))

  return {
    segments,
    usedTokens: b?.totalTokens ?? usage.context.tokens ?? 0,
    maxTokens: b?.rawMaxTokens ?? usage.context.window,
    percent: b?.percentage ?? usage.context.percent ?? 0,
    limits: usage.rateLimits.map(r => ({ kind: r.kind, percentUsed: r.percentUsed, resetsAt: r.resetsAt })),
  }
}

function order(kind: Segment['kind']): number {
  return kind === 'used' ? 0 : kind === 'free' ? 1 : 2
}

// Largest-remainder split of `width` cells across the segments, each visible segment getting at least one.
export function cellsOf(segments: Segment[], width: number): Cell[] {
  const total = segments.reduce((sum, s) => sum + s.tokens, 0)
  if (total === 0 || width <= 0) return []

  const shares = segments.map(s => (s.tokens / total) * width)
  const counts = shares.map(x => Math.max(1, Math.floor(x)))
  const byRemainder = shares.map((x, i) => ({ rest: x - Math.floor(x), i })).sort((p, q) => q.rest - p.rest)
  let extra = width - counts.reduce((sum, n) => sum + n, 0)
  for (const { i } of byRemainder) {
    if (extra <= 0) break
    counts[i] = (counts[i] ?? 0) + 1
    extra--
  }
  for (let i = counts.length - 1; extra < 0 && i >= 0; i--) {
    const take = Math.min((counts[i] ?? 1) - 1, -extra)
    counts[i] = (counts[i] ?? 1) - take
    extra += take
  }

  return segments.flatMap((s, i) =>
    Array.from({ length: counts[i] ?? 0 }, () => ({ color: s.color, char: CHARS[s.kind], isDim: s.kind !== 'used' })),
  )
}

export function levelColor(percent: number): string {
  return percent >= 80 ? 'red' : percent >= 50 ? 'yellow' : 'green'
}

export function untilReset(resetsAt: string | undefined, now: number): string {
  if (!resetsAt) return ''
  const mins = Math.max(0, Math.round((Date.parse(resetsAt) - now) / 60000))
  if (mins >= 1440) return `${Math.floor(mins / 1440)}d${Math.floor((mins % 1440) / 60)}h`
  if (mins >= 60) return `${Math.floor(mins / 60)}h${mins % 60}m`
  return `${mins}m`
}

export function compact(tokens: number): string {
  return tokens >= 1e6 ? `${(tokens / 1e6).toFixed(1)}M` : tokens >= 1e3 ? `${Math.round(tokens / 1e3)}k` : `${tokens}`
}
