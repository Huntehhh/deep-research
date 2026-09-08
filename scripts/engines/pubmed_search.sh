#!/usr/bin/env bash
# pubmed_search.sh -- NCBI PubMed via E-utilities (esearch -> esummary), JSON out.
# Lane: CLINICAL / PRIVACY / GOVERNMENT medical APIs (functional-medicine / clinical research).
#
# PHI SAFETY NOTE:
#   PHI never crosses the wire. Callers pass only anonymized clinical research
#   terms (drug name, condition, biomarker), never patient identifiers.
#
# Usage: pubmed_search.sh <query> [retmax]
#   <query>   search string (required), e.g. "BPC-157"
#   [retmax]  max results (default 5)
#
# Two-step E-utilities flow:
#   1) esearch.fcgi?db=pubmed&term=<q>&retmode=json&retmax=<n> -> idlist (PMIDs)
#   2) esummary.fcgi?db=pubmed&id=<csv ids>&retmode=json       -> summaries
#
# KEYLESS by default (gov-run): ~3 req/s per IP. If NCBI_API_KEY is set, it is
# passed via &api_key= which raises the limit to ~10 req/s. Both steps below
# add the key only when present.
# Output: one line per article -- "PMID | title | journal | year".
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

QUERY="${1:?Usage: pubmed_search.sh <query> [retmax]}"
RETMAX="$(asnum "${2:-5}")"
BASE="https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

# Pass api_key only when NCBI_API_KEY is present (keyless otherwise).
KEYARG=""
if [ -n "${NCBI_API_KEY:-}" ]; then
  KEYARG="$NCBI_API_KEY"
fi

# --- Step 1: esearch -> PMID idlist -------------------------------------------
# -G + --data-urlencode keeps the term shell-safe; -w appends the HTTP status as
# the final output line, split off with the same tail/sed idiom engine_common uses.
ESEARCH_RAW="$(curl -s -w '\n%{http_code}' -G "$BASE/esearch.fcgi" \
  --data-urlencode "db=pubmed" \
  --data-urlencode "term=$QUERY" \
  --data-urlencode "retmode=json" \
  --data-urlencode "retmax=$RETMAX" \
  ${KEYARG:+--data-urlencode "api_key=$KEYARG"} \
  --data-urlencode "tool=deep-research-skill" \
  --max-time 30)"
ESEARCH_STATUS="$(printf '%s' "$ESEARCH_RAW" | tail -n1)"
ESEARCH_BODY="$(printf '%s' "$ESEARCH_RAW" | sed '$d')"

case "$ESEARCH_STATUS" in
  2*) : ;;
  *)
    dr_log_failure "pubmed" "esearch status $ESEARCH_STATUS"
    printf 'DR_FAILURE: engine=pubmed reason=esearch-status status=%s\n' "$ESEARCH_STATUS" >&2
    printf '%s\n' "$ESEARCH_BODY"
    exit 1
    ;;
esac

IDS="$(printf '%s' "$ESEARCH_BODY" | jq -r '.esearchresult.idlist // [] | join(",")')"
if [ -z "$IDS" ]; then
  printf 'No PubMed results for: %s\n' "$QUERY"
  exit 0
fi

# --- Step 2: esummary -> titles / journals / dates ----------------------------
ESUM_RAW="$(curl -s -w '\n%{http_code}' -G "$BASE/esummary.fcgi" \
  --data-urlencode "db=pubmed" \
  --data-urlencode "id=$IDS" \
  --data-urlencode "retmode=json" \
  ${KEYARG:+--data-urlencode "api_key=$KEYARG"} \
  --data-urlencode "tool=deep-research-skill" \
  --max-time 30)"
ESUM_STATUS="$(printf '%s' "$ESUM_RAW" | tail -n1)"
ESUM_BODY="$(printf '%s' "$ESUM_RAW" | sed '$d')"

case "$ESUM_STATUS" in
  2*) : ;;
  *)
    dr_log_failure "pubmed" "esummary status $ESUM_STATUS"
    printf 'DR_FAILURE: engine=pubmed reason=esummary-status status=%s\n' "$ESUM_STATUS" >&2
    printf '%s\n' "$ESUM_BODY"
    exit 1
    ;;
esac

# .result.uids[] preserves ranked order; pull title / journal / year (first 4 of pubdate).
printf '%s' "$ESUM_BODY" | jq -r '
  .result as $r
  | ($r.uids // [])[]
  | $r[.] as $a
  | [ $a.uid,
      ($a.title // "(no title)"),
      ($a.fulljournalname // $a.source // "(no journal)"),
      (($a.pubdate // "") | capture("(?<y>[0-9]{4})").y // "n/a")
    ] | join(" | ")
'
