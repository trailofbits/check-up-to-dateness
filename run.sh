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

# Get PR head repo url and head sha using `gh`.
set +x
PR="$(gh api /repos/"$GITHUB_REPOSITORY"/pulls/"$N")"
PR_HEAD_REPO_URL="$(echo "$PR" | jq -r '.head.repo.clone_url')"
PR_HEAD_SHA="$(echo "$PR" | jq -r '.head.sha')"
set -x

# Check whether PR is up to date. (Thanks to @elopez for noticing a potential race condition in an
# earlier implementation that compared the merge group's base sha with the PR's base sha.)
git fetch "$PR_HEAD_REPO_URL" "$PR_HEAD_SHA"
if git diff --quiet "$GITHUB_SHA" "$PR_HEAD_SHA"; then
    echo 'is-up-to-date=true' >> "$GITHUB_OUTPUT"
else
    echo 'is-up-to-date=false' >> "$GITHUB_OUTPUT"
fi
