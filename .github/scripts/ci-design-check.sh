#!/usr/bin/env bash
# CI entry point for design-system drift detection. Unlike the Claude Code
# PostToolUse hook (warn-only, fires per-edit inside a session), this runs once
# per PR and is a real gate: it fails the check if any changed HTML/JSX/TSX file
# trips a rule. Catches drift regardless of what wrote the code — a human, a
# different AI tool, anything — since it doesn't depend on the hook having been
# active during authoring.
#
# Shares its actual detection logic with the Claude Code hook via
# .claude/hooks/design-system-rules.sh — one source of truth for the checks.
#
# Usage: ci-design-check.sh <base-sha> <head-sha>
set -euo pipefail

base_sha="${1:?usage: ci-design-check.sh <base-sha> <head-sha>}"
head_sha="${2:?usage: ci-design-check.sh <base-sha> <head-sha>}"

# This script's own location tells us where design-system-rules.sh lives (the
# design-system checkout root) — NOT where the calling repo's files are. `git
# diff` below runs against the current working directory, which is the calling
# repo's root (set by the workflow's checkout step), so changed-file paths from
# it are resolved relative to cwd, never prefixed with this script's own path.
rules_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../.claude/hooks/design-system-rules.sh
source "$rules_root/.claude/hooks/design-system-rules.sh"

changed_files=$(git diff --name-only --diff-filter=ACMR "$base_sha" "$head_sha" -- '*.html' '*.jsx' '*.tsx' || true)

if [ -z "$changed_files" ]; then
  echo "No changed HTML/JSX/TSX files in this diff — nothing to check."
  exit 0
fi

any_findings=0
summary=""

while IFS= read -r file; do
  [ -n "$file" ] || continue
  [ -f "$file" ] || continue

  findings=$(ds_check_file "$file") || true
  if [ -n "$findings" ]; then
    any_findings=1
    echo "::group::$file"
    echo "$findings"
    echo "::endgroup::"
    while IFS= read -r line; do
      echo "::error file=$file::$line"
    done <<< "$findings"
    summary+=$'\n'"### \`$file\`"$'\n'
    while IFS= read -r line; do
      summary+="- $line"$'\n'
    done <<< "$findings"
  fi
done <<< "$changed_files"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  if [ "$any_findings" -eq 1 ]; then
    {
      echo "## Design-system check — violations found"
      echo "$summary"
      echo ""
      echo "Cross-check each against \`COMPONENTS.md\`. If a finding is a genuine false positive (e.g. an adjudicated component-shaped pattern, see \"Filling a gap in the utility layer\"), say so in the PR rather than silently reworking around the check."
    } >> "$GITHUB_STEP_SUMMARY"
  else
    echo "## Design-system check — clean" >> "$GITHUB_STEP_SUMMARY"
  fi
fi

if [ "$any_findings" -eq 1 ]; then
  echo ""
  echo "Design-system check found real or possible violations above. Fix them, or if a finding is a false positive, explain why in the PR description rather than editing around the check."
  exit 1
fi

echo "Design-system check: clean."
exit 0
