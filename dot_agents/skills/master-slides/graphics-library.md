# Graphics Library — master-slides

Reference catalog for visuals in master-slides decks. Primary: the curated cards that ship with this skill (use these first). Secondary: the full cinematic modules pack.

**Source files:** every bento card referenced below ships in [`./bento-pack/`](./bento-pack/) — 14 `explainer-bento-*.html` files, each containing a 6-card grid. Open the matching file, copy the card's HTML + CSS inline into your deck.

---

## Curated cards (PRIMARY REFERENCES)

These are first-class. When a concept fits one of these, use it. The animations are proven, paper-style, and work at scale across a deck.

### Feature grid — clean UI motion
Source: `explainer-bento-feature-grid.html`

| Card | Title | Visual | Use when concept is… |
|---|---|---|---|
| 02 | Parallel sessions, one operator | Sidebar list + main panel with LIVE badge + typing cycle | multi-agent teams, parallel work, specialization |
| 04 | Every edit, same rails | 4-node pipeline (EDIT→FORMAT/LINT→COMMIT) with traveling sparks | skills, workflows, reusable pipelines, CI-style automation |
| 05 | Plugs into everything | Hub + 6 spokes to icon nodes, pulsing lines | MCP, integrations, connectors, "works with everything" |
| 06 | Talk, don't type | REC dot + animated waveform bars + caption | voice interaction, input methods, dictation |

### Concept grid — abstract principles
Source: `explainer-bento-concept-grid.html`

| Card | Title | Visual | Use when concept is… |
|---|---|---|---|
| 03 | Not available on this surface | Dimmed/blocked element with limit label | platform limits, gated features, permissions |
| 05 | Every window has a ceiling | Semicircle gauge with needle sweeping toward red | context windows, rate limits, constraints |
| 06 | Same prompt, different answers | Split: solid line vs fan-out lines | stochastic vs deterministic, drift, variability |

### Terminal grid — CLI aesthetic
Source: `explainer-bento-terminal-grid.html`

| Card | Title | Visual | Use when concept is… |
|---|---|---|---|
| 02 | Log stream / typing | Terminal with streaming log output | agent activity, execution traces, receipts |
| 04 | Run progress | Terminal with progress bars / diff | build progress, test runs, task completion |

### Data grid — charts with movement
Source: `explainer-bento-data-grid.html`

| Card | Title | Visual | Use when concept is… |
|---|---|---|---|
| 01 | Up and to the right | Sparkline climbing with data dots | growth metrics, output over time, trends |
| 02 | Hours back every day | Bar chart, last bar highlighted | time saved, month-over-month progress |
| 03 | Runs without you | Donut 82% orange fill with AUTO label | autonomy %, unassisted task rate |
| 06 | Data flows through one brain | Hub + 6 nodes with pulsing edges | dashboard/command center, data routing |

### Isometric grid — 3D abstract
Source: `explainer-bento-isometric-grid.html`

| Card | Title | Visual | Use when concept is… |
|---|---|---|---|
| 01 | Stacked tower | 3 gray cubes stacked + 1 orange cube bouncing above | composition, layers, three parts of X |
| 03 | Terrain wave | Field of cubes rising/falling in wave | scale, distribution, adoption spread |
| 04 | Parallel planes | Stacked translucent planes with depth | layered systems, abstraction levels |

### Isometric datacenter
Source: `explainer-bento-isometric-datacenter.html`

| Card | Title | Visual | Use when concept is… |
|---|---|---|---|
| 01 | Server rack LEDs | Iso rack with blinking LEDs | infrastructure, agents running, compute |
| 03 | Circuit signals | Signal packets traveling paths | request flow, message passing |
| 04 | Radar sweep | Rotating radar/sweep beam | monitoring, scanning, observability |

### Isometric city
Source: `explainer-bento-isometric-city.html`

| Card | Title | Visual | Use when concept is… |
|---|---|---|---|
| 01 | City block windows | Tall building with flickering windows | scale of systems, distributed work |

### Isometric machine
Source: `explainer-bento-isometric-machine.html`

| Card | Title | Visual | Use when concept is… |
|---|---|---|---|
| 06 | Orbiting rings | 3 concentric rings with satellites, orange core | agent loop, cyclic patterns, the universal loop |

### Isometric v2
Source: `explainer-bento-isometric-grid-v2.html`

| Card | Title | Visual | Use when concept is… |
|---|---|---|---|
| 04 | Pond ripple | Concentric expanding ripples | propagation, effect spreading, emergence |
| 05 | Tumbling numbered cube | Single cube rotating showing different faces | state change, iteration, self-modification |

---

## Concept → card mapping (quick lookup)

When a brief mentions these ideas, reach for these cards first:

| Concept | Primary card | Fallback |
|---|---|---|
| Three parts of an agent | iso-grid / card-01 (stacked tower) | 3 floating iso cubes custom |
| The agent loop | iso-machine / card-06 (orbiting rings) | 4 cubes in cycle custom |
| Multi-agent team | feature-grid / card-02 (parallel sessions) | Agent icon lineup (see agent-icons.md) |
| Skills / pipelines | feature-grid / card-04 | Stacked file cards |
| MCP / integrations | feature-grid / card-05 (hub-spoke) | Custom hub with tool pills |
| Voice input | feature-grid / card-06 (waveform) | — |
| Platform limits | concept-grid / card-03 | — |
| Context ceiling | concept-grid / card-05 (gauge) | Iceberg SVG |
| Stochastic / drift | concept-grid / card-06 (fan-out) | — |
| CLI / execution logs | terminal-grid / card-02 or 04 | — |
| Growth / output trend | data-grid / card-01 (sparkline) | data-grid / card-02 (bars) |
| Time saved | data-grid / card-02 (bars) | — |
| Autonomy % | data-grid / card-03 (donut) | — |
| Dashboard / command center | data-grid / card-06 (network hub) | feature-grid / card-03 (one pane) |
| Architecture / composition | iso-grid / card-01 (tower) | iso-datacenter / card-01 (rack) |
| Infrastructure | iso-datacenter / card-01 (rack) | iso-city / card-01 |
| Observability | iso-datacenter / card-04 (radar) | terminal-grid / card-02 |
| Self-modification | iso-v2 / card-05 (tumbling cube) | Custom recursive arrow |

---

## How to reproduce a card inline

Don't iframe bento cards in slides decks. Iframes break nav/scroll-snap and look stitched in.

Instead:
1. Open the bento HTML in the source path
2. Copy the card's HTML structure (the `.card` or `.preview` div)
3. Copy the card-specific CSS (look for `/* ═══ CARD N — Name ═══ */` comment blocks)
4. Scope the class names by prefixing with a slide identifier (e.g. `.s7-pv-hub` instead of `.pv-hub`)
5. Copy any per-card JS (some cards have typing cycles, counters, etc.)
6. Adjust dimensions to fit the slide layout (bento cards expect ~380x360px card; slides have more room)

A worked example: `examples/m1-reference.html` embeds three custom isometric scenes directly (Fig 01 · Anatomy / Fig 02 · The loop / Fig 03 · Architecture). Study the CSS tokens and cube patterns there.

---

## Full cinematic modules index

All 14 bento explainers ship in [`./bento-pack/`](./bento-pack/). When nothing in the curated list above fits, browse here:

**Bento explainers (all shipped in `bento-pack/`):**
- `explainer-bento-feature-grid.html` — UI motion mockups (6 cards)
- `explainer-bento-concept-grid.html` — abstract diagrams (6 cards)
- `explainer-bento-terminal-grid.html` — CLI aesthetics (6 cards)
- `explainer-bento-data-grid.html` — animated charts (6 cards)
- `explainer-bento-paper-grid.html` — academic/editorial (6 cards)
- `explainer-bento-blueprint-grid.html` — engineering schematic (6 cards)
- `explainer-bento-isometric-grid.html` — pure 3D (6 cards)
- `explainer-bento-neon-grid.html` — synthwave/arcade (6 cards)
- `explainer-bento-isometric-datacenter.html`
- `explainer-bento-isometric-city.html`
- `explainer-bento-isometric-machine.html`
- `explainer-bento-isometric-flow.html`
- `explainer-bento-isometric-stack.html`
- `explainer-bento-isometric-grid-v2.html`

**Paradigm modules** (not shipped with this skill — reference only, build your own or source separately):
- Scroll-driven (9): text-mask, sticky-stack, zoom-parallax, horizontal-scroll, sticky-cards, svg-draw, curtain-reveal, split-scroll, color-shift
- Cursor/hover (8): cursor-reactive, accordion, cursor-reveal, image-trail, flip-cards, magnetic-grid, spotlight-border, drag-pan
- Click (6): view-transitions, particle-button, odometer, coverflow, dynamic-island, dock-nav
- Ambient (7): text-scramble, marquee, mesh-gradient, circular-text, glitch, typewriter, gradient-stroke

Scroll-driven paradigms generally don't slot into 100vh slides (they expect scroll hijack). Use bento cards over paradigms for master-slides decks.

---

## When to invent a new graphic

Only when:
1. No card in the curated list matches the concept
2. No card in the full pack matches it either
3. The slide really needs a visual (not every slide does)

When inventing: follow the design tokens in SKILL.md, keep animation subtle, one primary motion per scene. If the concept comes up repeatedly across decks, add it to the concept-lookup table above after it's signed off.
