# Card reference — composition catalog

Sourced from real production Figma reference (an internal "Singularity Core Components" library),
not invented. Tagged by **structural usability**, never by source module/app name — the module
groupings in that Figma file are just how the samples happened to be collected, not a categorization
scheme worth inheriting.

**This is not a new component layer.** Every piece below maps to classes/tokens already registered
in this design system (`.vw-card-section`, `.vw-card-title`, `.vw-chip`, `.vw-card-metric-*`, etc.)
— nothing here requires inventing new CSS. It exists to solve a different problem than
`COMPONENTS.md`: that file tells you *which* component to use; this doc tells you how real,
production-tested compositions *arrange* those components together, so generation doesn't default
to the flattest possible expression of content (see `COMPONENTS.md` → "Composition heuristics").

It's a **modular** catalog: a small set of reusable header / body / footer pieces that combine
differently per content need, not a fixed list of whole-card templates. Compose from the pieces
first; only reach for a named archetype below as a starting silhouette, and swap pieces freely.

---

## 1. Header pieces

| Piece | What it looks like | `vw-*`/`nst-*` mapping | Notes |
|---|---|---|---|
| Icon slot | Small glyph icon, pale tinted square/badge | `.vw-card-icon-md` (+ `.vw-chip--neutral` background) | Standard, already registered |
| Illustration slot | Full decorative image/scene, left-aligned | plain `<img>`/inline SVG in a sized container | Used for higher-level/business-process entities, not operational/technical ones — visual weight signal |
| Title | Bold heading | `.vw-card-title` / `.vw-card-title-lg` | — |
| Subtitle | Smaller gray line directly under title (role, app name, "Sub heading") | `.vw-card-metric-label-sub` | Distinct from description — sits immediately under title, no gap before it |
| Status chip | e.g. "Approved", "Verified", "Engaged" | `.vw-chip--success`/`.vw-chip--info` etc. | Already registered |
| Toggle | Real on/off switch in header | see "Known registry gaps" — real usage confirmed (header-level enable/disable) | Not yet shipped |
| Rating | Star icon + numeric score (e.g. "4.3 ★") | see "Known registry gaps" — real usage confirmed (inline in header, and in a footer next to "Compliment") | Not yet shipped |
| Badge cluster | 2-3 small icon+number pills, each independently colored | Composable from `.vw-chip` variants (one per pill) | Not one component — just several small chips placed in a row |
| Kebab menu | Overflow `⋮` | `.nst-table-kebab` / `.nst-action-menu` | Already registered |
| Approve/reject pair | Two square icon buttons (✓ / ✕) | `.nst-btn--icon` ×2 | Alternative to kebab — for items awaiting a yes/no decision, not a general options menu |
| Inline value | A number placed directly in the header row (next to title/chip) | `.vw-card-metric-lg` positioned inline instead of in the body | Valid alternate hero-row ordering — value can lead, not just follow |
| Selection checkbox | Real checkbox at the very start of the header | see "Known registry gaps" — real usage confirmed (card-level selection) | Not yet shipped |

## 2. Body pieces

| Piece | What it looks like | `vw-*`/`nst-*` mapping | Notes |
|---|---|---|---|
| Plain label/value grid | N columns, label small-gray over bold value | `.vw-grid.vw-grid-cols-{2,3,4,5}` + `.vw-card-metric-label-sub` + bold value | Column count flexes 2-5 per section; already registered pattern |
| Shaded mini-stat tile row | 2-3 tiles, each icon+label+value in its own soft rounded box | nested tiles on `--vw-color-gray-50` bg, `--vw-radius-md` | Alternative to the plain grid when stats deserve more visual separation |
| Labeled progress bar | "Heading … 40%" line, bar below, two helper texts flanking underneath | fill bar on `--vw-color-*-500`/track `--vw-color-gray-100` | Precise spec for the already-logged progress-meter gap; can appear once, or once per metric side-by-side (2-up) inside a section |
| Metric + sparkline | Big value + delta, mini area-chart to the right, color-matched to trend (green up / red down) | precise spec for the already-logged sparkline gap | Sparkline color must match the delta color — semantic pairing, not decoration |
| Comparison table | Small labeled sub-section (e.g. "Recommended changes") containing a real `Parameter \| Current \| New` table | `.nst-table` (semantic) inside a shaded sub-block, or a repeated 3-col grid per row | Fills the "comparison" usability — current-vs-new / before-after content |
| Source → Target flow | Brand icon + label + value, arrow/chevron, second brand icon + label + value | composable from icon + label/value pair + a plain `→`/`»` glyph | For anything showing direction/movement (data flow, migration, handoff) |
| Status breakdown w/ parenthetical | "Delayed / 12(2 Running)" style — big number with a smaller qualifier in parens | plain text composition, no new class | Distinct from a plain metric — the parenthetical is a sub-status, not a unit |
| Tag chip row (+N overflow) | Row of neutral chips, last one reads "+3" | `.vw-chip--neutral` repeated, last instance = literal "+N" text | Convention, not a new component |
| Key-insight statement | One bold/larger line stating a finding (e.g. "13% resource can be saved") | plain text at `.vw-card-title`-adjacent weight, own line | Sits between two dividers in the Optimization/Insight archetype |
| Section label + divider | Bold mini-heading ("Planned Resources", "SMART") introducing a body block, divided from the next | plain bold text + `border-top` divider | The actual repeat unit for composite/health cards — stack as many as needed |

**Divider note**: no `.vw-divider` utility is registered — every divider in this catalog is a plain
`border-top: 1px solid var(--vw-color-gray-100/200)`. Fine to keep inline per "Filling a gap in the
utility layer," but common enough across this catalog to be worth a one-line utility eventually.

## 3. Footer pieces

| Piece | What it looks like | Mapping | Notes |
|---|---|---|---|
| Single timestamp | Clock icon + date, one line | icon + `.vw-card-metric-label-sub` | Simplest footer |
| Dual date + owner | Calendar+date (left), person+email (right) | two icon+text pairs, `.vw-flex.vw-justify-between` | Common on integration/flow cards |
| Dual identity | Two "role: name" pairs with avatar icons (Business owner / Operation owner) | two icon+label+value pairs | Common on composite/health cards |
| Dual-button actions | Secondary (outline) + Primary (filled), side by side | `.nst-btn` + `.nst-btn--filled` | Ends a card that needs a direct decision |
| Shaded warning-detail row | Warning icon + short label + description, on a tinted background band | icon + text on `--vw-color-gray-50`/`--vw-color-amber-50` bg | Closes the Optimization/Insight archetype |

---

## 4. Composed archetypes (starting silhouettes, not fixed templates)

| Archetype | Usability | Header | Body | Footer |
|---|---|---|---|---|
| Simple KPI | metric + trend | icon (top-right) + title | value + trend | — |
| KPI w/ description | metric + trend | icon + trend (header row) | value, divider, description | — |
| KPI w/ sparkline | metric + trend | title (+ optional info icon) | value + trend, sparkline | — |
| Entity summary (compact) | entity + status | icon + title + chip | value + trend | — |
| Entity summary (detailed) | entity + status + details | icon + title + chip + inline value | 4-col label/value grid, description | — |
| Integration/flow card | entity + description + tags | icon + title + kebab | description, 3-col property row, tag chips | dual date+owner |
| Integration/flow card (stat-list) | entity + description + stats | icon + title + chip + subtitle + kebab | description, vertical icon-stat list | dual date+owner |
| Process card (illustration) | entity + description | illustration + title + kebab | 3-col property row, description | — |
| Composite/health card | multi-metric status | icon + title + badge cluster | N repeated (section-label + grid/progress/breakdown), divided | dual identity |
| Multi-field entity (rich) | entity + status + details | title + subtitle + chip + toggle | 2-3 rows of 3-col grid, section label + grid, shaded section | — |
| Case/alert card | alert / action-required | title + chip | subtitle(ID), 3-col property row (one chip field), description | single timestamp |
| Pending-decision card | alert / action-required | info icon + title + subtitle + approve/reject buttons | description | shaded 4-col property strip (one field = tag) |
| Optimization/insight card | recommendation / insight | title + outline badge | divider, key-insight statement, divider | shaded warning-detail row |
| Comparison card | comparison | title + badge | 2-col property row, shaded comparison-table section | separate outcome-metric footer |
| Profile/identity card | profile | name + status chip + rating | subtitle(role), flexible 2-col label/value (mixed chip/plain), full-width row for long values | — |
| Flow/pipeline card | comparison / flow | title + subtitle + chip + toggle | Source→Target flow indicator, property grid | tag chips |
| Simple tile | simple tile | — | brand illustration zone (top) | name + date + kebab (bottom bar) |
| Action tile | simple tile | icon (centered) | label (centered) | — |
| Feature promo | recommendation / insight | icon (centered) | title + description (centered) | full-width button |
| Generic/fallback card | (base template) | checkbox + placeholder title | mixed label/value/tag grid | description |
| QR/link promo | simple tile | — | QR image, link text | button |

---

## 5. How to use this doc

1. Identify the content's **usability** (metric? entity+status? alert? comparison? profile?), not which module it superficially resembles.
2. Start from the closest archetype row above as a silhouette — header/body/footer combination.
3. Build each piece from its `vw-*`/`nst-*` mapping in section 1-3. If a piece maps to something in "Known registry gaps" below, use the documented token-only fallback for that gap, don't invent new classes.
4. Feel free to swap pieces the archetype table doesn't show together — the modular pieces are the source of truth, the archetype table is just a starting point, not an exhaustive enumeration.

## 6. Known registry gaps confirmed by this catalog

Cross-reference `COMPONENTS.md` → "Known registry gaps" — this catalog didn't find new gaps beyond
what was already logged, but it did supply real, concrete usage evidence and precise visual specs
for several:

- **Rating (star)** — 2 confirmed real usage contexts (header, footer)
- **Toggle switch** — confirmed real usage context (card-header enable/disable)
- **Checkbox** — confirmed real usage context (card-level selection)
- **Progress meter** — precise spec now available (heading+%, bar, 2 helper texts)
- **Sparkline/chart primitive** — precise spec now available (trend-colored gradient area)

Build these per "Filling a gap in the utility layer" (token-only, page-local) until they cross the
cross-app-recurrence bar in "Promoting a page-local pattern into the registry."
