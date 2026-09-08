#!/usr/bin/env bash
# dr_config.sh -- deep-research onboarding/state helper.
# State lives at ~/.claude/deep-research/. No secret values ever land in configuration.json.
# bash 3.2 compatible (macOS), ASCII only, jq required.
set -euo pipefail
export LC_ALL=C

# --- guards ------------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "dr_config: jq not found on PATH. Install it: https://jqlang.github.io/jq/download/" >&2
  echo "  macOS:   brew install jq" >&2
  echo "  Linux:   apt-get install jq  (or your package manager)" >&2
  echo "  Windows: winget install jqlang.jq  (or choco install jq)" >&2
  exit 127
fi

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

# Parse `claude mcp list` output for MCP NAME. Returns "installed" or "missing".
# `claude mcp list` lines look like "name: command ..." or a table; we do a
# substring match on the start of a line to stay tolerant.
mcp_installed() {
  local name="$1" out
  if ! command -v claude >/dev/null 2>&1; then echo "missing"; return; fi
  out="$(claude mcp list 2>/dev/null || true)"
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

  # 2. MCPs: parse `claude mcp list`
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
  write_env_key "$name" "$value"
  # Ensure an apiKeys entry exists (seed from key_meta_json) then mark present.
  local meta
  meta="$(key_meta_json "$name")"
  jq_update "(.components.apiKeys[\"$name\"]) |= ((. // {}) + $meta + {\"confirmed\": true, \"hasKey\": true, \"status\": \"present\", \"checkedAt\": \"$(now_iso)\"})"
  echo "wrote $name to $DR_ENV (chmod 600); marked present in $DR_CONFIG"
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
  set)                cmd_set "$@" ;;
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

  dr_config.sh set <dotted.path> <value>
      Generic setter for onboarding.* fields (e.g. onboarding.status complete).

State lives under ~/.claude/deep-research/. Override the location with DR_HOME.
EOF
    ;;
  *) die "unknown subcommand: $sub (try: $0 --help)" ;;
esac
