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
    *.html|*.jsx|*.tsx) ;;
    *) return 0 ;;
  esac

  [ -f "$file_path" ] || return 0

  # This design system's own reference/documentation material (preview/*.html
  # specimens, the gallery pages, the Layer-2 Aurora prototype) is exempt — those
  # files exist specifically to show raw tokens/hex/Inter for teaching purposes,
  # not to consume the registry. The Forbidden-list rules are about *application*
  # UI that should be using the registry, not the registry's own docs.
  case "$file_path" in
    */preview/*|*/ui_kits/*) return 0 ;;
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

  if [ ${#warnings[@]} -eq 0 ]; then
    return 0
  fi

  printf '%s\n' "${warnings[@]}"
  return 1
}
