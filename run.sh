#! /bin/bash

set -x

set -euo pipefail

# Check whether event is 'merge-group'.
if [[ "$GITHUB_EVENT_NAME" != 'merge_group' ]]; then
    echo 'is-up-to-date=false' >> "$GITHUB_OUTPUT"
    exit
fi

# Get PR number.
N="$(expr "$GITHUB_REF" : '.*-\([0-9]\+\)-[^-]*$')"

# Get PR using `gh`.
PR="$(gh api /repos/"$GITHUB_REPOSITORY"/pulls/"$N")"

# Get PR head sha and base sha.
set +x
PR_HEAD_SHA="$(echo "$PR" | jq -r '.head.sha')"
PR_BASE_SHA="$(echo "$PR" | jq -r '.base.sha')"
set -x

# Verify PR has not changed since workflow started. (Thanks to @elopez for noticing this potential
# vulnerability.)
if ! git diff --quiet "$GITHUB_SHA" "$PR_HEAD_SHA"; then
    echo "PR has changed since workflow started." >&2
    exit 1
fi

# Check whether PR is up to date.
if git diff --quiet "$GITHUB_EVENT_MERGE_GROUP_BASE_SHA" "$PR_BASE_SHA"; then
    echo 'is-up-to-date=true' >> "$GITHUB_OUTPUT"
else
    echo 'is-up-to-date=false' >> "$GITHUB_OUTPUT"
fi
