#!/usr/bin/env bash
# engine_common.sh -- shared helpers for deep-research engine wrappers.
#
# WINDOWS / CLAUDE BASH TOOL: always invoke scripts with forward-slash paths.
#   CORRECT:  bash "C:/Users/huntfat/.claude/skills/deep-research/scripts/engines/serper_search.sh"
#   WRONG:    bash "C:\Users\huntfat\.claude\skills\deep-research\scripts\engines\serper_search.sh"
# Backslashes in bash are escape chars (\U, \c, etc.) -- the path silently
# resolves wrong and the script exits 127 ("command not found").
#
# Source this from each engine wrapper:
#   . "$(dirname "$0")/engine_common.sh"
#
# Provides:
#   asnum                 -- coerce a value to a JSON number for jq --argjson
#   dr_keyval VAR         -- echo the value of an env var named by $1 (bash 3.2 safe)
#   dr_should_fallover    -- decide if an HTTP status/body warrants the backup key
#   dr_log_failure        -- append one JSONL incident line to the failure log
#   dr_run_with_fallover  -- run a request fn with primary -> backup key fallover
#
# Conventions enforced:
#   - Keys are read from the environment ONLY. Primary at <ENGINE>_API_KEY,
#     backup at <ENGINE>_API_KEY_BACKUP. Never hardcode a key in a script.
#   - Request fns append `-w '\n%{http_code}'` so the LAST output line is the
#     HTTP status; the helper splits body from status.
#   - On total failure: log + print `DR_FAILURE: engine=... reason=...` to stderr
#     + return 1. The orchestrator (SKILL.md) decides whether to surface a
#     degraded-output callout based on the critical-path table -- the wrappers
#     do NOT decide policy.
#
# bash 3.2 compatible (macOS), ASCII only, no associative arrays.

# --- deep-research: source per-user .env, OS env always wins ---
DR_ENV_FILE="${DR_ENV_FILE:-$HOME/.claude/deep-research/.env}"
if [ -f "$DR_ENV_FILE" ]; then
  while IFS='=' read -r __k __v; do
    case "$__k" in ''|'#'*) continue ;; esac
    __k="$(printf '%s' "$__k" | tr -d '[:space:]')"
    [ -z "$__k" ] && continue
    __v="${__v%\"}"; __v="${__v#\"}"; __v="${__v%\'}"; __v="${__v#\'}"
    eval "__cur=\${$__k:-}"
    [ -z "$__cur" ] && export "$__k=$__v"
  done < "$DR_ENV_FILE"
  unset __k __v __cur
fi
# --- end deep-research .env ---

# --- jq PATH bootstrap (Windows / non-standard installs) ---
# If jq isn't on PATH, honor DR_JQ_PATH (directory containing jq) so a
# non-standard install location doesn't require editing this script.
if ! command -v jq >/dev/null 2>&1 && [ -n "${DR_JQ_PATH:-}" ]; then
  export PATH="$DR_JQ_PATH:$PATH"
fi
# --- end jq PATH bootstrap ---

# Coerce a value to a JSON number for jq --argjson (empty/non-numeric -> 0).
asnum() { local v="${1:-}"; case "$v" in ''|*[!0-9.-]*) echo 0;; *) echo "$v";; esac; }

# Echo the value of an env var named by $1 (portable indirection, bash 3.2 safe).
dr_keyval() { eval "printf '%s' \"\${$1:-}\""; }

# Decide whether an HTTP status / body warrants failing over to the backup key.
# Usage: dr_should_fallover <status> <body>   ; returns 0 (true) to fail over.
dr_should_fallover() {
  local status="${1:-0}" body="${2:-}"
  case "$status" in
    401|402|403|429|500|502|503|504) return 0;;
  esac
  printf '%s' "$body" | grep -Eiq 'rate.?limit|quota|exhaust|too many request|insufficient|forbidden' && return 0
  return 1
}

# Append one JSONL incident line to the failure log for post-hoc analysis.
# Usage: dr_log_failure <engine> <reason>
# Log dir overridable via DR_FAILURE_LOG_DIR (default ~/.claude/deep-research-logs).
dr_log_failure() {
  local engine="${1:-unknown}" reason="${2:-}" logdir logfile ts
  logdir="${DR_FAILURE_LOG_DIR:-$HOME/.claude/deep-research-logs}"
  mkdir -p "$logdir" 2>/dev/null || true
  logfile="$logdir/api-failures.jsonl"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"; ts="${ts:-unknown}"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg ts "$ts" --arg engine "$engine" --arg reason "$reason" \
      '{ts:$ts, engine:$engine, reason:$reason}' >> "$logfile" 2>/dev/null || \
      printf '{"ts":"%s","engine":"%s","reason":"%s"}\n' "$ts" "$engine" "$reason" >> "$logfile"
  else
    printf '{"ts":"%s","engine":"%s","reason":"%s"}\n' "$ts" "$engine" "$reason" >> "$logfile"
  fi
}

# Run a request function with primary -> backup key fallover.
#
# The caller defines a function taking ONE arg (the api key) that runs curl
# with `-w '\n%{http_code}'` appended (last output line = HTTP status).
#
# Usage: dr_run_with_fallover <engine> <PRIMARY_VAR> <BACKUP_VAR> <request_fn>
#   - <BACKUP_VAR> may be "" for single-key engines (e.g. Lusha).
# On success: prints response body to stdout, returns 0.
# On total failure: logs, prints `DR_FAILURE: ...` to stderr, returns 1
#   (still prints whatever body came back, so the caller can inspect errors).
dr_run_with_fallover() {
  local engine="$1" primary_var="$2" backup_var="$3" req_fn="$4"
  local key raw status body bkey

  key="$(dr_keyval "$primary_var")"
  if [ -z "$key" ] && [ -n "$backup_var" ]; then
    key="$(dr_keyval "$backup_var")"
  fi
  if [ -z "$key" ]; then
    dr_log_failure "$engine" "no key set ($primary_var${backup_var:+ / $backup_var})"
    printf 'DR_FAILURE: engine=%s reason=no-key\n' "$engine" >&2
    return 1
  fi

  raw="$("$req_fn" "$key")"
  status="$(printf '%s' "$raw" | tail -n1)"
  body="$(printf '%s' "$raw" | sed '$d')"

  if dr_should_fallover "$status" "$body"; then
    bkey=""
    [ -n "$backup_var" ] && bkey="$(dr_keyval "$backup_var")"
    if [ -n "$bkey" ] && [ "$bkey" != "$key" ]; then
      dr_log_failure "$engine" "primary key failover (status $status)"
      raw="$("$req_fn" "$bkey")"
      status="$(printf '%s' "$raw" | tail -n1)"
      body="$(printf '%s' "$raw" | sed '$d')"
      if dr_should_fallover "$status" "$body"; then
        dr_log_failure "$engine" "both keys failed (status $status)"
        printf 'DR_FAILURE: engine=%s reason=both-keys-failed status=%s\n' "$engine" "$status" >&2
        printf '%s' "$body"
        return 1
      fi
    else
      dr_log_failure "$engine" "primary failed, no usable backup (status $status)"
      printf 'DR_FAILURE: engine=%s reason=no-backup status=%s\n' "$engine" "$status" >&2
      printf '%s' "$body"
      return 1
    fi
  fi

  printf '%s' "$body"
  return 0
}
