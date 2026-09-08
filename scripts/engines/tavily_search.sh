#!/usr/bin/env bash
# tavily_search.sh -- Tavily Search API results as JSON (POST /search).
#
# Usage: tavily_search.sh <query> [max_results] [depth]
#   <query>        search string (required)
#   [max_results]  number of results, 1-20 (default 5; Tavily default is 5)
#   [depth]        "basic" (1 credit, default) or "advanced" (2 credits)
#
# Keys: TAVILY_API_KEY (primary), TAVILY_API_KEY_BACKUP (backup).
# Auth: header "Authorization: Bearer <key>" (modern Tavily auth).
# Index type: Tavily LLM-optimized web index, returns include_answer summary.
# WATCH: "advanced" depth costs 2x credits -- we default to "basic" on purpose.
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

QUERY="${1:?Usage: tavily_search.sh <query> [max_results] [depth]}"
MAXR="${2:-5}"
DEPTH="${3:-basic}"

# Build request body with jq (shell-safe encoding).
BODY="$(jq -n \
  --arg q "$QUERY" \
  --argjson maxr "$(asnum "$MAXR")" \
  --arg depth "$DEPTH" \
  '{query:$q, max_results:$maxr, search_depth:$depth, include_answer:true}')"

# Request fn: takes the api key as $1, appends -w for status capture.
_req() {
  curl -s -w '\n%{http_code}' -X POST "https://api.tavily.com/search" \
    -H "Authorization: Bearer $1" \
    -H "Content-Type: application/json" \
    --max-time 30 \
    -d "$BODY"
}

dr_run_with_fallover "tavily" "TAVILY_API_KEY" "TAVILY_API_KEY_BACKUP" _req
