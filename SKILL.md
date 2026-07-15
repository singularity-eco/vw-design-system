---
name: nst-design-system
description: Generates Vision Waves / NST enterprise UI using repo components only. Use when building dashboards, KPI cards, admin consoles, forms, tables, HTML mocks, or React/SPA UI in this design-system repo. Enforces nst-design-system.css, vw-card/vw-chip classes, and COMPONENTS.md registry — never random designs.
user-invocable: true
---

# NST Design System

This is the **canonical** skill doc. `.claude/skills/nst-design-system/SKILL.md` and
`.cursor/skills/nst-design-system/SKILL.md` are thin pointers to this file — edit rules here,
not there, so the three copies don't drift out of sync.

## Non-negotiable workflow

Every UI task MUST follow this order:

1. **Read `COMPONENTS.md`** — find the component; if it exists, use it (includes `nst-table` — both the grid and semantic `<table>` variants are already registered)
2. **Read the reference** (CSS + `preview/*.html` listed in registry)
3. **Generate using only those classes and tokens**
4. **Self-check** forbidden patterns in `COMPONENTS.md`

Skipping step 1 produces incorrect output.

Always-on Cursor rule (same rules, shorter): `.cursor/rules/nst-design-system.mdc`

## Retrofitting an existing app

Use this instead of the workflow above when the task is applying this design system to a page or
component that **already has working code** — not building fresh. Rebuilding from scratch here is
a failure mode: it risks losing data-wiring (props, hooks, API calls, state) that has nothing to do
with styling.

**1. Determine intent — cheaply.**
- If the user already said "revamp" / "new build" / "match the existing X", trust that. Don't
  re-analyze the codebase to double-check.
- If they didn't say: do one quick existence check — does the target file/component already contain
  real logic (props, hooks, API calls, state)? If yes, ask one clarifying question ("this already has
  working data logic — restyle only, or rebuild?") before proceeding. Don't run a deep codebase
  analysis just to decide this.

**2. Retrofit sequence, once it's a revamp:**
1. Read the target component's code first. Identify what's data/logic — props, hooks, state, API
   calls, event handlers — and treat all of it as off-limits.
2. Start the dev server and screenshot the current rendered page. This catches runtime-only
   behavior (conditional renders, computed styles) a static code read alone would miss.
3. Match each visible section against `COMPONENTS.md` (this card → `.vw-card-section`, this table →
   `.nst-table`, this button → `.nst-btn--filled`, etc.).
4. Swap **only** markup/className to registry classes. Never touch data-wiring, props, state, or
   component boundaries unless the user explicitly asked for a logic change too.
5. Re-screenshot and compare against the original — confirm both the visual match improved *and*
   nothing broke functionally (data still renders, interactions still work, no new console errors).

If a screenshot of the current page isn't available (no dev server, no running app), fall back to
step 3 onward using the code alone, but say explicitly that visual parity is unverified without it.

## Stylesheet (always)

```html
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="nst-design-system.css">
```

Add `components.css` only for `.nst-input` / `.nst-table-*`.

## Legacy / dashboard (default — matches reference-only guidelines)

- `nst-design-system.css` + vw classes
- Specimens: `preview/vw-cards.html`, `preview/kpi-card.html`
- Cards: `.vw-card-section`, `.vw-card-title`, `.vw-card-metric-lg`
- Chips: `.vw-chip.vw-chip--success`
- Layout: `.vw-flex`, `.vw-page-gap`, `.vw-grid-cols-auto-320`

## Atomic layer (only when task needs buttons/inputs/tables)

- `components.css`, `preview/buttons-*.html`, `preview/table.html`, `preview/table-semantic.html`
- Figma-atomic React demo (buttons/fields only, not design-tokens-driven): `ui_kits/admin-console/components.jsx`
- Do **not** use this layer for KPI/dashboard cards

## React / SPA usage

`vw-*` and `nst-*` classes are plain CSS — use them as `className` exactly as you would in HTML.
No separate React port is needed for Layer 1/2 classes:

```jsx
<div className="vw-card-section vw-flex vw-flex-col vw-justify-between" style={{ maxWidth: 300 }}>
  <div className="vw-card-title">Potential revenue</div>
  <div className="vw-card-metric-lg">₹2.5M</div>
</div>
```

Load `nst-design-system.css` once at the app root. **Do not** base design-system-consistent React
components on `ui_kits/admin-console/components.jsx` — that's a separate Figma-atomic prototype
(Inter font, inline styles, no `vw-*`/`nst-*` classes), scoped to atomic demos only. Full detail:
`COMPONENTS.md` → "Framework usage — HTML vs React / SPA".

## Hard rules

- **Poppins** on enterprise/dashboard pages (not Inter)
- Use **registry components** — no invented `.card`, `.badge`, random hex
- **Sentence case** copy; pastel chips for status
- **No** Tailwind, Bootstrap, Material, or freestyle layouts

## Deviation policy

Hard rules apply by default, to every tool reading this repo. If a user explicitly asks for
something that breaks one (off-palette color, Tailwind, a non-Poppins font, an invented class):
don't silently comply, don't silently refuse. Name the rule being broken and why it exists, ask
for explicit confirmation, then implement exactly that — as a one-off, not a new precedent. No
confirmation or an ambiguous ask → default back to the registry. Full policy: `COMPONENTS.md` →
"Deviation policy".

## KPI card pattern

```html
<div class="vw-card-section vw-flex vw-flex-col vw-justify-between" style="max-width: 300px;">
  <div class="vw-card-title">Potential revenue</div>
  <div class="vw-flex vw-justify-between vw-items-baseline vw-gap-sm">
    <div class="vw-card-metric-lg">₹2.5M</div>
    <div class="vw-card-variance is-positive">+12%</div>
  </div>
</div>
```

## File map

| File | Purpose |
|------|---------|
| `COMPONENTS.md` | **Start here** — component registry, includes React/SPA usage section |
| `nst-design-system.css` | Canonical stylesheet bundle |
| `vw-cards.css` / `vw-chips.css` / `vw-utilities.css` | Legacy component classes |
| `components.css` | Form/table primitives (`.nst-*`), including `nst-table` |
| `preview/vw-cards.html` | Card specimens |
| `preview/table.html` / `preview/table-semantic.html` | Table specimens |
| `preview/gallery-index.html` | **Verification galleries** — live classes + snippets + reference tables for cards, utility, and Layer 2 atomic |
| `AGENTS.md` | Short agent instructions |
