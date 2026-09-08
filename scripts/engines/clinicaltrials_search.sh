#!/usr/bin/env bash
# clinicaltrials_search.sh -- ClinicalTrials.gov API v2 study search, JSON out.
# Lane: CLINICAL / PRIVACY / GOVERNMENT medical APIs (functional-medicine / clinical research).
#
# PHI SAFETY NOTE:
#   PHI never crosses the wire. Callers pass only anonymized clinical research
#   terms (drug name, condition, biomarker), never patient identifiers.
#
# Usage: clinicaltrials_search.sh <query> [pageSize]
#   <query>     free-text search term (required), e.g. "semaglutide"
#   [pageSize]  studies to return (default 5, API max 1000)
#
# Endpoint: GET https://clinicaltrials.gov/api/v2/studies?query.term=<q>&pageSize=<n>
# KEYLESS (gov-run, no auth, no signup). Generous rate limits.
# Output: one line per study --
#   "NCT ID | brief title | status | phase | conditions".
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

QUERY="${1:?Usage: clinicaltrials_search.sh <query> [pageSize]}"
PAGESIZE="$(asnum "${2:-5}")"
BASE="https://clinicaltrials.gov/api/v2/studies"

# -G + --data-urlencode keeps the term shell-safe; -w appends HTTP status as the
# final output line, split off with the same tail/sed idiom engine_common uses.
RAW="$(curl -s -w '\n%{http_code}' -G "$BASE" \
  --data-urlencode "query.term=$QUERY" \
  --data-urlencode "pageSize=$PAGESIZE" \
  --data-urlencode "format=json" \
  --max-time 30)"
STATUS="$(printf '%s' "$RAW" | tail -n1)"
BODY="$(printf '%s' "$RAW" | sed '$d')"

case "$STATUS" in
  2*) : ;;
  *)
    dr_log_failure "clinicaltrials" "status $STATUS"
    printf 'DR_FAILURE: engine=clinicaltrials reason=status status=%s\n' "$STATUS" >&2
    printf '%s\n' "$BODY"
    exit 1
    ;;
esac

COUNT="$(printf '%s' "$BODY" | jq -r '.studies // [] | length')"
if [ "$COUNT" = "0" ] || [ -z "$COUNT" ]; then
  printf 'No ClinicalTrials.gov studies for: %s\n' "$QUERY"
  exit 0
fi

# Data lives in protocolSection (3-4 levels deep):
#   identificationModule.nctId / .briefTitle
#   statusModule.overallStatus
#   designModule.phases[]            (array; "NA" when not a phased trial)
#   conditionsModule.conditions[]    (array)
printf '%s' "$BODY" | jq -r '
  .studies[]
  | .protocolSection as $p
  | [ ($p.identificationModule.nctId // "(no NCT)"),
      ($p.identificationModule.briefTitle // "(no title)"),
      ($p.statusModule.overallStatus // "UNKNOWN"),
      ((($p.designModule.phases // []) | join(", ")) | if . == "" then "N/A" else . end),
      ((($p.conditionsModule.conditions // []) | join("; ")) | if . == "" then "(none listed)" else . end)
    ] | join(" | ")
'
