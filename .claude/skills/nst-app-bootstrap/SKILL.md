---
name: nst-app-bootstrap
description: Bootstraps a new or existing app repository to use the NST / Vision Waves design system (singularity-eco/vw-design-system) — adds it as a git submodule, wires up the app's CLAUDE.md, installs the nst-design-system UI-generation skill locally for both Claude Code and Cursor, installs the Claude Code enforcement hook and a GitHub Actions CI check, and scaffolds a minimal starter index.html. Use this whenever a user wants to start a new project on this design system, add nst-design-system to an existing repo, "set up the design system here", or asks how to wire this design system into another codebase. This is a one-time setup skill — once bootstrapped, use the nst-design-system skill itself to generate dashboards, cards, forms, and other UI.
user-invocable: true
---

# NST App Bootstrap

Wires a target app repo up to use the NST / Vision Waves design system, automating the manual submodule setup in `docs/claude-code-setup.md` (Option A). Run this once per app repo. After it's done, switch to `/nst-design-system` for all actual UI generation — this skill's job ends at wiring, not building screens.

## What this does

0. Re-fetches its own instructions fresh before doing anything else, so a stale globally-installed
   copy of this skill can never silently run outdated steps (see step 0 below for why this exists)
1. Ensures the target repo is a git repo (`git init` if it isn't one yet)
2. Adds the design system as a submodule at `design-system/`
3. Writes or extends the app's `CLAUDE.md` with a design-system pointer block
4. Copies `.claude/skills/nst-design-system/` into the app repo, so `/nst-design-system` works there directly — not only when working inside this repo
5. Copies `.cursor/rules/nst-design-system.mdc` + `.cursor/skills/nst-design-system/` into the app repo too, so Cursor gets the same auto-loaded rules Claude Code gets — not just Claude Code users
6. Installs the enforcement hook (`.claude/hooks/check-design-system.sh` + a `PostToolUse` entry in `.claude/settings.json`) so drift is caught automatically in this app too, not just in the design-system repo itself
7. Installs a CI check (`.github/workflows/design-system-check.yml`) that runs the same rules as a real gate on every PR — catches drift the hook can't, since the hook only fires inside a Claude Code session
8. Installs a session-start staleness check (`.claude/hooks/check-design-system-staleness.sh` + a `SessionStart` entry in `.claude/settings.json`) so the agent proactively flags — once per session, not per task — when this app's pinned copy has fallen behind `origin/main`, instead of drifting further behind with no signal. Works whether the design system is vendored as a submodule, a nested clone, or plain file copies
8b. Writes a `VERSION` pin next to the vendored copy — the only record of what's installed when there's no `.git`, and the one thing the staleness hook can read in that case
9. Scaffolds a minimal starter `index.html` — one `.vw-card-section` example, nothing more

Every step checks for existing state first and skips or merges instead of overwriting. This makes the skill safe to re-run on a repo that's already partially set up (e.g. it already has a `CLAUDE.md` for other purposes).

## Steps

### 0. Check for a newer version of this skill — review before adopting, never auto-execute silently

**This step exists because of a real, already-hit bug — and an earlier version of this exact fix
had a real security problem of its own, found by external review.** A global install of this
skill (`~/.claude/skills/nst-app-bootstrap`) is a static file copy. When this `SKILL.md` gets
updated upstream — as it has been more than once — every machine with an existing global copy
keeps silently running the old instructions forever: bootstrap still completes, still reports
success, and gives no error or version mismatch to signal that whole steps are missing.

The first fix for this (auto-clone, overwrite the global copy, immediately follow whatever came
back) solved staleness but introduced something worse: it fetched and blindly executed live,
unreviewed content from the network on every single run, with no pin, no diff, no confirmation —
a real supply-chain risk, not a hypothetical one. Fixed here: fetch, diff, show, confirm — never
fetch-and-blindly-follow in the same breath.

1. Fetch the current upstream version into a throwaway location. Don't touch the installed copy yet:
   ```bash
   rm -rf /tmp/nst-bootstrap-check
   git clone --depth 1 https://github.com/singularity-eco/vw-design-system.git /tmp/nst-bootstrap-check
   ```
2. Diff it against what's actually installed:
   ```bash
   diff ~/.claude/skills/nst-app-bootstrap/SKILL.md /tmp/nst-bootstrap-check/.claude/skills/nst-app-bootstrap/SKILL.md
   ```
3. **Identical (no diff output, or the fetch/diff commands fail — e.g. offline)** — clean up (`rm -rf /tmp/nst-bootstrap-check`) and continue with step 1 below, using the instructions already loaded for this invocation. Nothing to review, nothing to adopt.
4. **Different** — do not silently overwrite the installed copy, and do not silently keep running the old one either. Show the user the diff output and ask explicitly: adopt the new version now (overwrite `~/.claude/skills/nst-app-bootstrap/SKILL.md`, then re-read and follow it for the rest of this run), or continue this run on the currently-installed version and revisit later. Proceed only per their answer — never auto-adopt unreviewed changes to your own instructions, regardless of how minor the diff looks.
5. Clean up the temp clone either way: `rm -rf /tmp/nst-bootstrap-check`.

This keeps staleness self-correcting (every run checks) without the blind-execution risk the
original version had. It can't retroactively fix a copy that predates this step, though — that one
still needs a one-time manual refresh (`cp -r design-system/.claude/skills/nst-app-bootstrap
~/.claude/skills/nst-app-bootstrap` once a submodule exists, or a fresh clone if not) before this
check-first behavior applies to it.

### 1. Confirm the target and repo state

The target is the current working directory unless the user names another path. Run `git status`; if that fails because there's no repo yet, run `git init`. If there are uncommitted changes already in the target repo, don't touch them — this skill only adds new files, it never resets or discards.

### 2. Add the submodule

```bash
git submodule add https://github.com/singularity-eco/vw-design-system.git design-system
```

- If `design-system/` already exists as a submodule pointing at this same repo, skip this step.
- If `design-system/` exists but isn't a submodule (a plain directory, a different repo, or a symlink), stop and ask the user how they want to proceed — don't overwrite something you don't recognize.

### 3. Wire up CLAUDE.md

If the app has no `CLAUDE.md`, create one containing:

```markdown
## Design system
- Path: `design-system/` (git submodule → singularity-eco/vw-design-system)
- Before any UI work: read `design-system/COMPONENTS.md` — use listed components only
- Stylesheet: `design-system/nst-design-system.css` + Poppins font
- Skill: `.claude/skills/nst-design-system/SKILL.md` — invoke `/nst-design-system` when generating UI
- Do not invent colors, cards, chips, or class names — use `.vw-*` classes from the registry
- Updating the design system: `git submodule update --remote design-system`
```

If `CLAUDE.md` already exists (it usually will, describing the rest of the app), append this same block under its own `## Design system` heading instead of overwriting the file. Preserve everything already there.

### 4. Install the skill locally

```bash
mkdir -p .claude/skills
cp -r design-system/.claude/skills/nst-design-system .claude/skills/nst-design-system
```

This is what makes `/nst-design-system` available directly in the app repo, rather than only when someone happens to be working inside the `design-system/` submodule itself.

### 5. Install the Cursor rule + skill

```bash
mkdir -p .cursor/rules .cursor/skills
cp design-system/.cursor/rules/nst-design-system.mdc .cursor/rules/nst-design-system.mdc
cp -r design-system/.cursor/skills/nst-design-system .cursor/skills/nst-design-system
```

Skip a file that already exists rather than overwriting it — same rule as step 4. Without this
step, a dev opening the bootstrapped app in Cursor gets nothing auto-loaded at all (Cursor doesn't
read `CLAUDE.md` or `.claude/skills/`), even though the submodule and the registry are right there.
This is what makes the design system usable regardless of which tool a given developer on the team
prefers, not just Claude Code.

### 6. Install the enforcement hook

Writing to `.claude/settings.json` modifies Claude Code's own hook configuration — a
properly safety-configured session may correctly pause and ask for explicit confirmation
before doing this, even mid-bootstrap. That pause is expected, not a failure: confirm with
the user, then proceed. Don't try to route around it.

```bash
mkdir -p .claude/hooks
cp design-system/.claude/hooks/check-design-system.sh .claude/hooks/check-design-system.sh
chmod +x .claude/hooks/check-design-system.sh
```

The hook's own path-exclusion logic (skip `preview/`, `ui_kits/`) matches on `*/preview/*`/`*/ui_kits/*` wildcards, so it works correctly regardless of how deep it's nested — no edits needed to the script itself.

Then wire it into `.claude/settings.json`:

- **No `.claude/settings.json` yet** — create one:
  ```json
  {
    "hooks": {
      "PostToolUse": [
        {
          "matcher": "Write|Edit",
          "hooks": [
            { "type": "command", "command": "bash .claude/hooks/check-design-system.sh 2>/dev/null || true" }
          ]
        }
      ]
    }
  }
  ```
- **`.claude/settings.json` already exists** — merge this hook entry into the existing `hooks.PostToolUse` array (append, don't replace). Preserve every other hook, permission rule, and setting already there.
- Validate after writing: `jq -e '.hooks.PostToolUse[] | select(.matcher == "Write|Edit")' .claude/settings.json` should print the command back, not error.

This gives the app the same automatic drift-checking this repo has, without the app needing to build it from scratch.

### 7. Install the CI check

The hook from step 6 only fires inside a Claude Code session — it can't catch a human edit, a
different tool, or a merge that bypassed the assistant entirely. This step wires up a repo-level
gate that runs regardless of what wrote the code.

Only if the app has a GitHub remote (this is a GitHub Actions workflow — skip silently, no need to
ask, if there's no `.git/config` remote pointing at github.com):

```bash
mkdir -p .github/workflows
```

Write `.github/workflows/design-system-check.yml`:

```yaml
name: Design System Check

on:
  pull_request:

jobs:
  design-system-check:
    uses: singularity-eco/vw-design-system/.github/workflows/design-system-check.yml@main
    with:
      base-sha: ${{ github.event.pull_request.base.sha }}
      head-sha: ${{ github.event.pull_request.head.sha }}
```

If the file already exists, don't overwrite it — a repo that already has its own PR-check workflow
shouldn't have that clobbered; tell the user to add the `design-system-check` job to it by hand
instead. This calls the reusable workflow living in the design-system repo itself
(`.github/workflows/design-system-check.yml`, which shares its actual rules with the Claude Code
hook via `.claude/hooks/design-system-rules.sh` — one source of truth, two enforcement points). It
runs as a real failing check, not a warning, since there's no assistant session to just leave a
note for.

### 8. Install the session-start staleness check

A vendored copy doesn't auto-sync — pushing a commit to `vw-design-system` gives every app that
already pinned an older commit no signal at all that an update exists, until someone happens to
check by hand. This step closes that gap with a `SessionStart` hook: once per session start or
resume (never per-prompt, so it stays cheap), it resolves the app's pinned commit, compares it to
`origin/main`, and if the app is behind, injects that fact into context so the agent can ask the
user whether to update now or later — never updates silently either way.

**It handles all three vendoring shapes**, which matters because most real apps are not submodules:

| Shape | How the pin is read | Upstream resolved by |
|---|---|---|
| Submodule (`.git` is a gitlink file) | `git rev-parse HEAD` | `git fetch` |
| Nested clone (`.git` is a real directory, any path) | `git rev-parse HEAD` | `git fetch` |
| **Plain file copy (no `.git` at all)** | the `commit:` line in `VERSION` | `git ls-remote` — no clone needed |

The plain-copy case is not hypothetical: an app that lives inside the design system's own worktree
cannot `git submodule add` at all (it would resolve to the design system repo itself), so file
copies are the only option there. That shape is exactly why step 8b writes a `VERSION` file.

The hook searches the usual locations (`design-system/`, `frontend/design-system/`,
`src/assets/nst/`, `frontend/apps/*/src/assets/nst/`, and a few more); set
`NST_DESIGN_SYSTEM_DIR` if this app vendors it somewhere unusual. It is silent on every failure —
not found, offline, no pin — and never blocks session start.

Same settings.json caveat as step 6 — a properly safety-configured session may pause for
confirmation before writing to `.claude/settings.json`; that's expected, confirm and proceed.

```bash
mkdir -p .claude/hooks
cp design-system/.claude/hooks/check-design-system-staleness.sh .claude/hooks/check-design-system-staleness.sh
chmod +x .claude/hooks/check-design-system-staleness.sh
```

Then wire it into `.claude/settings.json` under `hooks.SessionStart` (merge — don't replace
`hooks.PostToolUse` from step 6):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/check-design-system-staleness.sh 2>/dev/null || true" }
        ]
      }
    ]
  }
}
```

Validate after writing: `jq -e '.hooks.SessionStart[0].hooks[0].command' .claude/settings.json` should print the command back, not error.

### 8b. Write a `VERSION` pin alongside the vendored copy

Write this into the vendored design-system directory. For a plain file copy it is the **only**
record of what's installed and the sole thing the staleness hook can read; for a submodule or clone
it costs nothing and makes the pin legible to a human who isn't going to run `git -C`.

```bash
DS_DIR=design-system   # or wherever this app vendors it
PINNED=$(git -C "$DS_DIR" rev-parse HEAD 2>/dev/null || echo "<paste the source commit SHA>")

cat > "$DS_DIR/VERSION" <<EOF
# NST / Vision Waves design system — vendored snapshot

source:   https://github.com/singularity-eco/vw-design-system
commit:   $PINNED
vendored: $(date -u +%Y-%m-%d)

Nothing here auto-updates. The SessionStart hook
(.claude/hooks/check-design-system-staleness.sh) reads the commit line above and
warns once per session when this copy falls behind origin/main — but it only
warns. Updating is always a deliberate act.

To refresh:
  - submodule:   git submodule update --remote $DS_DIR
  - nested clone: git -C $DS_DIR pull
  - plain copy:   re-copy the files, then update the commit line above

Check for drift by hand:
  git ls-remote https://github.com/singularity-eco/vw-design-system.git main

Stylesheets: import each layer individually, NOT the nst-design-system.css
bundle — Tailwind v4 resolves only one level of @import, so the bundle's nested
imports are dropped and every vw- class silently goes unstyled while nst-
classes keep working. See docs/ for the full write-up.
EOF
```

Keep the `commit:` line accurate. A stale pin is worse than no pin — it makes the hook confidently
report the wrong thing.

This hook is silent by design whenever there's nothing to report — no submodule, offline, or
already current — so a quiet session start means it ran and found nothing, not that it didn't run.

### 9. Scaffold a starter page

Only create `index.html` if the app has no HTML entry point yet — check for `index.html`, `src/index.html`, or a framework-specific entry (e.g. `src/App.tsx`, `pages/index.*`, `public/index.html`). If one already exists, skip this step and tell the user why, rather than clobbering their app's real entry point.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>App</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="design-system/nst-design-system.css">
</head>
<body style="margin:0;background:var(--vw-color-gray-50);padding:24px;">
  <div class="vw-card-section">
    <div class="vw-card-title">Design system connected</div>
    <div class="vw-card-description">Run /nst-design-system to start building UI.</div>
  </div>
</body>
</html>
```

Keep this page minimal on purpose — real screens are `/nst-design-system`'s job, which reads `COMPONENTS.md` and matches `preview/*.html` specimens before generating anything.

## After bootstrapping

Tell the user setup is complete, name the files you touched, and point them at `/nst-design-system` for the next step. Don't generate any dashboard, form, or card content yourself here — that's out of scope for this skill and belongs to the UI-generation skill, which has its own registry-driven workflow.

## Using this skill on a fresh machine

This skill lives inside the `vw-design-system` repo, which creates a chicken-and-egg problem: a brand-new app doesn't have the design system yet, so it can't have this skill yet either. Two ways around that, matching the patterns in `docs/claude-code-setup.md`:

- **Global install (do this once per machine):** `git clone https://github.com/singularity-eco/vw-design-system.git /tmp/vw-design-system && cp -r /tmp/vw-design-system/.claude/skills/nst-app-bootstrap ~/.claude/skills/ && rm -rf /tmp/vw-design-system` — after this, `/nst-app-bootstrap` is available in every project.
- **One-off:** clone `vw-design-system` anywhere, then run Claude Code from inside (or pointed at) the target app directory and reference this skill by its path.

Either way, the very first run executes step 0 above and leaves a self-refreshing global copy at
`~/.claude/skills/nst-app-bootstrap` behind — every run after the first re-syncs itself
automatically, so this manual install step only ever has to happen once, ever, regardless of how
many times this skill's own instructions change later.
