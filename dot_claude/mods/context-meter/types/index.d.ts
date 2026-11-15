export type Segment = { name: string; color: string; tokens: number; kind: 'used' | 'free' | 'buffer' }
export type Limit = { kind: string; percentUsed: number; resetsAt?: string }
export type Snapshot = {
  segments: Segment[]
  usedTokens: number
  maxTokens: number
  percent: number
  limits: Limit[]
}

declare module 'claude-code' {
  interface PluginState {
    'context-meter': { snapshot: Snapshot | null; isKeyShown: boolean; cacheAt: number | null; isRunning: boolean; tick: number }
  }
}
