#!/usr/bin/env bash
# SessionStart hook — warns when a consuming app's copy of this design system is
# behind origin, so the agent can ask the user whether to update. Fires once per
# session start/resume, NOT per prompt.
#
# WHY THIS IS MORE THAN A SUBMODULE CHECK
# An earlier version looked for exactly one thing: a git submodule at exactly
# `design-system/`. Neither real consuming app we have is that shape, so it exited
# on its second line and never once fired — which is why two independently built
# apps sat 9 commits behind without knowing. One of them documented our own gap
# back to us, in its VERSION file: "nothing auto-updates and nothing warns when
# this falls behind."
#
# Three shapes exist in the wild, and all three are handled here:
#   1. submodule   — .git is a FILE (gitlink into the superproject)
#   2. nested clone— .git is a DIRECTORY, real remote, just not at the root path
#   3. plain copy  — no .git at all; the pinned commit lives in a VERSION file
#
# Shape 3 has no local git to fetch with, so it resolves upstream via
# `git ls-remote`, which needs no clone. It can only report "pinned X, latest Y
# differ" — no commit count, no log — and says so rather than implying more.
#
# Deliberately silent on every failure (not found, offline, no VERSION pin, no
# jq). This must never block or noisily interrupt session start. Nothing here
# writes: `git fetch` only updates refs/remotes/*, and ls-remote is read-only.
set -uo pipefail

REPO_URL_DEFAULT="https://github.com/singularity-eco/vw-design-system.git"

command -v jq >/dev/null 2>&1 || exit 0

# 5s cap so a flaky network can never stall session start. `timeout` is GNU
# coreutils and isn't on stock macOS (only `gtimeout` via brew) — fall back to
# running unguarded rather than dying on "command not found", which would
# silently disable the whole hook on macOS.
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout 5"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout 5"
fi

# ── Locate the vendored design system ────────────────────────────────────────
# COMPONENTS.md and VERSION are the two markers present across every vendoring
# shape seen so far, including partial copies that ship no CSS at all.
is_ds_dir() { [ -f "$1/COMPONENTS.md" ] || [ -f "$1/VERSION" ]; }

# Read whatever commit a directory is pinned to, whichever shape it is.
pinned_sha() {
  if [ -e "$1/.git" ]; then
    git -C "$1" rev-parse HEAD 2>/dev/null && return
  fi
  if [ -f "$1/VERSION" ]; then
    grep -iE '^[[:space:]]*commit:' "$1/VERSION" 2>/dev/null \
      | head -1 | grep -oE '[0-9a-f]{7,40}' | head -1
  fi
}

# Collect EVERY vendored copy, not just the first. Apps commonly keep two — a
# clone/submodule to pull into, plus a plain copy under src/assets that is the
# one the bundler actually imports. Stopping at the first match reports on the
# clone, so a `git pull` that was never re-copied downstream reads as "up to
# date" while the build still compiles the old CSS.
DS_DIRS=""
if [ -n "${NST_DESIGN_SYSTEM_DIR:-}" ] && is_ds_dir "${NST_DESIGN_SYSTEM_DIR}"; then
  DS_DIRS="$NST_DESIGN_SYSTEM_DIR"
else
  for cand in \
    design-system \
    frontend/design-system \
    src/assets/nst \
    frontend/src/assets/nst \
    vendor/design-system \
    packages/design-system \
    frontend/apps/*/src/assets/nst \
    apps/*/src/assets/nst
  do
    if is_ds_dir "$cand"; then DS_DIRS="$DS_DIRS $cand"; fi
  done
fi
DS_DIRS=$(echo "$DS_DIRS" | tr ' ' '\n' | grep -v '^$' || true)
DS_DIR=$(echo "$DS_DIRS" | head -1)
[ -n "$DS_DIR" ] || exit 0

# ── Copies that disagree with each other ─────────────────────────────────────
# This outranks staleness against upstream: if two vendored copies are pinned to
# different commits, updating from upstream cannot fix it and the build is
# already using something other than what the clone says it is.
if [ "$(echo "$DS_DIRS" | wc -l | tr -d ' ')" -gt 1 ]; then
  drift_report=""
  base_sha=""
  drifted=0
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    s=$(pinned_sha "$d")
    [ -n "$s" ] || continue
    drift_report="${drift_report}  ${d}/ — ${s:0:7}
"
    if [ -z "$base_sha" ]; then base_sha="$s"
    else
      n=${#s}; m=${#base_sha}
      [ "$n" -lt "$m" ] && m=$n
      [ "${s:0:$m}" = "${base_sha:0:$m}" ] || drifted=1
    fi
  done <<EOF
$DS_DIRS
EOF
  if [ "$drifted" = "1" ]; then
    jq -n --arg report "$drift_report" '{
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: (
          "This project vendors the NST design system in more than one place, and the copies are pinned to DIFFERENT commits:\n\n\($report)\nWhichever one the bundler imports is what actually ships — check the app'"'"'s CSS entrypoint (@import paths) to see which that is. Pulling from upstream will not reconcile these; the newer copy has to be propagated to the other.\n\nAt the start of this session, raise this with the user and ask which copy is authoritative. Don'"'"'t reconcile them silently."
        )
      }
    }'
    exit 0
  fi
fi

# Don't fire inside the design system's own repo — a maintainer working here is
# not a consumer with a stale copy.
[ -f "$DS_DIR/COMPONENTS.md" ] && [ -f "./COMPONENTS.md" ] && [ "$DS_DIR" = "." ] && exit 0
[ -d "./.git" ] && [ -f "./COMPONENTS.md" ] && [ -f "./nst-design-system.css" ] && exit 0

# ── Resolve the pinned commit ────────────────────────────────────────────────
VERSION_FILE="$DS_DIR/VERSION"
REPO_URL="$REPO_URL_DEFAULT"
if [ -f "$VERSION_FILE" ]; then
  url_line=$(grep -iE '^[[:space:]]*source:' "$VERSION_FILE" 2>/dev/null | grep -oE 'https?://[^[:space:]]+' | head -1)
  [ -n "$url_line" ] && REPO_URL="$url_line"
fi

SHAPE=""
LOCAL_SHA=""
if [ -e "$DS_DIR/.git" ]; then
  LOCAL_SHA=$(git -C "$DS_DIR" rev-parse HEAD 2>/dev/null || true)
  if [ -n "$LOCAL_SHA" ]; then
    if [ -f "$DS_DIR/.git" ]; then SHAPE="submodule"; else SHAPE="clone"; fi
  fi
fi
if [ -z "$LOCAL_SHA" ] && [ -f "$VERSION_FILE" ]; then
  LOCAL_SHA=$(grep -iE '^[[:space:]]*commit:' "$VERSION_FILE" 2>/dev/null | head -1 | grep -oE '[0-9a-f]{7,40}' | head -1 || true)
  [ -n "$LOCAL_SHA" ] && SHAPE="copy"
fi
[ -n "$LOCAL_SHA" ] || exit 0

# ── Resolve upstream ─────────────────────────────────────────────────────────
BEHIND_COUNT=""
BEHIND_LOG=""
REMOTE_SHA=""
DEFAULT_BRANCH="main"

if [ "$SHAPE" = "submodule" ] || [ "$SHAPE" = "clone" ]; then
  b=$(git -C "$DS_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)
  [ -n "$b" ] && DEFAULT_BRANCH="$b"
  $TIMEOUT_BIN git -C "$DS_DIR" fetch origin "$DEFAULT_BRANCH" --quiet 2>/dev/null || exit 0
  REMOTE_SHA=$(git -C "$DS_DIR" rev-parse "origin/$DEFAULT_BRANCH" 2>/dev/null || true)
  [ -n "$REMOTE_SHA" ] || exit 0
  [ "$LOCAL_SHA" = "$REMOTE_SHA" ] && exit 0
  BEHIND_COUNT=$(git -C "$DS_DIR" rev-list --count "HEAD..origin/$DEFAULT_BRANCH" 2>/dev/null || true)
  BEHIND_LOG=$(git -C "$DS_DIR" log --oneline "HEAD..origin/$DEFAULT_BRANCH" 2>/dev/null | head -5 || true)
else
  # Plain copy: no local git object store, so resolve the tip without cloning.
  REMOTE_SHA=$($TIMEOUT_BIN git ls-remote "$REPO_URL" "refs/heads/$DEFAULT_BRANCH" 2>/dev/null | awk '{print $1}' | head -1 || true)
  [ -n "$REMOTE_SHA" ] || exit 0
  # The pin may be abbreviated, so compare on the shorter of the two lengths.
  n=${#LOCAL_SHA}
  [ "$n" -gt 0 ] && [ "${REMOTE_SHA:0:$n}" = "$LOCAL_SHA" ] && exit 0
fi

# ── Report ───────────────────────────────────────────────────────────────────
if [ "$SHAPE" = "copy" ]; then
  DETAIL="This is a plain file copy (no .git), so the pinned commit was read from $VERSION_FILE and upstream resolved via ls-remote. That means no commit count or changelog is available here — only that the two differ."
  ACTION="re-copy the files from $REPO_URL and update the commit line in $VERSION_FILE"
else
  DETAIL="Recent upstream commits:
$BEHIND_LOG"
  if [ "$SHAPE" = "submodule" ]; then
    ACTION="git submodule update --remote $DS_DIR"
  else
    ACTION="git -C $DS_DIR pull"
  fi
fi

COUNT_TEXT="behind"
[ -n "$BEHIND_COUNT" ] && COUNT_TEXT="$BEHIND_COUNT commit(s) behind"

jq -n \
  --arg dir "$DS_DIR" \
  --arg shape "$SHAPE" \
  --arg count "$COUNT_TEXT" \
  --arg local "${LOCAL_SHA:0:7}" \
  --arg remote "${REMOTE_SHA:0:7}" \
  --arg branch "$DEFAULT_BRANCH" \
  --arg detail "$DETAIL" \
  --arg action "$ACTION" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: (
        "The vendored NST design system at \($dir)/ (\($shape)) is \($count) origin/\($branch) — pinned \($local), latest \($remote).\n\n\($detail)\n\nAt the start of this session, ask the user whether to update now (\($action), then re-read \($dir)/COMPONENTS.md for anything new before relying on it) or stay pinned for now. Don'\''t update silently either way — this is a one-time touchbase for this session, not a per-task check."
      )
    }
  }'
