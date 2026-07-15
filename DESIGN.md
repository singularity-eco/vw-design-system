---
version: alpha
name: NST Design System (Vision Waves)
description: Enterprise dashboard / admin-console design system — Poppins on a pale-gray canvas, flat cards, pastel semantic chips, one brand blue reserved for primary actions.
colors:
  primary: "#1C81EF"
  primary-hover: "#4290ED"
  secondary: "#6b7280"
  neutral: "#f4f4f4"
  surface: "#ffffff"
  on-surface: "#1f2937"
  border: "#e2e8f0"
  success: "#047857"
  success-surface: "#ecfdf5"
  error: "#b91c1c"
  error-surface: "#fef2f2"
  warning: "#c2410c"
  warning-surface: "#fffae8"
  info: "#124e8e"
  info-surface: "#f5f9ff"
typography:
  heading-xl:
    fontFamily: Poppins
    fontSize: 20px
    fontWeight: 500
    lineHeight: 1.5
  heading-md:
    fontFamily: Poppins
    fontSize: 16px
    fontWeight: 500
    lineHeight: 1.5
  body-md:
    fontFamily: Poppins
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.4
  label-sm:
    fontFamily: Poppins
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.2
  value-xxl:
    fontFamily: Poppins
    fontSize: 32px
    fontWeight: 300
    lineHeight: 1
rounded:
  sm: 8px
  md: 12px
  lg: 16px
  full: 9999px
spacing:
  xxs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
  2xl: 24px
components:
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"
  chip-success:
    backgroundColor: "{colors.success-surface}"
    textColor: "{colors.success}"
    rounded: "{rounded.full}"
  chip-error:
    backgroundColor: "{colors.error-surface}"
    textColor: "{colors.error}"
    rounded: "{rounded.full}"
  chip-warning:
    backgroundColor: "{colors.warning-surface}"
    textColor: "{colors.warning}"
    rounded: "{rounded.full}"
  chip-info:
    backgroundColor: "{colors.info-surface}"
    textColor: "{colors.info}"
    rounded: "{rounded.full}"
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
    padding: 8px 16px
  button-primary-hover:
    backgroundColor: "{colors.primary-hover}"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "#374151"
    rounded: "{rounded.sm}"
    padding: 6px 8px
---

> **Relationship to this repo's other docs:** this file is a portable, tool-agnostic token export —
> it lets any DESIGN.md-reading AI tool (e.g. Google Stitch) pick up Vision Waves' real colors and
> type without re-entering them. It is **not** the source of truth for Claude Code or Cursor working
> in this repo — `COMPONENTS.md` is, because it names the literal CSS classes (`.vw-card-section`,
> `.nst-btn--filled`, etc.) this format has no way to express. If the two ever disagree on a value,
> `colors.css` / `spacing.css` / `typography-tokens.css` win; update this file to match, not the
> other way around.

## Overview

Vision Waves / NST is an enterprise dashboard and admin-console system — dense, data-first screens
for CRM, ops, and workflow products (deal pipelines, KPI boards, approval queues). The tone is terse
and state-driven: sentence case, past-tense status labels ("Closed won", "Pending approval"), no
marketing voice, no emoji. Visually it favors calm, low-chroma surfaces over ornamentation: flat
white cards on a pale-gray page, a single brand blue reserved for the one primary action per screen,
and pastel semantic colors for everything else.

## Colors

- **Primary (#1C81EF):** brand blue — filled buttons, active borders, selected controls. The sole
  driver for primary actions; hover *lightens* toward `#4290ED` rather than darkening.
- **Neutral (#F4F4F4):** page background and gray-button fill — distinguishes chrome from content.
- **Surface (#FFFFFF):** card, table, and input backgrounds. No gradients, no dark mode defined yet.
- **Success / Error / Warning / Info:** pastel background + darker text pairs, used for status chips
  and semantic card accents — never as large color blocks or full-bleed fills.

## Typography

Poppins only, Regular (400) and Medium (500) weights across the interface, with one deliberate
exception: KPI/metric numerals use weight 300 at a dedicated size scale (14px up to 36px) so the
largest numbers on a dashboard read as light and spacious rather than bold. Headings run 16–20px at
weight 500; body/description text is a fixed 14px.

## Layout

A 4pt spacing grid (4 / 8 / 12 / 16 / 20 / 24px), applied via gap utilities on flex/grid containers
rather than margins. Cards default to 16px internal padding. KPI/card boards use a responsive
auto-fill grid (`minmax(320px, 1fr)`) so cards reflow rather than overflow on narrow viewports.

## Elevation & Depth

Mostly flat: resting cards and tables carry a 1px hairline border, not a shadow — elevation is
reserved for floating elements only (tooltips, dropdown/action menus, popovers), which share a
single soft shadow token. There is no resting-state shadow anywhere in the system.

## Shapes

Radius ladder: 8px (buttons, inputs) → 12px (tables) → 16px (cards — the default) → pill/9999px
(chips, toggles). No sharp corners anywhere in the registry.

## Components

The values below are style tokens only — this format has no way to name a literal CSS class. For
the actual reusable classes (`.vw-card-section`, `.vw-chip--success`, `.nst-btn--filled`, etc.), see
`COMPONENTS.md`, which is the enforced source of truth for any agent generating UI in this repo.

## Do's and Don'ts

- Do use the primary blue for exactly one primary action per screen; everything else is neutral or
  semantic.
- Don't invent a class when a `.vw-card-*` / `.nst-*` equivalent exists — see `COMPONENTS.md`.
- Do keep dashboard/KPI pages on Poppins; Inter is reserved for the separate atomic/Figma layer only.
- Don't mix the Layer 1 (`vw-*`) and Layer 2 (`nst-*`) visual languages on the same screen without a
  deliberate reason.
- Do maintain WCAG AA contrast (4.5:1 normal text) for any new color pair — this repo's existing
  pairs have not yet been machine-verified against that bar.
