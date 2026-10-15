#!/usr/bin/env bash
# Local hook: validates the branch name against the standard
#   feature/DEVOPS-NN-description | fix/DEVOPS-NN... | hotfix/DEVOPS-NN...
set -euo pipefail

branch="$(git symbolic-ref --short -q HEAD || true)"

# Detached HEAD (e.g. CI checkout) has no name to validate.
# main is allowed here: the no-commit-to-branch hook is the one that guards it.
if [ -z "$branch" ] || [ "$branch" = "main" ]; then
  exit 0
fi

pattern='^(feature/[A-Z]+-[0-9]+-[a-z0-9-]+|fix/[A-Z]+-[0-9]+.*|hotfix/[A-Z]+-[0-9]+.*)$'

if ! printf '%s' "$branch" | grep -Eq "$pattern"; then
  echo "Invalid branch name: '$branch'" >&2
  echo "Expected: feature/DEVOPS-NN-description, fix/DEVOPS-NN or hotfix/DEVOPS-NN" >&2
  echo "Rename it with: git branch -m feature/DEVOPS-NN-description" >&2
  exit 1
fi
