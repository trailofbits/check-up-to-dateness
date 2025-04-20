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

# Get PR base sha using `gh`.
PR_BASE_SHA="$(gh api /repos/"$GITHUB_REPOSITORY"/pulls/"$N" | jq -r '.base.sha')"

# Check whether PR is up to date.
if git diff --quiet "$GITHUB_EVENT_MERGE_GROUP_BASE_SHA" "$PR_BASE_SHA"; then
    echo 'is-up-to-date=true' >> "$GITHUB_OUTPUT"
else
    echo 'is-up-to-date=false' >> "$GITHUB_OUTPUT"
fi
