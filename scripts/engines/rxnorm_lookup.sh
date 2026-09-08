#!/usr/bin/env bash
# rxnorm_lookup.sh -- NLM RxNorm (RxNav) drug-name normalization, JSON out.
# Lane: CLINICAL / PRIVACY / GOVERNMENT medical APIs (functional-medicine / clinical research).
#
# PHI SAFETY NOTE:
#   PHI never crosses the wire. Callers pass only anonymized clinical research
#   terms (drug name, condition, biomarker), never patient identifiers.
#
# Usage: rxnorm_lookup.sh <drug_name>
#   <drug_name>  e.g. "semaglutide"
#
# Flow:
#   1) /REST/rxcui.json?name=<drug>                 -> resolve name to RxCUI(s)
#   2) /REST/rxcui/<rxcui>/related.json?tty=IN+PIN+SCD
#                                                   -> related ingredient/clinical concepts
#   bonus) DailyMed /v2/spls.json?rxcui=<rxcui>     -> Structured Product Label count
# KEYLESS (gov-run, no auth). Results in JSON.
# Output: resolved RxCUI + normalized name(s), then related IN/PIN/SCD concepts,
#         then a DailyMed SPL count for the primary RxCUI.
set -eo pipefail 2>/dev/null || set -e
. "$(dirname "$0")/engine_common.sh"

DRUG="${1:?Usage: rxnorm_lookup.sh <drug_name>}"
BASE="https://rxnav.nlm.nih.gov/REST"

# --- Step 1: resolve name -> RxCUI(s) -----------------------------------------
# -G + --data-urlencode keeps the name shell-safe; -w appends HTTP status line.
RAW="$(curl -s -w '\n%{http_code}' -G "$BASE/rxcui.json" \
  --data-urlencode "name=$DRUG" \
  --max-time 30)"
STATUS="$(printf '%s' "$RAW" | tail -n1)"
BODY="$(printf '%s' "$RAW" | sed '$d')"

case "$STATUS" in
  2*) : ;;
  *)
    dr_log_failure "rxnorm" "rxcui status $STATUS"
    printf 'DR_FAILURE: engine=rxnorm reason=rxcui-status status=%s\n' "$STATUS" >&2
    printf '%s\n' "$BODY"
    exit 1
    ;;
esac

# .idGroup.rxnormId is an array of RxCUIs (absent when nothing matched).
RXCUIS="$(printf '%s' "$BODY" | jq -r '.idGroup.rxnormId // [] | join(" ")')"
if [ -z "$RXCUIS" ]; then
  printf 'No RxNorm concept for: %s\n' "$DRUG"
  exit 0
fi

# Primary RxCUI = first match; report all resolved CUIs for transparency.
PRIMARY="$(printf '%s' "$RXCUIS" | awk '{print $1}')"
printf 'RxCUI(s) for "%s": %s\n' "$DRUG" "$RXCUIS"

# Normalized concept name + term type for the primary RxCUI (properties endpoint).
PROP_RAW="$(curl -s -w '\n%{http_code}' "$BASE/rxcui/$PRIMARY/properties.json" --max-time 30)"
PROP_STATUS="$(printf '%s' "$PROP_RAW" | tail -n1)"
PROP_BODY="$(printf '%s' "$PROP_RAW" | sed '$d')"
case "$PROP_STATUS" in
  2*)
    printf '%s' "$PROP_BODY" | jq -r '
      .properties as $p
      | if $p then "Normalized name: \($p.name // "n/a")  (tty: \($p.tty // "n/a"), rxcui: \($p.rxcui // "n/a"))"
        else "Normalized name: (no properties for RxCUI '"$PRIMARY"')" end'
    ;;
  *)
    dr_log_failure "rxnorm" "properties status $PROP_STATUS"
    printf '(properties lookup failed for RxCUI %s, status %s)\n' "$PRIMARY" "$PROP_STATUS" >&2
    ;;
esac

# --- Step 2: related concepts (IN ingredient / PIN precise / SCD clinical) -----
REL_RAW="$(curl -s -w '\n%{http_code}' -G "$BASE/rxcui/$PRIMARY/related.json" \
  --data-urlencode "tty=IN PIN SCD" \
  --max-time 30)"
REL_STATUS="$(printf '%s' "$REL_RAW" | tail -n1)"
REL_BODY="$(printf '%s' "$REL_RAW" | sed '$d')"

case "$REL_STATUS" in
  2*)
    printf 'Related concepts (IN/PIN/SCD):\n'
    # conceptGroup[] is keyed by tty; conceptProperties[] holds the members.
    printf '%s' "$REL_BODY" | jq -r '
      (.relatedGroup.conceptGroup // [])[]
      | .tty as $tty
      | (.conceptProperties // [])[]
      | "  [\($tty)] \(.rxcui) | \(.name)"
    ' | head -n 30
    REL_LINES="$(printf '%s' "$REL_BODY" | jq -r '[(.relatedGroup.conceptGroup // [])[] | (.conceptProperties // [])[]] | length')"
    if [ "${REL_LINES:-0}" = "0" ]; then
      printf '  (no IN/PIN/SCD relatives returned)\n'
    fi
    ;;
  *)
    dr_log_failure "rxnorm" "related status $REL_STATUS"
    printf '(related lookup failed for RxCUI %s, status %s)\n' "$PRIMARY" "$REL_STATUS" >&2
    ;;
esac

# --- Bonus: DailyMed SPL count for the primary RxCUI --------------------------
# Non-fatal: DailyMed is a nice-to-have; never fail the run on its account.
DM_RAW="$(curl -s -w '\n%{http_code}' -G "https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json" \
  --data-urlencode "rxcui=$PRIMARY" \
  --data-urlencode "pagesize=5" \
  --max-time 30 2>/dev/null || printf '\n000')"
DM_STATUS="$(printf '%s' "$DM_RAW" | tail -n1)"
DM_BODY="$(printf '%s' "$DM_RAW" | sed '$d')"
case "$DM_STATUS" in
  2*)
    DM_TOTAL="$(printf '%s' "$DM_BODY" | jq -r '.metadata.total_elements // 0' 2>/dev/null)"; DM_TOTAL="${DM_TOTAL:-0}"
    printf 'DailyMed SPLs for RxCUI %s: %s label(s)\n' "$PRIMARY" "$DM_TOTAL"
    ;;
  *)
    printf 'DailyMed SPL lookup unavailable (status %s) -- non-fatal\n' "$DM_STATUS"
    ;;
esac
