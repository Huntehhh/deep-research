#!/usr/bin/env bash
# serper_search.sh -- Google SERP results as JSON via Serper.dev (POST /search).
# CANONICAL REFERENCE WRAPPER -- new engine wrappers copy this shape exactly.
#
# Usage: serper_search.sh <query> [num] [tbs]
#   <query>  search string (required)
#   [num]    result count (default 10)
#   [tbs]    time filter, e.g. qdr:d (past day), qdr:w (past week) -- optional
#
# Keys: SERPER_API_KEY (primary), SERPER_API_KEY_BACKUP (backup).
# Index type: Google SERP wrapper. Free tier: 2,500 queries/mo per key.
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

QUERY="${1:?Usage: serper_search.sh <query> [num] [tbs]}"
NUM="${2:-10}"
TBS="${3:-}"

# Build request body with jq (shell-safe encoding; tbs added only when set).
BODY="$(jq -n --arg q "$QUERY" --argjson num "$(asnum "$NUM")" --arg tbs "$TBS" \
  '{q:$q, num:$num} + (if $tbs == "" then {} else {tbs:$tbs} end)')"

# Request fn: takes the api key as $1, appends -w for status capture.
_req() {
  curl -s -w '\n%{http_code}' -X POST "https://google.serper.dev/search" \
    -H "X-API-KEY: $1" \
    -H "Content-Type: application/json" \
    --max-time 30 \
    -d "$BODY"
}

dr_run_with_fallover "serper" "SERPER_API_KEY" "SERPER_API_KEY_BACKUP" _req
