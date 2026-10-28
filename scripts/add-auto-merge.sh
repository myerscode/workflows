#!/usr/bin/env bash
#
# add-auto-merge.sh — add the shared Dependabot auto-merge caller to a repo.
#
# Clones REPO to a temp dir, writes the caller workflow (and a dependabot.yml
# if the repo has none), pushes a branch and opens a PR. Does NOT commit for
# you with a signature — it stages and prints the exact `git commit -S` command
# to run, matching the git-commit skill. Never pushes to a protected branch.
#
# Usage:
#   scripts/add-auto-merge.sh <owner/repo> [ref]
#   scripts/add-auto-merge.sh myerscode/config develop
#
# ref defaults to "v1" (the shared workflow tag). Pass "develop" while testing.
#
# Requires: gh (authenticated), git.
set -euo pipefail

REPO="${1:?usage: add-auto-merge.sh <owner/repo> [ref]}"
REF="${2:-v1}"
WORKDIR="${KIROCREW_SCRATCH:-/tmp}/add-auto-merge-$$"

echo "Rolling auto-merge (@$REF) into $REPO ..."
git clone --depth 1 "git@github.com:${REPO}.git" "$WORKDIR"
cd "$WORKDIR"

git checkout -b ci/dependabot-auto-merge
mkdir -p .github/workflows

cat > .github/workflows/dependabot-auto-merge.yml <<YAML
# Calls the shared myerscode/workflows Dependabot auto-merge workflow.
name: Dependabot auto-merge

on:
  pull_request_target:

permissions:
  contents: write
  pull-requests: write

jobs:
  automerge:
    uses: myerscode/workflows/.github/workflows/dependabot-auto-merge.yml@${REF}
    with:
      merge-method: squash
      highest-auto-merge: minor
      approve: true
      resolve-conflicts: recreate
YAML

# Only add a dependabot.yml if the repo lacks one (don't clobber existing config).
if [ ! -f .github/dependabot.yml ]; then
  cat > .github/dependabot.yml <<'YAML'
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
YAML
  echo "  (added a starter .github/dependabot.yml — adjust ecosystems per repo)"
else
  echo "  (repo already has .github/dependabot.yml — left untouched)"
fi

git add .github/
echo
echo "Staged in $WORKDIR. Review, then commit (signed) and push:"
echo
echo "  cd $WORKDIR"
echo "  git commit -S -m \"feat(ci): add shared dependabot auto-merge\""
echo "  git push -u origin ci/dependabot-auto-merge"
echo "  gh pr create --repo $REPO --base main --head ci/dependabot-auto-merge \\"
echo "    --title \"feat(ci): add shared dependabot auto-merge\" --body \"Wires in myerscode/workflows auto-merge @${REF}.\""
