import { expect, mock, test } from 'claude-code/testing'

import { cellsOf, untilReset } from './meter'

test('cells fill the width and keep every segment visible', async () => {
  const cells = cellsOf(
    [
      { name: 'System prompt', color: 'promptBorder', tokens: 3000, kind: 'used' },
      { name: 'Messages', color: 'permission', tokens: 100, kind: 'used' },
      { name: 'Free space', color: 'inactive', tokens: 96900, kind: 'free' },
    ],
    20,
  )
  expect(cells).toHaveLength(20)
  expect(cells.filter(c => c.color === 'permission')).toHaveLength(1)
})

test('reset countdown', async () => {
  expect(untilReset(new Date(130 * 60000).toISOString(), 0)).toBe('2h10m')
  expect(untilReset(new Date(3 * 1440 * 60000).toISOString(), 0)).toBe('3d0h')
})

const USAGE = {
  startedAt: 0,
  context: {
    tokens: 84000,
    window: 200000,
    percent: 42,
    breakdown: {
      categories: [
        { name: 'System prompt', color: 'promptBorder', tokens: 20000, kind: 'used', isDeferred: false },
        { name: 'Messages', color: 'permission', tokens: 64000, kind: 'used', isDeferred: false },
        { name: 'MCP tools (deferred)', color: 'inactive', tokens: 9000, kind: 'deferred', isDeferred: true },
        { name: 'Free space', color: 'inactive', tokens: 116000, kind: 'free', isDeferred: false },
      ],
      totalTokens: 84000,
      rawMaxTokens: 200000,
      percentage: 42,
    },
  },
  rateLimits: [
    { kind: 'five_hour', percentUsed: 23.5 },
    { kind: 'seven_day', percentUsed: 81 },
  ],
}

for (const surface of ['terminal', 'desktop'] as const) {
  test(`draws bar and limits on ${surface}`, async ($, on) => {
    on('session.usage', () => ({ value: USAGE }) as never)
    mock.clock(on)
    on('prompt.submit', (_, e) => ({ text: e.text }) as never)
    on('session.measure', (_, e) => ({ changed: e.changed }))
    await $.session.measure({ context: USAGE.context, rateLimits: USAGE.rateLimits, changed: ['context'] } as never)
    const ui = await $.ui.mount({
      plugin: 'context-meter',
      surface,
      component: 'AbovePrompt',
      props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 120 },
    } as never)
    const collapsed = JSON.stringify(await ui.drawn())
    expect(collapsed).toContain('42%')
    expect(collapsed).toContain('5h')
    expect(collapsed).toContain('7d')
    expect(collapsed).not.toContain('Messages')

    await ui.press({ key: 'toggle' })
    const expanded = JSON.stringify(await ui.drawn())
    expect(expanded).toContain('Messages')
    expect(expanded).not.toContain('deferred')

    await $.prompt.submit({ text: 'next turn' } as never)
    expect(JSON.stringify(await ui.drawn())).not.toContain('Messages')
  })
}

test('Artifact is deferred behind ToolSearch, other tools are untouched', async ($, on) => {
  on('tool.describe', (_, e) => ({ description: e.description }))
  const provider = { plugin: 'engine', tier: 'core' } as never
  const artifact = await $.tool.describe({ tool: 'Artifact', description: 'publish pages', provider } as never)
  expect(artifact.isDeferred).toBe(true)
  const bash = await $.tool.describe({ tool: 'Bash', description: 'run commands', provider } as never)
  expect(bash.isDeferred).toBeUndefined()
})
