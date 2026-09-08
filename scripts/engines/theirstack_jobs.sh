#!/usr/bin/env bash
# theirstack_jobs.sh -- TheirStack hiring-signal intelligence (B2B / COMPANY).
# Searches millions of job postings to surface what a company / market is hiring for.
#
# Usage: theirstack_jobs.sh <job_title_or_tech> [limit]
#   <job_title_or_tech>  job title to match, e.g. "Software Engineer"
#   [limit]              result count (default 5)
#
# Auth: header "Authorization: Bearer <key>" (the key is a long JWT).
# Endpoint: POST https://api.theirstack.com/v1/jobs/search
# Keys: THEIRSTACK_API_KEY (primary), THEIRSTACK_API_KEY_BACKUP (backup).
#
# QUIRK: TheirStack 422s unless the body contains at least ONE of:
#   posted_at_max_age_days | posted_at_gte | posted_at_lte |
#   company_domain_or | company_linkedin_url_or | company_name_or
# We always send posted_at_max_age_days plus job_country_code_or to satisfy this.
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

TITLE="${1:?Usage: theirstack_jobs.sh <job_title_or_tech> [limit]}"
LIMIT="${2:-5}"
MAX_AGE="${THEIRSTACK_MAX_AGE_DAYS:-30}"

# Build a minimal valid body: required date filter + title filter + country.
BODY="$(jq -n \
  --arg title "$TITLE" \
  --argjson limit "$(asnum "$LIMIT")" \
  --argjson maxage "$(asnum "$MAX_AGE")" \
  '{page:0, limit:$limit, posted_at_max_age_days:$maxage, job_title_or:[$title], job_country_code_or:["US"]}')"

_req() {
  curl -s -w '\n%{http_code}' -X POST "https://api.theirstack.com/v1/jobs/search" \
    -H "Authorization: Bearer $1" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --max-time 45 \
    -d "$BODY"
}

dr_run_with_fallover "theirstack" "THEIRSTACK_API_KEY" "THEIRSTACK_API_KEY_BACKUP" _req
