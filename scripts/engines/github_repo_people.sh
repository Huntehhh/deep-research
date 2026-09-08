#!/usr/bin/env bash
# github_repo_people.sh -- "find the team / people behind this repo" (B2B / PEOPLE).
#
# DIFFERENT FROM THE KEYED WRAPPERS: uses the authenticated `gh` CLI (already
# logged in, 5,000 req/hr), NOT curl + an API key. No engine_common fallover.
#
# Usage: github_repo_people.sh <owner/repo>
#   e.g. github_repo_people.sh pipecat-ai/pipecat
#
# Output: JSON with the repo owner (login + type, and org details if it's an org)
# plus the top contributor logins. Fails gracefully if gh is missing or 404s.
set -eo pipefail 2>/dev/null || set -e

# Git Bash / MSYS2 on Windows rewrites a leading-slash arg ("/repos/...") into a
# filesystem path ("C:/Program Files/Git/repos/..."), which makes gh reject it as an
# invalid endpoint. We (a) omit the leading slash on every endpoint -- gh accepts
# the slashless form on all platforms -- and (b) set MSYS_NO_PATHCONV=1 as a
# belt-and-suspenders guard. Both are no-ops on real macOS/Linux bash.
export MSYS_NO_PATHCONV=1

REPO="${1:?Usage: github_repo_people.sh <owner/repo>}"

case "$REPO" in
  */*) : ;;
  *) echo "DR_FAILURE: engine=github reason=bad-arg (expected owner/repo, got '$REPO')" >&2; exit 1;;
esac
OWNER="${REPO%%/*}"

if ! command -v gh >/dev/null 2>&1; then
  echo "DR_FAILURE: engine=github reason=gh-cli-missing" >&2
  exit 1
fi

# Repo metadata (owner block). 404 -> graceful fail.
# NOTE: no leading slash on the endpoint (see MSYS2 comment above).
REPO_JSON="$(gh api "repos/$REPO" 2>/dev/null)" || {
  echo "DR_FAILURE: engine=github reason=repo-not-found-or-no-access ($REPO)" >&2
  exit 1
}

# Top 10 contributors (logins + contribution counts).
CONTRIB_JSON="$(gh api "repos/$REPO/contributors?per_page=10" 2>/dev/null)" || CONTRIB_JSON="[]"

# Owner detail: if it's an Organization, pull the org profile for richer context.
OWNER_TYPE="$(printf '%s' "$REPO_JSON" | jq -r '.owner.type // "unknown"')"
OWNER_DETAIL="{}"
if [ "$OWNER_TYPE" = "Organization" ]; then
  OWNER_DETAIL="$(gh api "orgs/$OWNER" 2>/dev/null)" || OWNER_DETAIL="{}"
fi

# Compose a single tidy JSON object for the router to consume.
jq -n \
  --argjson repo "$REPO_JSON" \
  --argjson contribs "$CONTRIB_JSON" \
  --argjson ownerdetail "$OWNER_DETAIL" \
  '{
    repo: $repo.full_name,
    description: $repo.description,
    stars: $repo.stargazers_count,
    owner: {
      login: $repo.owner.login,
      type: $repo.owner.type,
      name: ($ownerdetail.name // null),
      blog: ($ownerdetail.blog // null),
      location: ($ownerdetail.location // null),
      public_repos: ($ownerdetail.public_repos // null)
    },
    contributors: [ $contribs[] | {login: .login, contributions: .contributions, html_url: .html_url} ]
  }'
