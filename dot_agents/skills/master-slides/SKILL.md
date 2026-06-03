---
name: master-slides
description: Build single-file HTML presentations with paper typography + isometric/cinematic graphics. The user gives a brief (topic, outline, or full script), the skill generates a complete deck with scroll-snap slides, brand styling, and animations. Triggers on "master-slides", "build slides", "create deck", "make a presentation", "/tweak [N]".
---

# Master Slides

Build single-file HTML presentations from a brief. Paper typography + cinematic graphics + configurable branding. The deck opens directly in a browser — no build step.

## When to invoke

Trigger this skill when the user asks for slides, a deck, a presentation, or uses `/tweak [N]` to revise an existing deck. Works for:
- Masterclass modules and lesson decks
- YouTube video slide decks
- Community session talks
- Client / corporate pitches
- Any teaching piece that needs visual support

NOT for: MARP decks, lesson visualizations, or cinematic marketing sites — those are separate skills.

## Inputs accepted

The brief can be any of:
- **A topic** — "explain MCP servers" — skill designs structure
- **An outline** — "intro / problem / solution / demo / CTA" — skill fills each section
- **A full script** — slide-by-slide copy — skill handles visuals only
- **Mix** — topic plus some must-hit slides

Slide count is driven by the brief. No default minimum or maximum.

## Workflow — two phases

### Phase 1 · Explore (graphics sheet)

For non-trivial decks, **first produce a `graphics-sheet.html`** in the module folder by copying `graphics-sheet-template.html` from this skill. The sheet shows every concept that needs a visual, with 3–5 creative variants per concept side-by-side. The user curates in-browser, then hits Copy.

**Why:** default behaviour converges on safe picks from the bento pack. The sheet forces exploration — invent new metaphors, try unusual takes, take creative risks. The user curates. Winners get promoted to `patterns.md`; losers get archived.

**When to run Phase 1:**
- First build of a new module deck
- Any time the brief has unfamiliar concepts (no clear bento-card match)
- When the user says "be more creative" or "push for variety"

**Structure of the graphics sheet:**
- One section per concept, labeled and numbered (`01`, `02`, …)
- Each section has 3–5 variant cards in a row: `V01` (baseline) → `V0N` (creative takes)
- Each variant shows the live animation, a one-line name, a one-line description
- Fixed picks bar at bottom-center with pick count, chips, Copy + Clear buttons
- Comment textarea on every variant ("+ note") for per-variant feedback

**Interactions** (already wired in the template — don't reinvent):
- **Click a variant** to pick it (one pick per concept; re-click to un-pick; clicking a different variant in the same row swaps)
- **"+ note" button** on each variant → inline textarea, blur to save
- Pink badge appears on picked variants (orange checkmark, glow border)
- Picks bar shows `3 / N picks` + chip list with `×` remove per chip
- **Copy Picks** → formats `M{N}.concept=V0X` with notes inline: `M2.skills=V02 — "stopwatch icon would help"`. Toast confirms.
- **Clear** asks before wiping (picks and notes together).
- **localStorage keys:** `picks-M{N}` + `notes-M{N}`. Keyed `concept:variant` for notes so losers can have notes too.

**Default variant rule:** V01 is always the safest/shipped baseline. V02+ explore different metaphors, materials, cultural references. Don't repeat yourself across variants.

**To generate a new sheet:**
1. Copy `graphics-sheet-template.html` to the target deck folder as `graphics-sheet.html`
2. Update `<title>`, header h1, and kicker
3. In the `<script>`, change `MODULE = 'M2'` to the correct `M{N}` and `CONCEPTS = [...]` to the ordered list of concept keys you'll use
4. Replace the concept rows in `<body>` with your own (keep the `<section class="concept-row">` structure)
5. Add per-variant CSS blocks to the bottom of `<style>` (scope them with a prefix like `.c01v02` to avoid cross-row clashes)
6. Open in browser — everything else just works

### Phase 2 · Build (deck)

After the user picks (or on simpler decks where Phase 1 is skipped):

1. **Parse the brief** — topic, outline, or script. Ask for a project-id (e.g. `M1`, `DECK-01`) if not given. Derive a short folder name from the brief.

2. **Set up project folder** — `./projects/{id}-{short-desc}/{m{n}-deck}/` if it doesn't exist. The deck lives at `slides.html` inside it.

3. **Copy `template.html`** from this skill to the deck folder as `slides.html`. Keep the CSS, fixed UI, and SlidePresentation script untouched.

4. **Fill slides using the user's picks** — for each iso-slide or graphic moment, use whichever variant the user picked in Phase 1. For concepts without picks, use the baseline from `patterns.md` or the relevant bento card.

5. **Open in browser** automatically when generation completes.

6. **Append a session-log entry** in the project folder, noting which slides were generated, which variants were picked, and which graphics inspired each.

7. **Promote winners** — if the user's pick for a concept isn't already in `patterns.md`, add it. If it's a strong reusable, bake its CSS into `template.html`.

## Handling `/tweak [N]`

If the user runs `/tweak 5`, don't rebuild the whole deck. Open the most recent `slides.html`, locate slide 5 (by the `data-title` attribute or position), and regenerate only that slide's content + any scoped CSS. Preserve all other slides, the CSS tokens, and the JS controller untouched.

## Design defaults (CUSTOMIZABLE)

These are the shipped defaults — override them in `template.html` to match your brand.

**Typography (paper style):**
- `'Instrument Serif'` 400 for display `h1` (italic for accent words)
- `'Outfit'` 300-700 for body, kickers, utility
- `'JetBrains Mono'` 400-500 for labels, kickers, specs, numbers
- Orange highlight sweep animating across `<span class="hl">` keywords on slide enter
- Italic `<em>` or `<span class="italic">` for accent words in h1

**Colors (CSS variables in `template.html`):**
- `--bg: #000`
- `--surface: #0a0a0a`
- `--border: #1a1a1a`
- `--text: #e0e0e0`
- `--text-paper: #f1ece0` (display text)
- `--text-dim: #888`
- `--accent: #ff6b1a` (primary — swap for your brand color)
- `--teal: #50e3c2` (success / evergreen / pattern-holds)
- `--amber: #f5a623` (warning / in-progress / scarcity)
- `--violet: #8b5cf6` (abstraction / meta / systems-of-systems)
- `--cyan: #22d3ee` (data / observation / signals)
- `--red: #ef4444` (error / blocked / stop)

### Color variety rule

**The accent color is primary — use it on title words, picks, active states, main accents.** But **don't make every element the accent**. Every slide and graphic should use at least one *non-accent* color from the palette above. Multi-color is on-brand; mono-accent reads monotonous.

Semantic mapping (when the concept has an obvious match):
| Color | Semantic | Typical concepts |
|---|---|---|
| Accent `--accent` | Primary / brand / energy | Hooks, CTAs, hero graphics, picks, active states |
| Teal `--teal` | Evergreen / success / "this works" | Evergreen slides, done states, patterns-that-hold, autonomy % |
| Amber `--amber` | Warning / ceiling / scarcity | Rate limits, costs climbing, "in progress," approaching failure |
| Violet `--violet` | Abstraction / meta / formal | Rules, contracts, instructions, specs, definitions |
| Cyan `--cyan` | Data / signals / observation | Metrics, logs, readings, input streams |
| Red `--red` | Error / stop / blocked | Failure modes, gates, destructive actions, stopping |

**Practical applications:**
- **Multi-item graphics** (tower, lineup, pipeline, hub-spokes): don't paint them all in the accent. Color each item by semantic — model=cyan (brain), harness=accent (body), instructions=violet (personality). Each tells a story via its hue.
- **Kicker labels**: accent is default. Vary to teal/amber/cyan/violet per concept where it fits.
- **Highlight sweeps** (`.hl`): accent by default. Use `.hl.teal-hl` for evergreen keywords. Build `.hl.amber-hl` etc. as needed.
- **Metric cards**: deltas green/red, values accent, labels muted. Charts use 2-3 colors minimum.
- **Isometric cubes**: theme palette per scene — one cube in the accent (hero), others in complementary colors.

If you find yourself reaching for the accent on more than 60% of a graphic's colored elements, step back and re-color. Monochrome is the failure mode.

**Motion:**
- Reveal: `opacity 0→1` + `blur(4px)→0` + `scale(0.98→1)` + `translateY(30px→0)` with children staggered
- Per-slide radial spotlight fades in on `.visible`
- Accent underline draws beneath `h1 .accent` spans
- `.hl` highlight sweep 5s loop (paused until slide is visible)

**Fixed UI on every deck:**
- Progress bar top (accent gradient, width = scroll %)
- Nav dots right center (one per slide, active = accent)
- Slide counter bottom-right (`01 / N`)
- **Prev / Next arrows bottom-center** — floating pill buttons, keyboard + click
- **Brand watermark bottom-left** — swap for your own brand in `template.html`
- Favicon (customize)
- **Hexagon mesh canvas background** (slowly rotating)
- **Scattered pixel decorations** (12 pixels at low opacity, tilted)
- Cursor-follow accent glow (subtle)

**Navigation (must all work):**
- Keyboard: ↑↓←→, Space, PgUp/PgDn, j/k, Home/End
- Touch swipe (mobile)
- Click any nav dot to jump
- **Click prev / next arrow buttons at bottom-center** (auto-disabled at deck ends)
- Scroll-snap handles smooth transitions

Future style variants (blueprint, terminal, neon) can be added as `--style=` flags. For now, paper+iso+accent is the supported default.

## Slide types

The template includes these patterns. Pick per slide:

- **`.slide.lead`** — centered title + subtitle, optional kicker, for hook/intro/section-break slides
- **`.slide.iso-slide`** — two-column: text left (kicker + h2 + body + fine-list), 3D scene right. Use for concept scenes.
- **Content slide** — h1 + bullets or grid, max 6 items
- **`.slide.lead` + brand block** — title slide only; carries the brand mark + product name + attribution under the subtitle
- **Logo row slide** — platform-agnostic moment ("works on Claude Code / Cursor / Windsurf / …")

One idea per slide. If you need to say more, split into multiple slides.

## Branding

**Always include:**
- Brand watermark (bottom-left every slide) — customize in `template.html`
- Favicon

**Include when appropriate:**
- Brand block on the title slide (logo + product name + attribution) — use for masterclass modules, packaged content, community content
- Skip the brand block for work where brand prominence isn't needed (e.g. client pitches) — still keep the watermark

## References

Load these files on-demand:

- **`component-library.html`** — **the master catalog. Open this FIRST when building any new deck.** Live-animated thumbnails of every pattern, technique, metaphor, and bento card in one filterable page. Filter by category + text search. Link-out to each component's source.
- **`template.html`** — the starter slide deck HTML. Copy, fill slide sections, ship.
- **`graphics-sheet-template.html`** — the Phase 1 exploration sheet. Copy, rename MODULE/CONCEPTS, replace concept rows, use for curation.
- **`patterns.md`** — reusable slide components (CLAUDE.md mock, agent lineup, self-modifying box, brand block, iso scenes, recipe card, glass filling, USB-C device, two-column iso layout). Reach here before inventing.
- **`patterns-preview.html`** — live rendered preview of the 11 core patterns with anchors (`#pattern-1` … `#pattern-11`). Open when you want to see a pattern in motion before pasting it. The "View spec" links in `component-library.html` point here.
- **`graphics-library.md`** — catalog of curated bento cards with descriptions plus the full cinematic modules index. First-class references for each common concept.
- **`agent-icons.md`** — pixel-art agent icons (SIDEBAR_ICON_DATA). The shipped set is an example — customize the colors and pixel grids with your own team's identity.
- **`bento-pack/`** — 14 `explainer-bento-*.html` files containing the full source for every bento card referenced by `component-library.html`. Open the file matching the card you want, copy its HTML + CSS inline into your deck.
- **`examples/m1-reference.html`** — a full worked example deck.

## Component sourcing — THE RULE

**`component-library.html` is the canonical source of every reusable visual component in this skill.** Every pattern, technique, metaphor, and curated bento-pack entry lives there. It's the only thing you need to survey when building a new deck — everything else (`patterns.md`, `graphics-library.md`) feeds into it or is linked from it.

**Mandatory flow when you need a graphic:**
1. Open `component-library.html`
2. Filter by category chip or search by concept keyword
3. Pick → click through to source → copy pattern
4. If nothing fits → run Phase 1 (graphics sheet exploration) to generate new variants
5. After a new variant is picked → promote into `component-library.html` (add an entry) AND `patterns.md` (if it's a canonical keeper)

**Never invent fresh without checking the library first.** The library's job is to prevent duplicated work and keep the visual language coherent. If the library feels incomplete, expand it — don't go around it.

## Rules (do not break)

1. Single HTML file. All CSS inline. All JS inline. No build step, no npm, no framework.
2. Every slide = 100vh, overflow hidden. Split content across slides before you ever allow a scrollbar inside a slide.
3. Typography is Instrument Serif + Outfit + JetBrains Mono. Never substitute — paper style is the default look.
4. Accent color (`--accent`, ships as `#ff6b1a`) is the primary. Teal `#50e3c2` only for success/evergreen semantics. Amber `#f5a623` for warnings. Customize `--accent` for your brand.
5. Brand watermark on every deck, bottom-left, no exceptions (customize the label).
6. One idea per slide. Max 6 bullets per content slide.
7. Prefer reproducing a graphic inline (copying the bento card's CSS/JS pattern) over iframing — iframes break cleanly, inline is reliable.
8. Reach for curated cards first (see `graphics-library.md`). Only invent new graphics when no card fits.
9. Output lands at `./projects/{id}-{short-desc}/slides.html` (or your configured project root) and opens in the browser when done.
10. Don't touch the `SlidePresentation` JS class, the progress bar, nav dots, arrow buttons, or watermark — they're load-bearing.
11. **Every slide must have at least one dynamic element.** Even lead/text-only slides — accent-word glow, marker pulse, brand mark float, underline draw, typing cursor, scan bar. Stillness is failure.
12. **Represent agents with pixel-art icons, always.** Anywhere the brief mentions named agents or "the team" or "multi-agent," render a canvas-based pixel icon via `drawPixelAgent()` (the function is in the template JS). Never use word-only labels — always the 36-44px colored pixel icon.
13. **Graphics can dominate; text shrinks up top.** For iso-slide scenes, prefer the graphic taking 55-60% of the slide. Title and body text compact at the top/left. Don't pad text to match graphic size.
14. **The hex mesh bg + scattered decorations are always on.** Don't remove `#hexBg` canvas or the pixel scatter init. They're the signature background.

## Tuning the background

The hex mesh + scatter + cursor glow all live on one knob. At the top of the `<script>` block in every deck:

```js
const BG_CONFIG = {
  hexAlphaMax:       0.08,  // halve for subtle bg
  hexCellSize:       20,    // 32-40 for sparser grid
  hexLineWidth:      0.6,   // 0.35 for thinner lines
  hexFadeExponent:   2,     // 3-4 for sharper edge-vignette
  hexRotationSpeed:  0.0001,
  scatterCount:      12,    // drop to 6 for fewer decorations
  scatterOpacityMin: 0.04,
  scatterOpacityMax: 0.08,
  cursorGlowAlpha:   0.04,
};
```

**Do not try to dim the bg with a black overlay.** A `body::after` black rgba on top of already-low-alpha pixels wipes the mesh to nothing. Tune at the source.

**Presets to try:**
- **Subtle** — halve `hexAlphaMax` (0.04), halve `scatterOpacityMax` (0.04), `hexCellSize` 32
- **Loud / hero** — `hexAlphaMax` 0.12, `hexCellSize` 16, `hexLineWidth` 0.8
- **Vignette** — `hexFadeExponent` 4 (center visible, edges go dark)
- **Warm** — change the hex `strokeStyle` line from `rgba(255,255,255,...)` to your accent rgba for a colored mesh

## Motion primitives · cheatsheet

Rule 11: every slide has ≥ 1 moving element. These are already baked into template.html — just apply the class and the motion runs:

| Class / selector | Motion | Use on |
|---|---|---|
| `.brand-block .mark` | Gentle 4s float | Brand hexagon on title slide |
| `.slide.lead h1 em` / `.italic` | 3.5s accent glow pulse | Accent words in lead h1s |
| `.slide.lead h1 .teal` | 3.5s teal glow pulse | Evergreen-semantic accent words |
| `.hl` span | 5s accent highlight sweep across keyword | Keyword emphasis in any h1 |
| `.hl-static` span | Static accent wash (no motion) | Keyword emphasis that shouldn't distract |
| `.logo-pill` | Staggered float (5s) | Universal-pattern slides with tool names |
| `.bullets li::before` | Accent marker pulse (3s) | Any content slide with bullets |
| `.claude-mock::before` | Scanning accent line across top | CLAUDE.md mock pattern |
| `.claude-mock .cm-head .dot` | Blinking accent dot | CLAUDE.md mock header |
| `.claude-mock .cur` | Terminal cursor blink | End of last CLAUDE.md mock row |
| `.self-mod-stage .file-box .line.new` | Accent line expands in every 3.5s | Self-modifying pattern |
| `.self-mod-stage svg.loop path` | Dashed arrows march along curve | Self-modifying pattern |
| `.scene-tower .iso-cube.t4` | Top cube bobs up + down | Stacked tower iso |
| `.scene-tower .shadow` | Shadow scales with cube | Stacked tower iso |
| `.scene-orbit .orb-core` | 2s breathe (scale + glow) | Orbiting rings iso |
| `.scene-orbit .ring.r1/.r2/.r3` | Spin at 8s/12s/16s rates | Orbiting rings iso |
| `.scene-hub .hub-line` | Dashed pulse along each spoke | Hub+spoke iso |
| `.scene-hub .hub-center` | Expanding accent halo pulse | Hub+spoke iso |
| `.scene-hub .hub-node.lit` | Static accent glow (ambient) | Hub+spoke iso lit nodes |
| `.reveal` | Blur+scale+translateY on slide enter | Any element that should animate in |

**If a slide has none of the above,** add a `.reveal` to at least the h1 and subtitle. If that still feels dead, wrap an accent word in `.hl` to get the sweep. **Never ship a slide that's purely static.**

## Quick start

```
master-slides

Brief: I need 10 slides on "what is MCP", for a community session. Mention Gmail and Drive as integration examples. End with a CTA.

Project-id: M1
```

The skill responds with: project folder created, slides.html generated, opened in browser, ready for `/tweak [N]` feedback.
