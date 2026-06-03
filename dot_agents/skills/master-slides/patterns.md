# Patterns Library — master-slides

Reusable slide components. Reach for these first before inventing new HTML/CSS from scratch. Each pattern ships with proven motion, on-brand type, and tested proportions.

The full worked HTML for every pattern is in `examples/m1-reference.html` — grep by the pattern class name.

---

## 1 · CLAUDE.md mock (animated)

**Use when** a slide reads "let's open a file" or "here's what's inside a [config file]." The mock shows role/rules/tools/memory rows with a blinking cursor and a scanning accent bar across the top — reads as "live file being read by an agent."

**When NOT to use** — when you actually want to screen-share a real CLAUDE.md. Use this only as the preview/tease.

**HTML:**
```html
<div class="claude-mock reveal">
  <div class="cm-head">
    <span class="dot"></span>
    <canvas data-agent="agent-a" width="28" height="28" style="width:14px;height:14px;"></canvas>
    CLAUDE.md · Agent A
  </div>
  <div class="cm-row"><span class="k">role</span><span class="v">Content agent · writing, scripts, packaging</span></div>
  <div class="cm-row"><span class="k">rules</span><span class="v">Always fact-check · no AI-smell writing</span></div>
  <div class="cm-row"><span class="k">tools</span><span class="v">Dashboard · tasks.json · Drive</span></div>
  <div class="cm-row"><span class="k">memory</span><span class="v">memory/convo_log.md<span class="cur"></span></span></div>
</div>
```

**CSS:** Lives in template.html under `/* ─── CLAUDE.md live mock (slide 05) ─── */`. Key selectors:
- `.claude-mock` — the container box
- `.claude-mock::before` — scanning accent line animation (`scanBar` keyframe)
- `.cm-head .dot` — pulsing accent dot
- `.cm-row .k` — accent key labels
- `.cm-row .cur` — blinking cursor at end of last value

**Swap agent:** change `data-agent="agent-a"` to any agent key you defined in `agent-icons.md`. The icon and the title both reflect whichever agent the config belongs to.

---

## 2 · Agent lineup (multi-agent pixel bar)

**Use when** the brief introduces or references an agent team, mentions "multi-agent," "specialization," "the team," or whenever the slide benefits from showing agents as a group. **Rule 12 applies: never type an agent name without rendering its pixel icon alongside.**

**HTML:**
```html
<div class="agent-lineup reveal">
  <div class="agent-badge">
    <canvas data-agent="agent-a" width="56" height="56" style="width:44px;height:44px;"></canvas>
    <span class="name">Agent A</span>
    <span class="role">Orchestrator</span>
  </div>
  <!-- …repeat for each agent defined in agent-icons.md -->
</div>
```

**CSS:** in template.html under `/* ─── Agent pixel lineup ─── */`. Provides hover-lift on `.agent-badge`.

**Variants:**
- **Single hero agent** — one 120-180px pixel icon center-stage for an "agent spotlight" slide
- **Subset (3 agents)** — when the slide focuses on a specific sub-team
- **Inline in body text** — 14-16px canvas inline with a paragraph when referencing an agent mid-sentence

Define your team's agents, colors, and roles in `agent-icons.md` — then reference them here by their keys.

---

## 3 · Self-modifying file-box

**Use when** a concept involves a thing modifying itself, iteration, feedback loops, learning, or "correct once, it learns forever." Shows a file frame with an orange "+1 rule" line expanding in every 3.5s, wrapped by recursive dashed arrows.

**HTML:**
```html
<div class="self-mod-stage reveal">
  <svg class="loop" viewBox="0 0 300 180" preserveAspectRatio="none">
    <path d="M 220 50 C 280 50, 280 130, 220 130 L 215 125 M 220 130 L 225 125"/>
    <path d="M 80 130 C 20 130, 20 50, 80 50 L 85 55 M 80 50 L 75 55"/>
  </svg>
  <div class="file-box">
    <div class="title">CLAUDE.md</div>
    <div class="line w1"></div>
    <div class="line w2"></div>
    <div class="line w3"></div>
    <div class="line w1"></div>
    <div class="line new"></div>
  </div>
</div>
```

**CSS:** in template.html under `/* ─── Self-modifying animation ─── */`. The `.line.new` class animates in via `newRule` keyframe; the SVG arrows loop via `loopDraw`.

**Swap the label:** change `.title` text from `CLAUDE.md` to `skill.md`, `memory.md`, etc. The "thing that rewrites itself" can be anything.

---

## 4 · Brand block (title slide)

**Use when** the deck is branded content (masterclass modules, product packages, community pieces). Skip for work where brand prominence isn't needed (client pitches, personal).

**HTML:**
```html
<div class="brand-block">
  <svg class="mark" width="44" height="44" viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    <!-- Swap for your own logo SVG -->
    <path d="M24 6l18 10v16L24 42 6 32V16Z"/>
    <path d="M24 6v16l18 10" opacity="0.5"/>
    <path d="M24 22L6 32" opacity="0.5"/>
  </svg>
  <div class="text">
    <div class="title-line">{{BRAND}} <span class="mc">· {{PRODUCT}}</span></div>
    <div class="tag-line">Created by {{BRAND}} · {{TAGLINE}}</div>
  </div>
</div>
```

Fill the placeholders with your brand, product name, and tagline.

The `.mark` SVG floats gently via `brandFloat` keyframe. The block fades in 0.9s after the title slide becomes visible (delay baked into the transition).

---

## 5 · Iso scene · stacked tower

**Use when** the concept is composition, layers, stacked parts, "three pieces of one thing." Three gray isometric cubes stacked + one orange cube bouncing above.

**HTML:**
```html
<div class="iso-stage reveal">
  <div class="scene-tower">
    <div class="shadow"></div>
    <div class="iso-cube gray t1"><div class="face top"></div><div class="face left"></div><div class="face right"></div></div>
    <div class="iso-cube gray t2"><div class="face top"></div><div class="face left"></div><div class="face right"></div></div>
    <div class="iso-cube gray t3"><div class="face top"></div><div class="face left"></div><div class="face right"></div></div>
    <div class="iso-cube orange t4"><div class="face top"></div><div class="face left"></div><div class="face right"></div></div>
  </div>
</div>
```

Ref source: cinematic-site-modules bento pack — `explainer-bento-isometric-grid.html` card-01.

---

## 6 · Iso scene · orbiting rings

**Use when** the concept is cyclical: loops, rotations, continuous processes. Three concentric rings with satellites, orange core pulsing at center.

**HTML:**
```html
<div class="iso-stage reveal">
  <div class="scene-orbit">
    <div class="orb-core"></div>
    <div class="ring r1"><div class="sat"></div></div>
    <div class="ring r2"><div class="sat"></div></div>
    <div class="ring r3"><div class="sat"></div></div>
    <div class="ring-label rl-observe">Observe</div>
    <div class="ring-label rl-think">Think</div>
    <div class="ring-label rl-act">Act</div>
    <div class="ring-label rl-repeat">Repeat</div>
  </div>
</div>
```

Ref source: cinematic-site-modules bento pack — `explainer-bento-isometric-machine.html` card-06.

**Swap labels:** change the 4 ring labels to any observe/think/act/repeat variant, or to 4 other phases.

---

## 7 · Iso scene · hub + spoke

**Use when** concept is architecture, central coordination, MCP, integration, "everything plugs into one thing." Central orange hub + 6 node spokes with pulsing dashed lines.

**HTML:**
```html
<div class="iso-stage reveal">
  <div class="scene-hub">
    <svg class="lines" viewBox="0 0 100 100" preserveAspectRatio="none">
      <line class="hub-line" x1="50" y1="50" x2="18" y2="22"/>
      <line class="hub-line" x1="50" y1="50" x2="82" y2="22"/>
      <line class="hub-line" x1="50" y1="50" x2="10" y2="50"/>
      <line class="hub-line" x1="50" y1="50" x2="90" y2="50"/>
      <line class="hub-line" x1="50" y1="50" x2="18" y2="78"/>
      <line class="hub-line" x1="50" y1="50" x2="82" y2="78"/>
    </svg>
    <div class="hub-center">AGT</div>
    <div class="hub-node p1 lit">Model</div>
    <div class="hub-node p2 lit">Tools</div>
    <div class="hub-node p3">Memory</div>
    <div class="hub-node p4 lit">Harness</div>
    <div class="hub-node p5">Rules</div>
    <div class="hub-node p6 lit">Loop</div>
  </div>
</div>
```

Ref source: cinematic-site-modules bento pack — `explainer-bento-feature-grid.html` card-05.

**Swap the hub label:** change `AGT` to your concept's 3-letter acronym. Swap the 6 node labels. Add `.lit` to any node to make it pulse orange.

---

## 8 · Iso text + scene (two-column)

**Use when** you want text on one side and a graphic on the other. Text at 45% width, scene at 55%. This is the default layout for concept-heavy slides.

**HTML:**
```html
<section class="slide iso-slide" data-title="Your concept">
  <div class="slide-content">
    <div class="iso-text">
      <h3 class="kicker reveal">Fig. 01 · Label</h3>
      <h2 class="scene-title reveal">Concept title with <em>italic accent</em>.</h2>
      <p class="body-text reveal">One compact paragraph.</p>
      <ul class="fine-list reveal">
        <li><span class="k">01 · Key</span><span class="v">Value</span></li>
        <!-- …up to 4 items -->
      </ul>
    </div>
    <div class="iso-stage reveal">
      <!-- Drop any iso scene pattern here -->
    </div>
  </div>
</section>
```

---

## 9 · Recipe card

**Use when** the concept is a named procedure or skill — a sequence of steps that are always run in order. Classic fit: Skills as reusable playbooks, checklists, pipelines framed as recipes (not graph nodes).

**Picked for:** M2 Skills slide.

**HTML:**
```html
<div class="m2-recipe">
  <div class="h">script-writing.md</div>
  <div class="step"><span class="n">01</span><span>Research the topic</span><span class="bar"><span class="fill"></span></span></div>
  <div class="step"><span class="n">02</span><span>Write the hook</span><span class="bar"><span class="fill"></span></span></div>
  <div class="step"><span class="n">03</span><span>Draft the body</span><span class="bar"><span class="fill"></span></span></div>
  <div class="step"><span class="n">04</span><span>Nail the CTA</span><span class="bar"><span class="fill"></span></span></div>
</div>
```

**Source:** `m2-deck/slides.html`, `/* ─── Skills · recipe card (V02 pick) ─── */`. Scan bar, italic serif title, sequential progress bars with staggered fills.

**Color variants:** `h` color can shift teal (evergreen procedures) or violet (abstract/formal recipes). Default orange.

---

## 10 · Glass filling

**Use when** the concept is capacity, ceiling, or "it fills up." Primal, visceral — everyone has felt a cup overflow.

**Picked for:** M2 Context Window slide. Fills to 85%, caption below.

**HTML:**
```html
<div class="m2-glass-wrap">
  <div class="m2-glass"><div class="water"></div></div>
  <div class="cap">Context · <b>85%</b> full</div>
</div>
```

**Source:** `m2-deck/slides.html`, `/* ─── Context · glass filling (V03 pick) ─── */`. Stylized glass with rounded bottom, highlight streak, orange water rising with glow.

**Color variants:** swap the `.water` gradient to teal for "capacity healthy," amber for "near warning," red for "overflow." Default orange = mid-warning.

**Variant:** drip overflow — add an `::after` on `.m2-glass` for a drop falling when full.

---

## 11 · USB-C device

**Use when** the concept is universal plug-in, standard connector, "many things into one port." Classic fit: MCP, integration standards, API adapters.

**Picked for:** M2 MCP slide. Central MCP device with 4 plugs (Gmail, Slack, Drive, GitHub) reaching in on curved cables.

**HTML (abbreviated):**
```html
<div class="m2-usb">
  <svg viewBox="0 0 440 320">
    <rect class="device" x="170" y="110" width="100" height="100" rx="10"/>
    <text class="lbl" x="220" y="150" text-anchor="middle">MCP</text>
    <rect class="port" x="186" y="165" width="68" height="28" rx="6"/>
    <path class="cable" d="M 92 90 Q 140 90, 160 110"/>
    <rect class="plug p1" x="60" y="76" width="52" height="26" rx="4"/>
    <text class="plug-lbl" x="86" y="93" text-anchor="middle">GMAIL</text>
    <!-- …repeat for p2/p3/p4 at other corners -->
  </svg>
</div>
```

**Source:** `m2-deck/slides.html`, `/* ─── MCP · USB-C (V02 pick) ─── */`. Plugs pulse in-out sequentially with drop-shadow glow.

**Color variants:** Plugs can be differently colored per integration semantic — Gmail amber, Slack violet, Drive cyan, GitHub orange. Currently all orange. Add variety per the color rules in SKILL.md.

---

## How to add a new pattern

1. Build and ship it once on a real deck (first as a graphics-sheet variant, then promoted after it's picked)
2. Extract the HTML + CSS block
3. Add a section here with: use case, HTML, CSS source path, color variants, and "picked for:" credit
4. If it's signed off as reusable, bake the CSS into template.html so it works without copy-paste
