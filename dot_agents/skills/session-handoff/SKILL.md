---
name: session-handoff
description: Use when the user says "session handoff", "wrap up session", "hand off", "handoff summary", or wants a structured end-of-session summary before clearing context. Always writes decisions and learnings to agentOS memory first, then produces a chat handoff covering shipped changes, key files, running state, verification steps, deferrals, and open questions so a fresh agent can continue seamlessly.
---

# Session Handoff

Produce a repeatable end-of-session summary so the user can `/clear` and start a fresh agent without losing continuity. The next agent should be able to pick up by reading this summary alone.

This is a **context-handoff artifact**, not a status report. The audience is a future instance of you, not a stakeholder.

## When to invoke

User says: "session handoff", "wrap up session", "hand off", "handoff summary", "let's wrap up", "summarize before I clear", or any near-equivalent. Also invoke proactively if the user says they're about to `/clear` without having run it yet.

## Step 0 — Write to memory first (always, no confirmation needed)

Before producing the handoff output, extract and persist what's worth keeping long-term.

**Review the full conversation** for:

1. **Decisions** — choices that change how the system or life works going forward. Write each to `agentOS/memory/decisions/YYYY-MM.md`:
   ```markdown
   ## YYYY-MM-DD — {Short title}
   
   {What was decided}
   
   **Why:** {reason}
   **Impact:** {effect going forward}
   **Tags:** #{tag}
   
   ---
   ```

2. **Learnings** — synthesized insights or non-obvious patterns. Write each to `agentOS/memory/learnings/YYYY-MM.md`:
   ```markdown
   ## YYYY-MM-DD — {Short title}
   
   {The insight}
   
   #{tag1} #{tag2}
   
   ---
   ```

3. **Session summary** — always write one to `agentOS/memory/sessions/YYYY-MM-DD-{slug}.md`:
   ```markdown
   ---
   date: YYYY-MM-DD
   type: session
   slug: {slug}
   tags: []
   ---
   
   # Session: {Title}
   
   ## What happened
   {2-4 sentences}
   
   ## Decisions made
   {Bullet list, or "None"}
   
   ## Learnings
   {Bullet list, or "None"}
   
   ## Next actions
   {What to pick up next, or "None"}
   ```

If the memory monthly file doesn't exist yet, create it with a `# Memory — {Type} — YYYY-MM` header first.

Skip any category that has nothing real to record — don't manufacture entries.

Tell the user in one line what was written: "Memory written: 1 decision, 2 learnings, session summary."

**Then proceed immediately to the handoff output — no further prompting.**

## How to produce the handoff

1. **Review the full conversation**, not just the last few turns. Handoffs miss things when they only summarize recent context.
2. **Pull state from these sources (in order):**
   - Plan files referenced this session.
   - TodoWrite state — any in-progress or pending tasks.
   - Background processes you started with `run_in_background` — shell IDs are load-bearing for the next agent.
   - Files created or modified this session — you know what you touched; don't grep to re-discover.
   - Memory files written in Step 0 — list their paths.
   - Unresolved questions — things you asked the user that never got a clear answer, or things the user asked that got deflected.
3. **Do NOT audit the filesystem.** This is synthesis of what happened in THIS session. No `git log`, no broad `Glob` sweeps. If you didn't touch it this session, it doesn't belong here.
4. **Produce the output in chat.**

## Output template — use exactly this structure, every time

```
# Session Handoff — <one-line title of what this session was about>

## Where it started
<2-3 sentences: what the user asked for, key framing or constraints that emerged>

## Decisions locked + what shipped
- <decision or change> — <why, and where it lives (absolute path if a file)>
- ...

## Key files for next session
- `<absolute path>` — <why the next agent should read this first>
- Plan file: `<path>` (if a plan drove the session)
- Memory files touched: `<paths>` (if any)

## Running state
- Background processes: <shell IDs + what they are + how to kill> — or "none"
- Dev servers / ports: <url + port> — or "none"
- Open worktrees / branches: <paths> — or "none"

## Verification — how to confirm things still work
- `<command>` — <expected outcome>
- ...

## Deferred + open questions
- Deferred: <item> — <why pushed to later>
- Open: <question needing the user's input> — <context>

## Pick up here
<1-2 sentences: the single most likely next action for a fresh agent>
```

## Hard rules

1. **Memory first, always.** Step 0 is not optional. Always write to agentOS memory before producing the handoff output.
2. **Handoff output is chat-only.** The handoff summary itself goes to chat, not to a file (memory was already written in Step 0).
3. **Never invent state.** If a section has nothing to report, write "none" — do not omit the section. Structure stability is the whole point.
4. **Absolute paths always.** The next agent may have a different working directory.
5. **If a plan file drove the session, name it first** in "Key files" so the next agent reads it before anything else.
6. **No emojis, no hype, no "great job" summaries.** Terse and concrete — paths, commands, shell IDs, decisions. Match the tone of a seasoned engineer handing off at end-of-shift.
7. **Background process IDs are critical.** If you started any `run_in_background` shells, their IDs must appear in "Running state" with the kill command — the next agent cannot find them otherwise.

## Anti-patterns — do not do these

- Skipping Step 0. Memory always gets written first.
- Asking "should I write to memory?" — the answer is always yes.
- Summarizing the last 3 turns and calling it a handoff.
- Listing files by relative path.
- Skipping the "Running state" section because "nothing is running" — write "none" instead.
- Adding a "what went well / what went poorly" retrospective. This isn't a retro.
- Recommending next steps beyond the single "Pick up here" line. The next agent decides; you just hand off.
