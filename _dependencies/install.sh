#!/usr/bin/env bash
# install.sh -- bootstraps the deep-research skill's bundled dependencies.
# Idempotent: safe to re-run. Skips anything already in place.
# Cross-platform: macOS (bash 3.2+), Linux, Windows Git-Bash / WSL.
set -euo pipefail
export LC_ALL=C

# --- resolve paths -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPS_DIR="$SCRIPT_DIR"
HOME_SKILLS="$HOME/.claude/skills"

echo "deep-research installer"
echo "  SCRIPT_DIR: $SCRIPT_DIR"
echo "  SKILL_ROOT: $SKILL_ROOT"
echo ""

# --- tally for the final summary --------------------------------------------
INSTALLED=""
SKIPPED=""
MISSING=""
NEEDS_KEY=""

note_installed() { INSTALLED="$INSTALLED  - $1\n"; }
note_skipped()   { SKIPPED="$SKIPPED  - $1\n"; }
note_missing()   { MISSING="$MISSING  - $1\n"; }
note_needs_key() { NEEDS_KEY="$NEEDS_KEY  - $1\n"; }

# --- prereq detection (informational, never fatal) --------------------------
echo "[1/6] checking prerequisites"

HAS_BUN=0
if command -v bun >/dev/null 2>&1; then
  HAS_BUN=1
  echo "  bun: $(bun --version)"
else
  echo "  bun: NOT FOUND -- install from https://bun.sh (or 'curl -fsSL https://bun.sh/install | bash')"
  note_missing "bun (skipped: perplexity-server build)"
fi

HAS_PY=0
PY_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PY_BIN="python3"
  HAS_PY=1
elif command -v python >/dev/null 2>&1; then
  PY_BIN="python"
  HAS_PY=1
fi
if [ "$HAS_PY" = "1" ]; then
  PY_VER="$($PY_BIN -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo "?")"
  echo "  $PY_BIN: $PY_VER"
  PY_MAJOR="$($PY_BIN -c 'import sys; print(sys.version_info[0])' 2>/dev/null || echo 0)"
  PY_MINOR="$($PY_BIN -c 'import sys; print(sys.version_info[1])' 2>/dev/null || echo 0)"
  if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" = "3" ] && [ "$PY_MINOR" -lt 10 ]; }; then
    echo "  python: need >= 3.10 (have $PY_VER) -- install from https://www.python.org/downloads/"
    note_missing "python3 >= 3.10 (skipped: paper-search-mcp install)"
    HAS_PY=0
  fi
else
  echo "  python3: NOT FOUND -- install from https://www.python.org/downloads/"
  note_missing "python3 (skipped: paper-search-mcp install)"
fi

HAS_CLAUDE=0
if command -v claude >/dev/null 2>&1; then
  HAS_CLAUDE=1
  echo "  claude CLI: present"
else
  echo "  claude CLI: NOT FOUND -- install from https://docs.anthropic.com/en/docs/claude-code"
  note_missing "claude CLI (skipped: MCP registration)"
fi

echo ""

# --- step 2: copy exa-search skill to ~/.claude/skills ----------------------
echo "[2/6] installing exa-search skill"
EXA_SRC="$DEPS_DIR/skills/exa-search"
EXA_DST="$HOME_SKILLS/exa-search"
if [ -d "$EXA_DST" ]; then
  echo "  $EXA_DST already exists -- skipping (re-install: 'rm -rf $EXA_DST' then re-run)"
  note_skipped "exa-search skill (already installed)"
else
  if [ ! -d "$EXA_SRC" ]; then
    echo "  exa-search source missing at $EXA_SRC -- bundle is incomplete"
    note_missing "exa-search source"
  else
    mkdir -p "$HOME_SKILLS"
    cp -R "$EXA_SRC" "$EXA_DST"
    echo "  copied -> $EXA_DST"
    note_installed "exa-search skill (~/.claude/skills/exa-search)"
  fi
fi
echo ""

# --- step 3: install paper-search-mcp (python) ------------------------------
echo "[3/6] installing paper-search-mcp"
if [ "$HAS_PY" = "1" ]; then
  PAPER_SRC="$DEPS_DIR/MCPs/paper-search-mcp"
  if [ -d "$PAPER_SRC" ]; then
    if $PY_BIN -m pip install "$PAPER_SRC" >/dev/null 2>&1; then
      echo "  installed from bundled source"
      note_installed "paper-search-mcp (from bundled source)"
    else
      echo "  bundled install failed; trying PyPI fallback"
      if $PY_BIN -m pip install paper-search-mcp >/dev/null 2>&1; then
        echo "  installed from PyPI"
        note_installed "paper-search-mcp (from PyPI fallback)"
      else
        echo "  pip install failed -- run manually: $PY_BIN -m pip install paper-search-mcp"
        note_missing "paper-search-mcp (pip install failed)"
      fi
    fi
  else
    echo "  bundled source missing; trying PyPI directly"
    if $PY_BIN -m pip install paper-search-mcp >/dev/null 2>&1; then
      echo "  installed from PyPI"
      note_installed "paper-search-mcp (from PyPI)"
    else
      echo "  pip install failed"
      note_missing "paper-search-mcp (pip install failed)"
    fi
  fi
else
  echo "  skipped (python missing)"
fi
echo ""

# --- step 4: build perplexity-server (bun) ----------------------------------
echo "[4/6] building perplexity-server"
PERP_DIR="$DEPS_DIR/MCPs/perplexity-server"
if [ "$HAS_BUN" = "1" ]; then
  if [ -d "$PERP_DIR" ]; then
    (
      cd "$PERP_DIR"
      echo "  bun install"
      bun install >/dev/null 2>&1 || { echo "  bun install failed"; exit 1; }
      echo "  bun run build"
      bun run build >/dev/null 2>&1 || { echo "  bun run build failed"; exit 1; }
    ) && { echo "  built: $PERP_DIR/build/main.js"; note_installed "perplexity-server (built)"; } \
       || note_missing "perplexity-server (build failed)"
  else
    echo "  bundled source missing at $PERP_DIR"
    note_missing "perplexity-server source"
  fi
else
  echo "  skipped (bun missing)"
fi
echo ""

# --- step 5: register MCPs at user scope (idempotent) -----------------------
echo "[5/6] registering MCPs (claude mcp add --scope user)"
if [ "$HAS_CLAUDE" = "1" ]; then
  # paper-search
  if claude mcp get paper-search >/dev/null 2>&1; then
    echo "  paper-search: already registered -- skipping"
    note_skipped "paper-search MCP (already registered)"
  else
    if [ "$HAS_PY" = "1" ]; then
      if claude mcp add --scope user paper-search -- "$PY_BIN" -m paper_search_mcp.server >/dev/null 2>&1; then
        echo "  paper-search: registered"
        note_installed "paper-search MCP registration"
      else
        echo "  paper-search: registration failed -- run manually:"
        echo "    claude mcp add --scope user paper-search -- $PY_BIN -m paper_search_mcp.server"
        note_missing "paper-search MCP registration"
      fi
    else
      echo "  paper-search: skipped (python missing)"
    fi
  fi

  # perplexity-server
  if claude mcp get perplexity-server >/dev/null 2>&1; then
    echo "  perplexity-server: already registered -- skipping"
    note_skipped "perplexity-server MCP (already registered)"
  else
    if [ "$HAS_BUN" = "1" ] && [ -f "$PERP_DIR/build/main.js" ]; then
      if claude mcp add --scope user perplexity-server -- bun "$PERP_DIR/build/main.js" >/dev/null 2>&1; then
        echo "  perplexity-server: registered"
        note_installed "perplexity-server MCP registration"
        note_needs_key "PERPLEXITY_API_KEY -- export PERPLEXITY_API_KEY=<key> (https://docs.perplexity.ai/)"
      else
        echo "  perplexity-server: registration failed -- run manually:"
        echo "    claude mcp add --scope user perplexity-server -- bun $PERP_DIR/build/main.js"
        note_missing "perplexity-server MCP registration"
      fi
    else
      echo "  perplexity-server: skipped (bun or built artifact missing)"
    fi
  fi
else
  echo "  skipped (claude CLI missing)"
fi
echo ""

# --- step 6: print Firecrawl manual line ------------------------------------
echo "[6/6] Firecrawl MCP -- manual step (needs your API key)"
echo "  Get a key: https://firecrawl.dev/"
echo "  Then run:"
echo "    claude mcp add --transport http --scope user firecrawl https://mcp.firecrawl.dev/<FIRECRAWL_API_KEY>/v2/mcp"
note_needs_key "Firecrawl MCP -- run the printed 'claude mcp add' after you have a key"
echo ""

# --- final summary ----------------------------------------------------------
echo "============================================================"
echo "deep-research install summary"
echo "============================================================"
if [ -n "$INSTALLED" ]; then
  echo "Installed:"
  printf "$INSTALLED"
fi
if [ -n "$SKIPPED" ]; then
  echo "Skipped (already present):"
  printf "$SKIPPED"
fi
if [ -n "$MISSING" ]; then
  echo "Not installed (prereq missing or step failed):"
  printf "$MISSING"
fi
if [ -n "$NEEDS_KEY" ]; then
  echo "Needs an API key:"
  printf "$NEEDS_KEY"
fi
echo ""
echo "Next: 'claude mcp list' to verify, then trigger the skill with a research query."
echo "Onboarding: the skill will prompt you for category selection + key setup on first use."
