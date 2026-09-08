#!/usr/bin/env bash
set -eo pipefail 2>/dev/null || set -e
# brave_llm_context.sh -- Brave LLM-grounding context via the summarizer flow.
#
# FREE-TIER LIMITATION (verified May 2026 against Brave API docs):
#   Brave's dedicated AI endpoints are BOTH paywalled:
#     - Summarizer Search API  -> "discontinued Pro AI plan" only (deprecated).
#     - AI Grounding / Answers  -> paid "Answers plan" only (/res/v1/chat/completions).
#   On the free/base Data-for-Search plan neither dedicated endpoint is billable,
#   BUT the web-search endpoint still accepts `summary=1`. When the query is
#   summary-eligible AND the plan allows it, the response carries a `summarizer.key`
#   that we then poll at /res/v1/summarizer/search?key=... (that poll is NOT billed).
#
#   So this wrapper does the closest-available thing on a free key:
#     Step 1: GET /res/v1/web/search?q=...&summary=1&count=...&extra_snippets=1
#     Step 2: IF a summarizer key came back -> GET /res/v1/summarizer/search?key=...
#             and emit that summary JSON (pre-extracted markdown chunks for grounding).
#             ELSE -> emit the Step 1 web payload, whose results[].description +
#             extra_snippets already give LLM-groundable text. Graceful degradation;
#             no fake "summary" is fabricated.
#
#   If/when Hunter upgrades to the Answers plan, swap _req to POST
#   /res/v1/chat/completions {"model":"brave","messages":[...],"stream":false}.
#
# Usage: brave_llm_context.sh <query> [count]
#   <query>  search string (required)
#   [count]  web result count feeding the context, 1-20 (default 10)
#
# Keys: BRAVE_API_KEY (primary), BRAVE_API_KEY_BACKUP (backup).
# Auth: header "X-Subscription-Token: <key>" + "Accept: application/json".
. "$(dirname "$0")/engine_common.sh"

QUERY="${1:?Usage: brave_llm_context.sh <query> [count]}"
COUNT="${2:-10}"

# Step 1 request fn: web search with summary=1 to (maybe) mint a summarizer key.
# extra_snippets=1 enriches results[].extra_snippets so the fallback path still
# carries dense groundable text even when no summarizer key is granted.
_req() {
  curl -s -w '\n%{http_code}' -G "https://api.search.brave.com/res/v1/web/search" \
    --data-urlencode "q=$QUERY" \
    --data-urlencode "count=$COUNT" \
    --data-urlencode "summary=1" \
    --data-urlencode "extra_snippets=1" \
    -H "X-Subscription-Token: $1" \
    -H "Accept: application/json" \
    --max-time 30
}

# Run step 1 with fallover; capture the web payload.
WEB_JSON="$(dr_run_with_fallover "brave_llm_context" "BRAVE_API_KEY" "BRAVE_API_KEY_BACKUP" _req)"
WEB_RC=$?
[ $WEB_RC -ne 0 ] && { printf '%s' "$WEB_JSON"; exit $WEB_RC; }

# Extract a summarizer key if the plan/query granted one (else empty).
SUM_KEY=""
if printf '%s' "$WEB_JSON" | jq -e '.summarizer.key? // empty' >/dev/null 2>&1; then
  SUM_KEY="$(printf '%s' "$WEB_JSON" | jq -r '.summarizer.key')"
fi

# No summarizer key (free tier / not summary-eligible): emit web payload as-is.
# Its results[].description + extra_snippets are the groundable context.
if [ -z "$SUM_KEY" ] || [ "$SUM_KEY" = "null" ]; then
  printf '%s' "$WEB_JSON"
  exit 0
fi

# Step 2: poll the summarizer endpoint with the minted key (this call is not billed).
_req_sum() {
  curl -s -w '\n%{http_code}' -G "https://api.search.brave.com/res/v1/summarizer/search" \
    --data-urlencode "key=$SUM_KEY" \
    --data-urlencode "entity_info=1" \
    -H "X-Subscription-Token: $1" \
    -H "Accept: application/json" \
    --max-time 30
}

SUM_JSON="$(dr_run_with_fallover "brave_llm_context" "BRAVE_API_KEY" "BRAVE_API_KEY_BACKUP" _req_sum)"
SUM_RC=$?

# If the summary poll failed, fall back to the (valid) web payload rather than error out.
if [ $SUM_RC -ne 0 ]; then
  printf '%s' "$WEB_JSON"
  exit 0
fi

printf '%s' "$SUM_JSON"
