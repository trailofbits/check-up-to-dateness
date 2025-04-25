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

# Get PR `updated_at` and `base.sha` using `gh`.
set +x
PR="$(gh api /repos/"$GITHUB_REPOSITORY"/pulls/"$N")"
PR_UPDATED_AT="$(echo "$PR" | jq -r '.updated_at')"
PR_BASE_SHA="$(echo "$PR" | jq -r '.base.sha')"
set -x

# smoelius: The original implementation compared just the merge group base sha with the PR base
# sha. However, @elopez observed:
#
# > Imagine I open a PR with an outdated branch base, and I know that when merging on the newer main
# > commit, it will cause things to fail. But you request the merge and I promptly rebase it and
# > force push, and your check then sees the rebased branch and opts to skip testing, merging and
# > breaking the main branch.
#
# Note that comparing the merge group head sha with the PR head sha would have the same problem. If
# you think through it, @elopez's attack still works.
#
# Ideally, there would be something in the `merge_group` event that ties it to the state of the PR
# at the time the `merge_group` event was triggered.
#
# Having found not such thing, the current implementation compares the time when the current
# workflow started to the time when the PR was last updated.
#
# UPDATE: It appears that GitHub locks a branch after it has been queued for merge:
#
# > remote: - A pull request for this branch has been added to a merge queue. Branches that
# > remote:   are queued for merging cannot be updated. To modify this branch, dequeue the
# > remote:   associated pull request.
#
# Nonetheless, I am keeping the additional checks for sanity.

# Get merge group commit check-runs using `gh`. Approach based on:
# https://stackoverflow.com/a/76465815
set +x
CHECK_RUNS="$(gh api repos/"$GITHUB_REPOSITORY"/commits/"$GITHUB_SHA"/check-runs)"
TOTAL_COUNT="$(echo "$CHECK_RUNS" | jq -r '.total_count')"
if [[ "$TOTAL_COUNT" != 1 ]]; then
    echo "::warning::Unexpected number of check-runs for commit $GITHUB_SHA: $TOTAL_COUNT"
    echo 'is-up-to-date=false' >> "$GITHUB_OUTPUT"
    exit
fi
CHECK_RUN_STARTED_AT="$(echo "$CHECK_RUNS" | jq -r '.check_runs[0].started_at')"
set -x

PR_UPDATED_AT_TIMESTAMP="$(date -d "$PR_UPDATED_AT" '+%s')"
CHECK_RUN_STARTED_AT_TIMESTAMP="$(date -d "$CHECK_RUN_STARTED_AT" '+%s')"

# Verify PR has not changed since workflow started.
if [[ "$PR_UPDATED_AT_TIMESTAMP" -ge "$CHECK_RUN_STARTED_AT_TIMESTAMP" ]]; then
    echo "::error::PR $N has changed since workflow started"
    exit 1
fi

# Check whether PR is up to date.
if ! git diff --quiet "$GITHUB_EVENT_MERGE_GROUP_BASE_SHA" "$PR_BASE_SHA"; then
    echo 'is-up-to-date=false' >> "$GITHUB_OUTPUT"
    exit
fi

echo 'is-up-to-date=true' >> "$GITHUB_OUTPUT"

# smoelius: Uncomment the next line when testing.
# exit 1
