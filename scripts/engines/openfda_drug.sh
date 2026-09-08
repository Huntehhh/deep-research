#!/usr/bin/env bash
# openfda_drug.sh -- openFDA drug label + adverse-event lookups, JSON out.
# Lane: CLINICAL / PRIVACY / GOVERNMENT medical APIs (functional-medicine / clinical research).
#
# PHI SAFETY NOTE:
#   PHI never crosses the wire. Callers pass only anonymized clinical research
#   terms (drug name, condition, biomarker), never patient identifiers.
#
# Usage:
#   openfda_drug.sh label <term> [limit]   -- drug product labels (default)
#   openfda_drug.sh event <term> [limit]   -- adverse-event reports (FAERS)
#   openfda_drug.sh <term> [limit]         -- shorthand; defaults to "label"
#
#   <term>   generic/brand drug name, e.g. "semaglutide" (matched against
#            openfda.generic_name then openfda.brand_name)
#   [limit]  records to return (default 5, API max 1000)
#
# Endpoints (search=field:term syntax -- ONE '=', a ':' between field and term):
#   label: https://api.fda.gov/drug/label.json?search=<field:term>&limit=<n>
#   event: https://api.fda.gov/drug/event.json?search=<field:term>&limit=<n>
# KEYLESS by default (240/min, 1000/day per IP). If OPENFDA_API_KEY is set it is
# passed via &api_key= which raises the limit (240/min, 120k/day per key).
# Output: the most relevant fields (brand/generic name, indications, warnings for
# labels; reaction counts for events) -- not the raw firehose.
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

# Subcommand routing: explicit label|event, else treat $1 as the term ("label").
MODE="label"
case "${1:-}" in
  label|event) MODE="$1"; shift ;;
esac

TERM="${1:?Usage: openfda_drug.sh [label|event] <term> [limit]}"
LIMIT="$(asnum "${2:-5}")"

# Pass api_key only when OPENFDA_API_KEY is present (keyless otherwise).
KEYARG=""
if [ -n "${OPENFDA_API_KEY:-}" ]; then
  KEYARG="$OPENFDA_API_KEY"
fi

if [ "$MODE" = "event" ]; then
  BASE="https://api.fda.gov/drug/event.json"
  # FAERS nests the drug under patient.drug.openfda.*; match generic OR brand.
  SEARCH="patient.drug.openfda.generic_name:\"$TERM\"+patient.drug.openfda.brand_name:\"$TERM\""
else
  BASE="https://api.fda.gov/drug/label.json"
  # Label endpoint exposes openfda.* at the top level; match generic OR brand.
  SEARCH="openfda.generic_name:\"$TERM\"+openfda.brand_name:\"$TERM\""
fi

# Build the query string by hand: openFDA's field:term + '+' OR syntax must NOT
# be percent-encoded the way --data-urlencode would mangle the ':' and '+'. We
# only need to encode the space inside the quoted term, which we do above by
# leaving the term intact (single-token drug names are space-free; multi-word
# callers should pass a '+' themselves). -w appends the HTTP status line.
RAW="$(curl -s -w '\n%{http_code}' \
  "$BASE?search=$SEARCH&limit=$LIMIT${KEYARG:+&api_key=$KEYARG}" \
  --max-time 30)"
STATUS="$(printf '%s' "$RAW" | tail -n1)"
BODY="$(printf '%s' "$RAW" | sed '$d')"

case "$STATUS" in
  2*) : ;;
  404)
    # openFDA returns 404 with {"error":{"code":"NOT_FOUND",...}} for zero hits.
    if printf '%s' "$BODY" | jq -e '.error.code == "NOT_FOUND"' >/dev/null 2>&1; then
      printf 'No openFDA %s results for: %s\n' "$MODE" "$TERM"
      exit 0
    fi
    dr_log_failure "openfda" "$MODE status 404"
    printf 'DR_FAILURE: engine=openfda reason=status status=404\n' >&2
    printf '%s\n' "$BODY"
    exit 1
    ;;
  *)
    dr_log_failure "openfda" "$MODE status $STATUS"
    printf 'DR_FAILURE: engine=openfda reason=status status=%s\n' "$STATUS" >&2
    printf '%s\n' "$BODY"
    exit 1
    ;;
esac

if [ "$MODE" = "event" ]; then
  # Summarize each FAERS adverse-event report. A report bundles MANY co-reported
  # drugs (10-20 is common) and generic_name is itself an array -- so we do NOT
  # dump the bystander drug list (that's the firehose). The clinical signal is
  # the reactions (MedDRA preferred terms) + serious flag + report date.
  #   serious: "1" = serious, "2" = non-serious
  printf '%s' "$BODY" | jq -r '
    .results[]
    | ("serious: " + (if .serious == "1" then "yes" elif .serious == "2" then "no" else (.serious // "n/a" | tostring) end))
      + " | date: " + (.receivedate // "n/a")
      + " | reactions: " + (([.patient.reaction[]?.reactionmeddrapt] | map(select(. != null)) | unique | join(", ")) | if . == "" then "(none coded)" else . end)
  '
else
  # Label: brand/generic name + truncated indications + truncated warnings.
  printf '%s' "$BODY" | jq -r '
    def first_or(d): if (. // [] | length) > 0 then .[0] else d end;
    def clip: if (. | length) > 240 then (.[0:240] + " ...") else . end;
    .results[]
    | [ ("generic: " + (.openfda.generic_name | first_or("n/a"))),
        ("brand: "   + (.openfda.brand_name   | first_or("n/a"))),
        ("indications: " + ((.indications_and_usage | first_or("n/a")) | gsub("\\s+"; " ") | clip)),
        ("warnings: "    + ((.warnings           | first_or("n/a")) | gsub("\\s+"; " ") | clip))
      ] | join("\n")
    , "---"
  '
fi
