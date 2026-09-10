#!/usr/bin/env bash
# Shared design-system drift detection — sourced by both the Claude Code
# PostToolUse hook (check-design-system.sh) and the CI check
# (.github/scripts/ci-design-check.sh). One source of truth for the actual
# regex/heuristics, so the two callers can't drift out of sync with each other.
#
# Usage: source this file, then call `ds_check_file "$file_path"`.
# Prints one warning line per finding to stdout. Returns 0 if clean, 1 if any
# finding fired. Does NOT decide whether a caller should warn or block — that's
# the caller's job (the Claude Code hook always warns; CI treats findings as
# a real gate).

ds_check_file() {
  local file_path="$1"

  case "$file_path" in
    *.html|*.jsx|*.tsx|*.css) ;;
    *) return 0 ;;
  esac

  [ -f "$file_path" ] || return 0

  # This design system's own reference/documentation material (preview/*.html
  # specimens, the gallery pages, the Layer-2 Aurora prototype) is exempt — those
  # files exist specifically to show raw tokens/hex/Inter for teaching purposes,
  # not to consume the registry. The Forbidden-list rules are about *application*
  # UI that should be using the registry, not the registry's own docs.
  #
  # Both `*/preview/*` (path has a directory component before "preview") AND the
  # bare `preview/*` (path starts with "preview/", no leading component at all)
  # are needed: `*/preview/*` requires the literal substring "/preview/" to
  # appear, which a bare repo-root-relative path like "preview/x.html" does NOT
  # contain (no leading "/"). This is exactly the path shape `git diff
  # --name-only` produces in the CI check - without the bare-prefix case, the CI
  # gate would have incorrectly flagged every top-level preview/ui_kits file it
  # touched as a violation instead of exempting it.
  case "$file_path" in
    */preview/*|*/ui_kits/*|preview/*|ui_kits/*) return 0 ;;
  esac

  local warnings=()

  # Extract every class/className attribute value, split into individual tokens —
  # checks below match whole tokens (anchored), never substrings, so "vw-card-section"
  # can never collide with a bare "card" or "w-" pattern check.
  local tokens
  tokens=$(grep -oE '(class|className)="[^"]*"' "$file_path" 2>/dev/null | sed -E 's/^(class|className)="//; s/"$//' | tr ' ' '\n' | grep -v '^$' || true)

  # 1. Tailwind-style bare utility class tokens (bg-*, p-4, rounded-lg, etc.).
  #    Anchored to the whole token, so vw-*/nst-* classes never match.
  if [ -n "$tokens" ] && echo "$tokens" | grep -qE '^(bg|text|p|m|w|h|rounded|shadow|border|space-x|space-y)-[a-z0-9-]+$'; then
    warnings+=("Possible Tailwind utility classes found. Tailwind is forbidden here — use the vw-*/nst-* registry classes from COMPONENTS.md instead.")
  fi

  # 2. Invented generic class names with a known registry equivalent. Exact-token match only.
  if [ -n "$tokens" ] && echo "$tokens" | grep -qxE '(card|kpi-box|status-badge|btn-primary|badge)'; then
    warnings+=("Invented class name detected (card/kpi-box/status-badge/btn-primary/badge). Check COMPONENTS.md for the registered vw-*/nst-* equivalent before inventing a new one.")
  fi

  # 3. Hardcoded hex color in an inline style attribute.
  if grep -nE 'style="[^"]*(color|background)(-color)?[[:space:]]*:[[:space:]]*#[0-9a-fA-F]{3,8}' "$file_path" | grep -qE '.'; then
    warnings+=("Hardcoded hex color found in an inline style attribute. Colors should come from colors.css/theme-tokens.css tokens; inline style is only for layout (max-width, grid-template-columns, etc).")
  fi

  # 4. Inter font. (preview/ and ui_kits/ — where Inter is legitimately used by the
  #    Layer 2/Aurora atomic layer — are already excluded above.)
  if grep -nE "font-family:[[:space:]]*['\"]?Inter" "$file_path" | grep -qE '.'; then
    warnings+=("Inter font found. Layer 1/dashboard pages should use Poppins, not Inter — see CLAUDE.md.")
  fi

  # 5. A locally-defined parallel utility-class system — 5+ distinct classes sharing the
  #    same non-vw/nst/is prefix inside a <style> block (e.g. a whole .pg-* family invented
  #    to work around a missing typography utility). Heuristic, so the threshold is loose
  #    on purpose — a couple of one-off page-scoped classes sharing a prefix is normal and
  #    not what this is trying to catch.
  local style_block
  style_block=$(sed -n '/<style/,/<\/style>/p' "$file_path" 2>/dev/null || true)
  if [ -n "$style_block" ]; then
    local top top_count top_prefix
    top=$(echo "$style_block" \
      | grep -oE '^[[:space:]]*\.[a-zA-Z][a-zA-Z0-9_-]*' \
      | sed -E 's/^[[:space:]]*\.//' \
      | grep -vE '^(vw|nst|is)-' \
      | sed -E 's/-.*$//' \
      | sort | uniq -c | sort -rn | head -1 || true)
    top_count=$(echo "$top" | awk '{print $1}')
    top_prefix=$(echo "$top" | awk '{print $2}')
    if [ -n "$top_count" ] && [ "$top_count" -ge 5 ] 2>/dev/null; then
      warnings+=("Found $top_count classes sharing the prefix \"$top_prefix-\" defined locally in a <style> block — looks like an invented parallel utility-class system. Use vw-*/nst-* classes, or fall back to var(--vw-font-*)/var(--vw-space-*) tokens via inline style (see COMPONENTS.md \"Filling a gap in the utility layer\") instead of a new naming convention.")
    fi
  fi

  # 6. `.vw-page-gap`/`.vw-gap-*` applied without a flex/grid display class on the same
  #    element. `gap` only affects flex/grid containers — on a bare block element it's a
  #    silent no-op (no console error, no visual difference, and the hook would otherwise
  #    stay quiet since the class name itself is spelled correctly). Per-element check
  #    (unlike checks 1/2/4, which use the flattened token list) since only the specific
  #    element missing a display class is wrong, not the whole file. Can't see an
  #    equivalent `style="display:flex"` on the same tag — that's a known false-positive
  #    case, see COMPONENTS.md "Common gotcha".
  local class_attrs bad_gap_count attr
  class_attrs=$(grep -oE '(class|className)="[^"]*"' "$file_path" 2>/dev/null | sed -E 's/^(class|className)="//; s/"$//' || true)
  bad_gap_count=0
  if [ -n "$class_attrs" ]; then
    while IFS= read -r attr; do
      [ -n "$attr" ] || continue
      if echo "$attr" | grep -qE '(^|[[:space:]])(vw-page-gap(-[a-z]+)?|vw-gap-[a-z]+)([[:space:]]|$)'; then
        if ! echo "$attr" | grep -qE '(^|[[:space:]])(vw-flex|vw-inline-flex|vw-grid)([[:space:]]|$)'; then
          bad_gap_count=$((bad_gap_count + 1))
        fi
      fi
    done <<< "$class_attrs"
  fi
  if [ "$bad_gap_count" -gt 0 ]; then
    warnings+=("Found $bad_gap_count element(s) with a vw-page-gap/vw-gap-* class but no vw-flex/vw-inline-flex/vw-grid class on the same element — gap only works on a flex/grid container, so this is likely a silent no-op. See COMPONENTS.md \"Common gotcha\" (if display is set via inline style instead of a class, this is a false positive).")
  fi

  # 7. Raw px font-size where a matching var(--vw-font-*) token already exists.
  #    typography-tokens.css defines exactly these sizes: 11/12/14/16/18/20/
  #    24/28/32/36px. Matches the literal substring "font-size:Npx" regardless
  #    of surrounding syntax, so one regex covers both an inline
  #    style="font-size:12px" attribute (HTML/JSX) and a bare CSS-file
  #    declaration (font-size: 12px; in a .css file or a <style> block) —
  #    found via a real consuming app whose whole page-local gaps.css (31
  #    font-size declarations, 0 tokenized) drifted this way silently, since
  #    no check here ever looked at font-size before this one. Deliberately
  #    conservative: only fires on an EXACT token-size match, never a near
  #    miss (13px/15px/etc. have no token and are correctly left alone — see
  #    COMPONENTS.md "Filling a gap in the utility layer").
  local fs_hits fs_count fs_sizes n hit
  fs_hits=$(grep -oE 'font-size:[[:space:]]*[0-9]+px' "$file_path" 2>/dev/null || true)
  fs_count=0
  fs_sizes=""
  if [ -n "$fs_hits" ]; then
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      n=$(echo "$hit" | grep -oE '[0-9]+')
      case "$n" in
        11|12|14|16|18|20|24|28|32|36)
          fs_count=$((fs_count + 1))
          fs_sizes="$fs_sizes ${n}px"
          ;;
      esac
    done <<< "$fs_hits"
  fi
  if [ "$fs_count" -gt 0 ]; then
    local fs_sizes_sorted
    fs_sizes_sorted=$(echo "$fs_sizes" | tr ' ' '\n' | grep -v '^$' | sort -u -n | xargs)
    warnings+=("Found $fs_count raw px font-size value(s) ($fs_sizes_sorted) matching an existing var(--vw-font-*) token size — use the token instead of a literal value (e.g. 12px -> var(--vw-font-label-sm) or var(--vw-font-legend), 14px -> var(--vw-font-description) or var(--vw-font-label-md)). See COMPONENTS.md \"Filling a gap in the utility layer.\"")
  fi

  # 8. Premature CSS comment close via a class-family glob. Writing "vw-*/nst-*" inside a
  #    comment (shorthand for "vw-* or nst-*") ends the comment early at that "*/" — every
  #    character after it is then parsed as CSS, so the browser silently DROPS the next rule
  #    and a whole component renders unstyled with NO console error (this cost a full
  #    debugging session on a real app: .app-shell{display:flex} was dropped, the shell fell
  #    back to display:block, and every page's content was pushed off-screen).
  #    Matches specifically "-*/[letter]" — a hyphenated token ending "-*" immediately
  #    followed by "/" and another identifier — the actual glob-shorthand shape, NOT every
  #    "*/" that happens to be followed by a letter. A plain comment closing right before the
  #    next selector with no space (e.g. "} /* done */.bar {") is completely valid CSS and
  #    must not fire here; an earlier, broader version of this check («\*/[A-Za-z.]») flagged
  #    exactly that as a false positive. Scanned whole on .css files, and only inside <style>
  #    blocks on .tsx/.jsx/.html (so an ordinary JS block comment ending right before code
  #    never false-positives).
  local comment_scan
  case "$file_path" in
    *.css) comment_scan=$(cat "$file_path" 2>/dev/null || true) ;;
    *)     comment_scan="$style_block" ;;
  esac
  if [ -n "$comment_scan" ] && printf '%s\n' "$comment_scan" | grep -qE -- '-\*/[A-Za-z.]'; then
    warnings+=("A '*/' inside a CSS comment closes it early (e.g. the glob in \"vw-*/nst-*\") and silently drops the very next CSS rule — the component renders unstyled with no console error. In comments, write class families WITHOUT the trailing asterisk: \"vw- or nst-\". See uiux-dev.md rule 3.")
  fi

  if [ ${#warnings[@]} -eq 0 ]; then
    return 0
  fi

  printf '%s\n' "${warnings[@]}"
  return 1
}
