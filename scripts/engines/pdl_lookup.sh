#!/usr/bin/env bash
# pdl_lookup.sh -- People Data Labs person enrichment + autocomplete (B2B / PEOPLE).
#
# Usage:
#   pdl_lookup.sh autocomplete <field> <text> [size]
#       e.g. pdl_lookup.sh autocomplete school harv 1
#   pdl_lookup.sh enrich <param>=<value> [param2=value2 ...]
#       e.g. pdl_lookup.sh enrich profile=github.com/torvalds
#       e.g. pdl_lookup.sh enrich profile=linkedin.com/in/seanthorne
#       e.g. pdl_lookup.sh enrich email=someone@example.com
#       PDL accepts GitHub and LinkedIn profile URLs as person-lookup input.
#
# Auth: header "X-Api-Key: <key>".
# Endpoints:
#   GET https://api.peopledatalabs.com/v5/autocomplete (free smoke endpoint)
#   GET https://api.peopledatalabs.com/v5/person/enrich (sent as -G query string)
# Keys: PDL_API_KEY (primary), PDL_API_KEY_BACKUP (backup).
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

MODE="${1:?Usage: pdl_lookup.sh autocomplete <field> <text> [size] | enrich <param>=<value> ...}"

case "$MODE" in
  autocomplete)
    FIELD="${2:?Usage: pdl_lookup.sh autocomplete <field> <text> [size]}"
    TEXT="${3:?Usage: pdl_lookup.sh autocomplete <field> <text> [size]}"
    SIZE="${4:-1}"
    _req() {
      curl -s -w '\n%{http_code}' -G "https://api.peopledatalabs.com/v5/autocomplete" \
        -H "X-Api-Key: $1" \
        --max-time 30 \
        --data-urlencode "field=$FIELD" \
        --data-urlencode "text=$TEXT" \
        --data-urlencode "size=$SIZE"
    }
    ;;
  enrich)
    shift
    [ "$#" -ge 1 ] || { echo "Usage: pdl_lookup.sh enrich <param>=<value> [param2=value2 ...]" >&2; exit 1; }
    # Build the curl --data-urlencode arg list once, preserving values with
    # spaces (e.g. company=People Data Labs). PDL_ENC is a normal array set at
    # top level; it is visible inside _req without any closure trickery.
    PDL_ENC=()
    for pair in "$@"; do
      case "$pair" in
        *=*) PDL_ENC+=(--data-urlencode "$pair") ;;
        *) echo "enrich args must be param=value, got: $pair" >&2; exit 1;;
      esac
    done
    _req() {
      curl -s -w '\n%{http_code}' -G "https://api.peopledatalabs.com/v5/person/enrich" \
        -H "X-Api-Key: $1" \
        --max-time 30 \
        "${PDL_ENC[@]}"
    }
    ;;
  *)
    echo "Unknown mode '$MODE'. Use: autocomplete | enrich" >&2
    exit 1
    ;;
esac

dr_run_with_fallover "pdl" "PDL_API_KEY" "PDL_API_KEY_BACKUP" _req
