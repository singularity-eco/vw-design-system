#!/usr/bin/env bash
# PostToolUse hook (Write|Edit) — warns Claude when a written/edited HTML/JSX/TSX
# file looks like it violates COMPONENTS.md's Forbidden list. Warn-only: never
# blocks (always exits 0). Tune the patterns below as false positives surface.
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

case "$file_path" in
  *.html|*.jsx|*.tsx) ;;
  *) exit 0 ;;
esac

[ -f "$file_path" ] || exit 0

# This design system's own reference/documentation material (preview/*.html
# specimens, the gallery pages, the Layer-2 Aurora prototype) is exempt — those
# files exist specifically to show raw tokens/hex/Inter for teaching purposes,
# not to consume the registry. The Forbidden-list rules are about *application*
# UI that should be using the registry, not the registry's own docs.
case "$file_path" in
  */preview/*|*/ui_kits/*) exit 0 ;;
esac

warnings=()

# Extract every class/className attribute value, split into individual tokens —
# checks below match whole tokens (anchored), never substrings, so "vw-card-section"
# can never collide with a bare "card" or "w-" pattern check.
tokens=$(grep -oE '(class|className)="[^"]*"' "$file_path" 2>/dev/null | sed -E 's/^(class|className)="//; s/"$//' | tr ' ' '\n' | grep -v '^$' || true)

# 1. Tailwind-style bare utility class tokens (bg-*, p-4, rounded-lg, etc.).
#    Anchored to the whole token, so vw-*/nst-* classes never match.
if [ -n "$tokens" ] && echo "$tokens" | grep -qE '^(bg|text|p|m|w|h|rounded|shadow|border|space-x|space-y)-[a-z0-9-]+$'; then
  warnings+=("- Possible Tailwind utility classes found. Tailwind is forbidden here — use the vw-*/nst-* registry classes from COMPONENTS.md instead.")
fi

# 2. Invented generic class names with a known registry equivalent. Exact-token match only.
if [ -n "$tokens" ] && echo "$tokens" | grep -qxE '(card|kpi-box|status-badge|btn-primary|badge)'; then
  warnings+=("- Invented class name detected (card/kpi-box/status-badge/btn-primary/badge). Check COMPONENTS.md for the registered vw-*/nst-* equivalent before inventing a new one.")
fi

# 3. Hardcoded hex color in an inline style attribute.
if grep -nE 'style="[^"]*(color|background)(-color)?[[:space:]]*:[[:space:]]*#[0-9a-fA-F]{3,8}' "$file_path" | grep -qE '.'; then
  warnings+=("- Hardcoded hex color found in an inline style attribute. Colors should come from colors.css/theme-tokens.css tokens; inline style is only for layout (max-width, grid-template-columns, etc).")
fi

# 4. Inter font. (preview/ and ui_kits/ — where Inter is legitimately used by the
#    Layer 2/Aurora atomic layer — are already excluded above.)
if grep -nE "font-family:[[:space:]]*['\"]?Inter" "$file_path" | grep -qE '.'; then
  warnings+=("- Inter font found. Layer 1/dashboard pages should use Poppins, not Inter — see CLAUDE.md.")
fi

# 5. A locally-defined parallel utility-class system — 5+ distinct classes sharing the
#    same non-vw/nst/is prefix inside a <style> block (e.g. a whole .pg-* family invented
#    to work around a missing typography utility). Heuristic, so the threshold is loose
#    on purpose — a couple of one-off page-scoped classes sharing a prefix is normal and
#    not what this is trying to catch.
style_block=$(sed -n '/<style/,/<\/style>/p' "$file_path" 2>/dev/null || true)
if [ -n "$style_block" ]; then
  top=$(echo "$style_block" \
    | grep -oE '^[[:space:]]*\.[a-zA-Z][a-zA-Z0-9_-]*' \
    | sed -E 's/^[[:space:]]*\.//' \
    | grep -vE '^(vw|nst|is)-' \
    | sed -E 's/-.*$//' \
    | sort | uniq -c | sort -rn | head -1 || true)
  top_count=$(echo "$top" | awk '{print $1}')
  top_prefix=$(echo "$top" | awk '{print $2}')
  if [ -n "$top_count" ] && [ "$top_count" -ge 5 ] 2>/dev/null; then
    warnings+=("- Found $top_count classes sharing the prefix \"$top_prefix-\" defined locally in a <style> block — looks like an invented parallel utility-class system. Use vw-*/nst-* classes, or fall back to var(--vw-font-*)/var(--vw-space-*) tokens via inline style (see COMPONENTS.md \"Filling a gap in the utility layer\") instead of a new naming convention.")
  fi
fi

if [ ${#warnings[@]} -eq 0 ]; then
  exit 0
fi

msg=$(printf '%s\n' "${warnings[@]}")
jq -n --arg file "$file_path" --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("Design-system check flagged possible issues in \($file):\n\($msg)\nThis is a warning, not a block — cross-check against COMPONENTS.md and fix if it is a real violation, or proceed if it is a false positive.")
  }
}'
