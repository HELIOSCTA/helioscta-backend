#!/usr/bin/env bash
# check-docs-updated.sh
# Fails if code files are changed without updating documentation.
# Works in two modes:
#   pre-commit hook: compares staged changes against HEAD
#   CI (pull request): compares PR branch against base branch
set -euo pipefail

# --- Determine diff targets ---
if [ "${CI:-}" = "true" ] && [ -n "${GITHUB_BASE_REF:-}" ]; then
  # CI mode: compare full PR diff against base branch
  BASE="origin/${GITHUB_BASE_REF}"
  ALL_CHANGED=$(git diff --name-only "$BASE"...HEAD)
else
  # Local pre-commit mode: compare staged changes against HEAD
  ALL_CHANGED=$(git diff --cached --name-only)
fi

# --- Split into docs vs non-docs ---
DOCS_CHANGED=$(echo "$ALL_CHANGED" | grep -E '^(docs/|README\.md)' || true)
NON_DOCS_CHANGED=$(echo "$ALL_CHANGED" | grep -vE '^(docs/|README\.md)' || true)

# --- No non-docs files changed? Pass (docs-only commit). ---
if [ -z "$NON_DOCS_CHANGED" ]; then
  exit 0
fi

# --- Docs were also updated? Pass. ---
if [ -n "$DOCS_CHANGED" ]; then
  exit 0
fi

# --- Fail with clear message ---
echo ""
echo "============================================================"
echo "  DOCS GATE FAILED"
echo "============================================================"
echo ""
echo "Code files were changed but no documentation was updated."
echo ""
echo "Changed files:"
echo "$NON_DOCS_CHANGED" | sed 's/^/  - /'
echo ""
echo "To pass this check, also update at least one of:"
echo "  - README.md  (repo root)"
echo "  - docs/*     (any file under docs/)"
echo ""
echo "============================================================"
exit 1
