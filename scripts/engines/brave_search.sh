#!/usr/bin/env bash
# brave_search.sh -- Brave Search API web results as JSON (GET /res/v1/web/search).
#
# Usage: brave_search.sh <query> [count]
#   <query>  search string (required)
#   [count]  result count, 1-20 (default 10; Brave caps free tier at 20)
#
# Keys: BRAVE_API_KEY (primary), BRAVE_API_KEY_BACKUP (backup).
# Auth: header "X-Subscription-Token: <key>" + "Accept: application/json".
# Index type: Brave independent web index. Free tier: 2,000 queries/mo, 1 req/sec.
# NOTE: GET request (not POST) -- query is url-encoded via curl -G --data-urlencode.
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

QUERY="${1:?Usage: brave_search.sh <query> [count]}"
COUNT="${2:-10}"

# Request fn: takes the api key as $1, appends -w for status capture.
# GET with -G so --data-urlencode params are appended to the query string.
_req() {
  curl -s -w '\n%{http_code}' -G "https://api.search.brave.com/res/v1/web/search" \
    --data-urlencode "q=$QUERY" \
    --data-urlencode "count=$COUNT" \
    -H "X-Subscription-Token: $1" \
    -H "Accept: application/json" \
    --max-time 30
}

dr_run_with_fallover "brave" "BRAVE_API_KEY" "BRAVE_API_KEY_BACKUP" _req
