#!/usr/bin/env bash
# linkup_search.sh -- Linkup web search results as JSON (POST /v1/search).
#
# Usage: linkup_search.sh <query> [depth]
#   <query>  natural-language search string (required)
#   [depth]  "standard" (agentic, fast, default) or "deep" (multi-iteration, slower)
#            Linkup also supports "fast" (sub-second, no LLM) -- pass it explicitly.
#
# Keys: LINKUP_API_KEY (primary), LINKUP_API_KEY_BACKUP (backup).
# Auth: header "Authorization: Bearer <key>".
# Index type: Linkup production web-search API. outputType=searchResults ->
#   returns a list of relevant documents (not a synthesized answer).
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

QUERY="${1:?Usage: linkup_search.sh <query> [depth]}"
DEPTH="${2:-standard}"

# Build request body with jq (shell-safe encoding).
BODY="$(jq -n \
  --arg q "$QUERY" \
  --arg depth "$DEPTH" \
  '{q:$q, depth:$depth, outputType:"searchResults"}')"

# Request fn: takes the api key as $1, appends -w for status capture.
_req() {
  curl -s -w '\n%{http_code}' -X POST "https://api.linkup.so/v1/search" \
    -H "Authorization: Bearer $1" \
    -H "Content-Type: application/json" \
    --max-time 45 \
    -d "$BODY"
}

dr_run_with_fallover "linkup" "LINKUP_API_KEY" "LINKUP_API_KEY_BACKUP" _req
