#!/usr/bin/env bash
#
# kick-stuck-prs.sh — nudge stuck Dependabot PRs so auto-merge can complete.
#
# For every open Dependabot PR in REPO, inspect its merge state and:
#   BEHIND -> comment "@dependabot rebase"
#   DIRTY  -> comment "@dependabot recreate" (rebuilds the branch from scratch)
# CLEAN / UNSTABLE / BLOCKED PRs are left alone (auto-merge handles them).
#
# Usage:
#   scripts/kick-stuck-prs.sh <owner/repo>
#   scripts/kick-stuck-prs.sh myerscode/learn.tf
#
# Requires: gh (authenticated), jq.
set -euo pipefail

REPO="${1:?usage: kick-stuck-prs.sh <owner/repo>}"

echo "Scanning open Dependabot PRs in $REPO..."
prs=$(gh pr list --repo "$REPO" --author "app/dependabot" --state open \
        --json number,mergeStateStatus,title)

count=$(echo "$prs" | jq 'length')
if [ "$count" -eq 0 ]; then
  echo "No open Dependabot PRs."
  exit 0
fi

echo "$prs" | jq -c '.[]' | while read -r pr; do
  num=$(echo "$pr" | jq -r '.number')
  state=$(echo "$pr" | jq -r '.mergeStateStatus')
  title=$(echo "$pr" | jq -r '.title')

  case "$state" in
    BEHIND)
      echo "  #$num [$state] rebase -> $title"
      gh pr comment "$num" --repo "$REPO" --body "@dependabot rebase"
      ;;
    DIRTY)
      echo "  #$num [$state] recreate -> $title"
      gh pr comment "$num" --repo "$REPO" --body "@dependabot recreate"
      ;;
    *)
      echo "  #$num [$state] skip -> $title"
      ;;
  esac
done

echo "Done."
