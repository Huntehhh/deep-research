#!/usr/bin/env bash
# explorium_enrich.sh -- Explorium prospect lookup (B2B / PEOPLE+COMPANY).
#
# Usage: explorium_enrich.sh <company_domain_or_name> [page_size]
#   <company_domain_or_name>  company name to filter prospects by
#   [page_size]               records per page, 1-500 (default 5)
#
# Auth: header "api_key: <key>" -- LOWERCASE header name is the quirk.
# Endpoint: POST https://api.explorium.ai/v1/prospects
# Keys: EXPLORIUM_API_KEY (primary), EXPLORIUM_API_KEY_BACKUP (backup).
#
# BODY SCHEMA (from developers.explorium.ai/reference/fetch_prospects):
#   required top-level: mode ("full"), page_size (1-500)
#   filters object keys include: company_name, business_id, job_level,
#     job_department, has_email, has_phone_number, job_title, country_code,
#     company_size, company_revenue, skills, ... (see docs for full list)
#   NOTE: there is no direct "domain" filter -- domain must first be resolved
#     to a business_id via the businesses endpoint. We filter by company_name.
#
# A 422 here means AUTH IS VALID but the body schema needs work -- the smoke
# test treats 422 as "auth OK". engine_common does NOT fail over on 422, so a
# 422 body is returned to stdout for inspection.
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

COMPANY="${1:?Usage: explorium_enrich.sh <company_domain_or_name> [page_size]}"
PAGE_SIZE="${2:-5}"

# Minimal valid body: mode + page_size + a company_name filter.
BODY="$(jq -n \
  --arg company "$COMPANY" \
  --argjson ps "$(asnum "$PAGE_SIZE")" \
  '{mode:"full", size:$ps, page_size:$ps, page:1, filters:{company_name:{values:[$company]}}}')"

_req() {
  curl -s -w '\n%{http_code}' -X POST "https://api.explorium.ai/v1/prospects" \
    -H "api_key: $1" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --max-time 45 \
    -d "$BODY"
}

dr_run_with_fallover "explorium" "EXPLORIUM_API_KEY" "EXPLORIUM_API_KEY_BACKUP" _req
