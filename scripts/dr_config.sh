#!/usr/bin/env bash
# dr_config.sh -- deep-research onboarding/state helper.
# State lives at ~/.claude/deep-research/. No secret values ever land in configuration.json.
# bash 3.2 compatible (macOS), ASCII only, jq required.
set -euo pipefail
export LC_ALL=C

# --- jq bootstrap: same convention as engine_common.sh -----------------------
# If jq isn't on PATH, honor DR_JQ_PATH (env, else ~/.claude/deep-research/.env)
# so a non-standard install doesn't break `status` -- the skill's first step.
if ! command -v jq >/dev/null 2>&1; then
  __jqdir="${DR_JQ_PATH:-}"
  __envf="${DR_HOME:-$HOME/.claude/deep-research}/.env"
  if [ -z "$__jqdir" ] && [ -f "$__envf" ]; then
    __jqdir="$(sed -n 's/^DR_JQ_PATH=//p' "$__envf" | tail -n1 | tr -d "\r\"'")" || __jqdir=""
  fi
  if [ -n "$__jqdir" ]; then export PATH="$__jqdir:$PATH"; fi
  unset __jqdir __envf
fi

# --- guards ------------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "dr_config: jq not found on PATH. Install it: https://jqlang.github.io/jq/download/" >&2
  echo "  macOS:   brew install jq" >&2
  echo "  Linux:   apt-get install jq  (or your package manager)" >&2
  echo "  Windows: winget install jqlang.jq  (or choco install jq)" >&2
  exit 127
fi
# jq.exe on Windows ends its lines with CRLF. A stray \r inside a key name once
# made `check` write a duplicate of every apiKeys entry, so strip it everywhere.
jq() { command jq "$@" | tr -d '\r'; }

# --- paths -------------------------------------------------------------------
DR_HOME="${DR_HOME:-$HOME/.claude/deep-research}"
DR_CONFIG="$DR_HOME/configuration.json"
DR_ENV="$DR_HOME/.env"
mkdir -p "$DR_HOME"

# --- helpers -----------------------------------------------------------------
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; }

# Atomic JSON write: replaces $DR_CONFIG by piping a transform through jq.
# Usage: jq_update '<jq expression operating on .>'
jq_update() {
  local expr="$1" tmp
  [ -f "$DR_CONFIG" ] || die "configuration.json missing -- run: $0 init"
  tmp="$(mktemp "${DR_CONFIG}.XXXXXX")"
  jq --arg now "$(now_iso)" "$expr | .onboarding.updatedAt = \$now" "$DR_CONFIG" > "$tmp"
  mv -f "$tmp" "$DR_CONFIG"
}

die() { echo "dr_config: $*" >&2; exit 1; }

# Append/replace KEY=VALUE in .env (chmod 600). Does NOT echo the value.
write_env_key() {
  local name="$1" value="$2" tmp
  case "$name" in
    ''|*[!A-Za-z0-9_]*) die "invalid key name: $name" ;;
  esac
  touch "$DR_ENV"; chmod 600 "$DR_ENV" 2>/dev/null || true
  tmp="$(mktemp "${DR_ENV}.XXXXXX")"
  # keep all OTHER lines verbatim; drop any prior assignment of this name
  if [ -f "$DR_ENV" ]; then
    grep -v "^${name}=" "$DR_ENV" > "$tmp" 2>/dev/null || true
  fi
  printf '%s=%s\n' "$name" "$value" >> "$tmp"
  mv -f "$tmp" "$DR_ENV"
  chmod 600 "$DR_ENV" 2>/dev/null || true
}

# Empty-state configuration.json (mirrors references/onboarding.md).
seed_config() {
  cat > "$DR_CONFIG" <<'JSON'
{
  "schemaVersion": 1,
  "onboarding": {
    "status": "not_started",
    "reminderPreference": "ask_next_time",
    "selectedCategories": [],
    "startedAt": null,
    "updatedAt": null,
    "completedAt": null,
    "lastPromptedAt": null
  },
  "components": {
    "skills": {
      "exa-search":      { "recommended": true,  "confirmed": false, "installed": false, "status": "missing", "checkedAt": null },
      "nano-banana-pro": { "recommended": false, "confirmed": false, "installed": false, "status": "missing", "checkedAt": null }
    },
    "mcps": {
      "firecrawl":         { "recommended": true,  "confirmed": false, "installed": false, "status": "missing", "needsKey": true,  "hasKey": false, "checkedAt": null },
      "perplexity-server": { "recommended": true,  "confirmed": false, "installed": false, "status": "missing", "needsKey": false, "checkedAt": null },
      "paper-search":      { "recommended": true,  "confirmed": false, "installed": false, "status": "missing", "needsKey": false, "checkedAt": null },
      "chrome-devtools":   { "recommended": false, "confirmed": false, "installed": false, "status": "missing", "needsKey": false, "checkedAt": null }
    },
    "apiKeys": {}
  }
}
JSON
  # Stamp the empty config with updatedAt so consumers can tell it's been touched.
  local tmp
  tmp="$(mktemp "${DR_CONFIG}.XXXXXX")"
  jq --arg now "$(now_iso)" '.onboarding.updatedAt = $now' "$DR_CONFIG" > "$tmp"
  mv -f "$tmp" "$DR_CONFIG"
}

# Known key names + signup URLs + lane categories (mirrors onboarding.md).
# Used by `set-key` to seed an apiKeys entry on first write if absent.
key_meta_json() {
  local name="$1"
  case "$name" in
    EXA_API_KEY)        printf '%s' '{"tier":"baseline","categories":["deep_general","academic_medical","b2b_intel","scraping_extraction"],"signupUrl":"https://dashboard.exa.ai/api-keys"}' ;;
    PERPLEXITY_API_KEY) printf '%s' '{"tier":"baseline","categories":["deep_general"],"signupUrl":"https://docs.perplexity.ai/"}' ;;
    FIRECRAWL_API_KEY)  printf '%s' '{"tier":"baseline","categories":["academic_medical","b2b_intel","scraping_extraction"],"signupUrl":"https://www.firecrawl.dev/app/api-keys"}' ;;
    SERPER_API_KEY)     printf '%s' '{"tier":"optional","categories":["deep_general"],"signupUrl":"https://serper.dev"}' ;;
    BRAVE_API_KEY)      printf '%s' '{"tier":"optional","categories":["deep_general","scraping_extraction"],"signupUrl":"https://brave.com/search/api/"}' ;;
    TAVILY_API_KEY)     printf '%s' '{"tier":"optional","categories":["deep_general"],"signupUrl":"https://app.tavily.com"}' ;;
    LINKUP_API_KEY)     printf '%s' '{"tier":"optional","categories":["deep_general"],"signupUrl":"https://app.linkup.so"}' ;;
    OPENROUTER_API_KEY) printf '%s' '{"tier":"optional","categories":["deep_general"],"signupUrl":"https://openrouter.ai/keys"}' ;;
    PDL_API_KEY)        printf '%s' '{"tier":"recommended","categories":["b2b_intel"],"signupUrl":"https://www.peopledatalabs.com/signup"}' ;;
    THEIRSTACK_API_KEY) printf '%s' '{"tier":"optional","categories":["b2b_intel"],"signupUrl":"https://app.theirstack.com"}' ;;
    EXPLORIUM_API_KEY)  printf '%s' '{"tier":"optional","categories":["b2b_intel"],"signupUrl":"https://www.explorium.ai"}' ;;
    LUSHA_API_KEY)      printf '%s' '{"tier":"optional","categories":["b2b_intel"],"signupUrl":"https://www.lusha.com"}' ;;
    NCBI_API_KEY)       printf '%s' '{"tier":"optional","categories":["academic_medical"],"signupUrl":"https://www.ncbi.nlm.nih.gov/account/"}' ;;
    OPENFDA_API_KEY)    printf '%s' '{"tier":"optional","categories":["academic_medical"],"signupUrl":"https://open.fda.gov/apis/authentication/"}' ;;
    PAPER_SEARCH_MCP_UNPAYWALL_EMAIL) printf '%s' '{"tier":"optional","categories":["academic_medical"],"signupUrl":"https://unpaywall.org/products/api"}' ;;
    *)                  printf '%s' '{"tier":"custom","categories":[],"signupUrl":null}' ;;
  esac
}

# Look up whether a key is present in .env or OS env. OS env wins.
key_has_value() {
  local name="$1" val
  eval "val=\${$name:-}"
  if [ -n "$val" ]; then
    echo "present"; return
  fi
  if [ -f "$DR_ENV" ] && grep -q "^${name}=" "$DR_ENV" 2>/dev/null; then
    val="$(grep "^${name}=" "$DR_ENV" | tail -n1 | cut -d= -f2-)"
    if [ -n "$val" ]; then echo "present"; return; fi
  fi
  echo "missing"
}

# Detect a Claude Code skill folder by name.
skill_installed() {
  local name="$1"
  if [ -d "$HOME/.claude/skills/$name" ]; then echo "true"; else echo "false"; fi
}

# The `claude mcp list` output, fetched once per run (it health-checks every
# server, so it's slow). Finds the native installer's ~/.local/bin/claude.exe
# when `claude` isn't on PATH. Empty when no CLI is found.
MCP_LIST_CACHE=""
MCP_LIST_DONE=0
mcp_list() {
  local bin=""
  if [ "$MCP_LIST_DONE" = 0 ]; then
    MCP_LIST_DONE=1
    bin="$(command -v claude 2>/dev/null)" || bin=""
    if [ -z "$bin" ] && [ -x "$HOME/.local/bin/claude.exe" ]; then bin="$HOME/.local/bin/claude.exe"; fi
    if [ -n "$bin" ]; then MCP_LIST_CACHE="$("$bin" mcp list 2>/dev/null | tr -d '\r' || true)"; fi
  fi
  printf '%s\n' "$MCP_LIST_CACHE"
}

# Parse `claude mcp list` output for MCP NAME. Returns "installed" or "missing".
# `claude mcp list` lines look like "name: command ..." or a table; we do a
# substring match on the start of a line to stay tolerant.
mcp_installed() {
  local name="$1" out
  out="$(mcp_list)"
  if printf '%s\n' "$out" | grep -Eiq "^[[:space:]]*${name}[[:space:]:]" ; then
    echo "installed"
  else
    echo "missing"
  fi
}

# --- subcommands -------------------------------------------------------------
cmd_init() {
  if [ -f "$DR_CONFIG" ]; then
    echo "configuration.json already exists at $DR_CONFIG -- no changes."
    return 0
  fi
  seed_config
  echo "initialized: $DR_CONFIG"
}

cmd_check() {
  [ -f "$DR_CONFIG" ] || cmd_init >/dev/null
  local now ts
  now="$(now_iso)"
  ts="$now"

  # 1. skills: each known skill folder
  for s in exa-search nano-banana-pro; do
    if [ "$(skill_installed "$s")" = "true" ]; then
      jq_update ".components.skills[\"$s\"].installed = true | .components.skills[\"$s\"].status = \"present\" | .components.skills[\"$s\"].checkedAt = \"$ts\""
    else
      jq_update ".components.skills[\"$s\"].installed = false | .components.skills[\"$s\"].status = \"missing\" | .components.skills[\"$s\"].checkedAt = \"$ts\""
    fi
  done

  # 2. MCPs: parse `claude mcp list` (fetched once here, in this shell, so the
  #    per-MCP lookups below reuse it instead of re-running the slow CLI)
  mcp_list >/dev/null
  for m in firecrawl perplexity-server paper-search chrome-devtools; do
    if [ "$(mcp_installed "$m")" = "installed" ]; then
      jq_update ".components.mcps[\"$m\"].installed = true | .components.mcps[\"$m\"].status = \"present\" | .components.mcps[\"$m\"].checkedAt = \"$ts\""
    else
      jq_update ".components.mcps[\"$m\"].installed = false | .components.mcps[\"$m\"].status = \"missing\" | .components.mcps[\"$m\"].checkedAt = \"$ts\""
    fi
  done

  # 3. API keys: only update entries that already exist in apiKeys.
  local key_names
  key_names="$(jq -r '.components.apiKeys | keys[]' "$DR_CONFIG" 2>/dev/null || true)"
  if [ -n "$key_names" ]; then
    while IFS= read -r kname; do
      [ -z "$kname" ] && continue
      local hv
      hv="$(key_has_value "$kname")"
      if [ "$hv" = "present" ]; then
        jq_update ".components.apiKeys[\"$kname\"].hasKey = true | .components.apiKeys[\"$kname\"].status = \"present\" | .components.apiKeys[\"$kname\"].checkedAt = \"$ts\""
      else
        jq_update ".components.apiKeys[\"$kname\"].hasKey = false | .components.apiKeys[\"$kname\"].status = \"missing\" | .components.apiKeys[\"$kname\"].checkedAt = \"$ts\""
      fi
    done <<EOF
$key_names
EOF
  fi

  echo "check complete (updated checkedAt = $ts)"
}

cmd_status() {
  [ -f "$DR_CONFIG" ] || { echo "no configuration.json yet -- run: $0 init"; return 1; }
  cmd_check >/dev/null
  jq '.' "$DR_CONFIG"
}

cmd_select_categories() {
  [ "${1:-}" ] || die "usage: $0 select-categories <c1,c2,...>"
  [ -f "$DR_CONFIG" ] || cmd_init >/dev/null
  local raw="$1" arr
  # Build JSON array from comma-separated input. Trim whitespace per item.
  arr="$(printf '%s' "$raw" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | jq -R . | jq -s .)"
  local started
  started="$(jq -r '.onboarding.startedAt // ""' "$DR_CONFIG")"
  if [ -z "$started" ]; then
    jq_update ".onboarding.startedAt = \"$(now_iso)\""
  fi
  jq_update ".onboarding.selectedCategories = $arr | .onboarding.status = \"in_progress\""
  echo "selected: $arr"
}

cmd_set_key() {
  [ "${1:-}" ] || die "usage: $0 set-key <NAME> <VALUE>"
  [ "${2:-}" ] || die "usage: $0 set-key <NAME> <VALUE>"
  [ -f "$DR_CONFIG" ] || cmd_init >/dev/null
  local name="$1" value="$2"
  # Exa is read from the global environment only (exa-search never reads this
  # skill's .env), so EXA_API_KEY goes through exa-search's check-then-save.
  if [ "$name" = "EXA_API_KEY" ]; then
    local setter="$HOME/.claude/skills/exa-search/scripts/exa_set_key.sh" rc=0
    [ -f "$setter" ] || die "exa-search skill not installed ($setter missing) -- install it first (references/onboarding.md)"
    bash "$setter" "$value" || rc=$?
    if [ "$rc" -ne 0 ]; then echo "dr_config: EXA_API_KEY not saved (see above)." >&2; exit "$rc"; fi
    jq_update "(.components.apiKeys[\"EXA_API_KEY\"]) |= ((. // {}) + $(key_meta_json EXA_API_KEY) + {\"confirmed\": true, \"hasKey\": true, \"status\": \"present\", \"checkedAt\": \"$(now_iso)\"})"
    echo "EXA_API_KEY saved to the global environment (not .env); marked present in $DR_CONFIG"
    return 0
  fi
  write_env_key "$name" "$value"
  # Ensure an apiKeys entry exists (seed from key_meta_json) then mark present.
  local meta
  meta="$(key_meta_json "$name")"
  jq_update "(.components.apiKeys[\"$name\"]) |= ((. // {}) + $meta + {\"confirmed\": true, \"hasKey\": true, \"status\": \"present\", \"checkedAt\": \"$(now_iso)\"})"
  echo "wrote $name to $DR_ENV (chmod 600); marked present in $DR_CONFIG"
}

# Record which known keys already exist in the OS environment (or .env), so a
# machine whose keys were set up elsewhere can finish onboarding without
# re-pasting anything. Names only: no value is read into the config.
cmd_detect_keys() {
  [ -f "$DR_CONFIG" ] || cmd_init >/dev/null
  local name found="" missing=""
  for name in EXA_API_KEY FIRECRAWL_API_KEY SERPER_API_KEY BRAVE_API_KEY TAVILY_API_KEY LINKUP_API_KEY \
              OPENROUTER_API_KEY PDL_API_KEY THEIRSTACK_API_KEY EXPLORIUM_API_KEY LUSHA_API_KEY \
              NCBI_API_KEY OPENFDA_API_KEY PAPER_SEARCH_MCP_UNPAYWALL_EMAIL; do
    if [ "$(key_has_value "$name")" = present ]; then
      jq_update "(.components.apiKeys[\"$name\"]) |= ((. // {}) + $(key_meta_json "$name") + {\"confirmed\": true, \"hasKey\": true, \"status\": \"present\", \"checkedAt\": \"$(now_iso)\"})"
      found="$found $name"
    else
      missing="$missing $name"
    fi
  done
  echo "present:${found:- none}"
  echo "missing:${missing:- none}"
}

cmd_check_failures() {
  # Critical-path engines per references/routing.md#api-failure-alerting.
  local since="" arg
  while [ $# -gt 0 ]; do
    case "$1" in
      --since) since="${2:-}"; shift 2 ;;
      --since=*) since="${1#--since=}"; shift ;;
      *) die "usage: $0 check-failures [--since ISO8601]" ;;
    esac
  done
  # Default window: last 4 hours, if no explicit --since given.
  if [ -z "$since" ]; then
    since="$(date -u -d '4 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-4H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")"
  fi

  local logfile="${DR_FAILURE_LOG_DIR:-$HOME/.claude/deep-research-logs}/api-failures.jsonl"
  if [ ! -f "$logfile" ]; then
    echo "check-failures: no failure log yet ($logfile) -- nothing has failed. OK."
    return 0
  fi

  # Exa first (logged by exa-search's _exa_lib.sh as engine "exa"). A fatal means
  # the run should already have stopped at the Exa gate: exit 3, not a callout.
  local exa_fatal exa_err
  exa_fatal="$(jq -c --arg since "$since" \
    'select(.ts >= $since and .engine == "exa" and ((.reason // "") | tostring | startswith("fatal")))' \
    "$logfile" 2>/dev/null)" || exa_fatal=""
  if [ -n "$exa_fatal" ]; then
    echo "check-failures: EXA KEY FAILURE since $since -- do not deliver results. Stop, show the user this error, and ask for a working Exa key (SKILL.md 'Exa gate')." >&2
    printf '%s\n' "$exa_fatal" >&2
    return 3
  fi
  exa_err="$(jq -c --arg since "$since" \
    'select(.ts >= $since and .engine == "exa" and ((.reason // "") | tostring | startswith("error")))' \
    "$logfile" 2>/dev/null)" || exa_err=""
  if [ -n "$exa_err" ]; then
    echo "check-failures: note -- transient Exa error(s) since $since. Each must have been retried once; if any retry also failed, the run should have stopped:" >&2
    printf '%s\n' "$exa_err" >&2
  fi

  # Names as the wrappers actually log them (brave_search.sh logs "brave").
  local critical_engines='["pdl","explorium","github","github_repo_people","theirstack","lusha","paper-search","pubmed","brave","brave_search","perplexity-server","openrouter"]'
  local hits
  hits="$(jq -c --arg since "$since" --argjson crit "$critical_engines" \
    'select(.ts >= $since) | select(.engine as $e | $crit | index($e) != null)' \
    "$logfile" 2>/dev/null)" || hits=""

  if [ -z "$hits" ]; then
    echo "check-failures: OK -- no critical-path engine failures since $since."
    return 0
  fi

  echo "check-failures: CRITICAL-PATH FAILURE(S) since $since -- surface the degraded-output callout." >&2
  printf '%s\n' "$hits" >&2
  return 1
}

cmd_set() {
  [ "${1:-}" ] || die "usage: $0 set <dotted.path> <value>"
  [ -f "$DR_CONFIG" ] || cmd_init >/dev/null
  local path="$1" value="${2:-}"
  case "$path" in
    onboarding.status|onboarding.reminderPreference|onboarding.startedAt|onboarding.updatedAt|onboarding.completedAt|onboarding.lastPromptedAt) ;;
    *) die "set: only onboarding.* fields are supported (got: $path)" ;;
  esac
  # Treat the value as a string. If it parses as a JSON literal (true/false/null/number) we still
  # store it as a string to keep onboarding fields consistent.
  jq_update ".$path = \"$value\""
  echo "set $path = $value"
}

# --- dispatch ----------------------------------------------------------------
sub="${1:-}"
[ "$sub" ] && shift || true
case "$sub" in
  init)               cmd_init "$@" ;;
  status)             cmd_status "$@" ;;
  check)              cmd_check "$@" ;;
  select-categories)  cmd_select_categories "$@" ;;
  set-key)            cmd_set_key "$@" ;;
  detect-keys)        cmd_detect_keys "$@" ;;
  set)                cmd_set "$@" ;;
  check-failures)     cmd_check_failures "$@" ;;
  ''|-h|--help|help)
    cat <<'EOF'
dr_config.sh -- deep-research onboarding/state helper

Usage:
  dr_config.sh init
      Seed ~/.claude/deep-research/configuration.json (status not_started) if absent.

  dr_config.sh status
      Print current configuration as JSON (runs check first).

  dr_config.sh check
      Detect skills, MCPs, and key presence; update installed/hasKey/status/checkedAt.

  dr_config.sh select-categories <c1,c2,...>
      Set onboarding.selectedCategories + status="in_progress".
      Valid lanes: deep_general, academic_medical, b2b_intel, scraping_extraction

  dr_config.sh set-key <NAME> <VALUE>
      Append/replace NAME=VALUE in ~/.claude/deep-research/.env (chmod 600).
      Marks hasKey=true, status="present" in configuration.json. Never stores the value.
      EXA_API_KEY is different: it goes to the global environment via
      exa-search's exa_set_key.sh, which checks it live first (never .env).

  dr_config.sh detect-keys
      Mark every known key already present in the OS environment (or .env)
      as present in configuration.json. Names only; values are never read in.

  dr_config.sh set <dotted.path> <value>
      Generic setter for onboarding.* fields (e.g. onboarding.status complete).

  dr_config.sh check-failures [--since ISO8601]
      Read ~/.claude/deep-research-logs/api-failures.jsonl for critical-path
      engine failures since the given time (default: last 4 hours). Exit 0
      and print OK if none found; exit 1 and print the hits otherwise; exit 3
      if an Exa key failure (EXA_FATAL) was logged -- stop and ask for a key.
      Pass --since <the Exa gate's pass time>. Run this before finalizing
      output -- see SKILL.md "What's code-enforced vs. protocol-enforced".

State lives under ~/.claude/deep-research/. Override the location with DR_HOME.
EOF
    ;;
  *) die "unknown subcommand: $sub (try: $0 --help)" ;;
esac
