#!/usr/bin/env bash
# lusha_phone.sh -- Lusha PHONE-NUMBER lookup ONLY (B2B / PEOPLE).
#
# PHONE-ONLY: the router calls this only for "find direct dial / phone for
# <person>" intents. Costs 5 credits per phone reveal; free tier is 40
# credits/month (~8 phone lookups). Do NOT use for general enrichment.
#
# Usage: lusha_phone.sh <firstName> <lastName> <companyName>
#
# Auth: header "api_key: <key>".
# Endpoint: GET https://api.lusha.com/v2/person
#   Required combo: firstName AND lastName AND (companyName OR companyDomain).
#   HTTP params are CASE-SENSITIVE. We add filterBy=phoneNumbers + revealPhones
#   so only phone-bearing matches are returned.
# Key: LUSHA_API_KEY (single key, NO backup).
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

FIRST="${1:?Usage: lusha_phone.sh <firstName> <lastName> <companyName>}"
LAST="${2:?Usage: lusha_phone.sh <firstName> <lastName> <companyName>}"
COMPANY="${3:?Usage: lusha_phone.sh <firstName> <lastName> <companyName>}"

_req() {
  curl -s -w '\n%{http_code}' -G "https://api.lusha.com/v2/person" \
    -H "api_key: $1" \
    --max-time 30 \
    --data-urlencode "firstName=$FIRST" \
    --data-urlencode "lastName=$LAST" \
    --data-urlencode "companyName=$COMPANY" \
    --data-urlencode "filterBy=phoneNumbers" \
    --data-urlencode "revealPhones=true"
}

dr_run_with_fallover "lusha" "LUSHA_API_KEY" "" _req
