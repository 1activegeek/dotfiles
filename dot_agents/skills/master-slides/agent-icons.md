# Agent Icons — master-slides

Pixel-art agent icons for use in multi-agent scenes, lineups, and "who does what" slides.

The shipped set below is an **example** — it shows 6 sample agents with distinct colors and pixel grids. **Customize with your own team's identity** by editing `SIDEBAR_ICON_DATA` and the `renderAgentIcon` function.

## Pixel data (copy-paste)

Drop this into the deck's inline `<script>` block:

```javascript
const SIDEBAR_ICON_DATA = {
  'agent-a': { color: '#ffffff', pixels: [[0,0,1,0],[1,1,1,1],[1,1,1,1],[1,0,1,1],[1,1,1,1],[1,1,1,1],[1,0,0,1],[0,0,0,0]] },
  'agent-b': { color: '#58abf5', pixels: [[0,0,1,0],[0,1,1,1],[1,1,1,1],[0,1,0,1],[0,1,1,1],[1,1,1,0],[0,0,1,0],[0,0,0,0]] },
  'agent-c': { color: '#f5a623', pixels: [[0,0,1,0],[0,0,1,1],[0,1,1,1],[0,1,0,1],[0,1,1,1],[1,1,1,1],[1,0,1,0],[0,0,0,0]] },
  'agent-d': { color: '#b47aff', pixels: [[1,0,0,0],[1,1,0,0],[0,1,1,1],[0,1,1,1],[1,1,0,1],[0,1,1,1],[0,1,0,1],[0,0,0,0]] },
  'agent-e': { color: '#50e3c2', pixels: [[0,0,1,0],[0,0,1,1],[0,1,1,1],[1,1,0,1],[1,1,1,1],[1,1,1,1],[1,0,0,1],[0,0,0,0]] },
  'agent-f': { color: '#ff6b6b', pixels: [[0,0,1,1],[0,1,1,1],[1,1,1,1],[1,1,0,1],[1,1,1,1],[0,1,1,1],[0,0,1,1],[0,0,0,0]] },
};

function renderAgentIcon(agentId, size = 36) {
  const d = SIDEBAR_ICON_DATA[agentId];
  if (!d) return '';
  const cols = 8;
  let rects = '';
  for (let y = 0; y < d.pixels.length; y++) {
    for (let x = 0; x < d.pixels[y].length; x++) {
      if (d.pixels[y][x]) {
        rects += `<rect x="${x}" y="${y}" width="1" height="1" fill="${d.color}"/>`;
        rects += `<rect x="${cols - 1 - x}" y="${y}" width="1" height="1" fill="${d.color}"/>`;
      }
    }
  }
  return `<svg viewBox="0 0 8 8" width="${size}" height="${size}" style="image-rendering:pixelated;">${rects}</svg>`;
}
```

## HTML pattern — agent lineup

```html
<div class="agent-lineup">
  <div class="agent-badge">
    <div data-agent="agent-a"></div>
    <span class="name">Agent A</span>
    <span class="role">Orchestrator</span>
  </div>
  <div class="agent-badge">
    <div data-agent="agent-b"></div>
    <span class="name">Agent B</span>
    <span class="role">Dev</span>
  </div>
  <!-- …repeat for each agent in your team -->
</div>

<script>
  document.querySelectorAll('[data-agent]').forEach(el => {
    el.innerHTML = renderAgentIcon(el.dataset.agent, 40);
  });
</script>
```

## CSS pattern

```css
.agent-lineup {
  display: flex;
  gap: clamp(16px, 2vw, 28px);
  align-items: flex-start;
  justify-content: center;
  flex-wrap: wrap;
}
.agent-badge {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  min-width: 64px;
}
.agent-badge svg { image-rendering: pixelated; }
.agent-badge .name {
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--text-paper);
}
.agent-badge .role {
  font-family: 'Outfit', sans-serif;
  font-weight: 300;
  font-size: 11px;
  color: var(--text-dim);
  font-style: italic;
}
```

## Customizing for your team

Replace the 6 sample agents with your own. For each agent:

1. **Pick a key** — a short lowercase name (e.g. `design`, `ops`, `pm`)
2. **Pick a color** — a hex value unique to that agent
3. **Draw a pixel grid** — 8 rows × 4 cols (the renderer mirrors to 8 cols)
   - `1` = pixel on, `0` = pixel off
   - Keep the silhouette distinct — different heads, antennas, or accents
4. **Pick a role line** — one short phrase for the lineup

Example team:

| Key | Color | Role |
|---|---|---|
| `design` | `#ff6b1a` | Designer |
| `eng` | `#58abf5` | Engineer |
| `pm` | `#50e3c2` | PM |
| `ops` | `#f5a623` | Ops |

## Sizing guidance

| Context | Size |
|---|---|
| Inline icon in body text | 16px |
| Agent badge in lineup | 36-44px |
| Hero agent icon (single agent feature slide) | 120-180px |
| Dashboard mock mini-row | 10-12px |

## Notes

- The icons render symmetric (each row's 4 source cols are mirrored to cols 4-7)
- `image-rendering: pixelated` is REQUIRED — without it the icons blur when scaled
- Keep each agent's color canonical across decks so viewers associate hue with identity
- For animated/active states, add a "hop" keyframe animation to convey "working now" vs "idle"
