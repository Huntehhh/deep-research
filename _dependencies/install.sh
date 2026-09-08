#!/usr/bin/env bash
# install.sh -- bootstraps the deep-research skill's dependencies.
# Idempotent: safe to re-run. Skips anything already in place.
# Cross-platform: macOS (bash 3.2+), Linux, Windows Git-Bash / WSL.
#
# Nothing here is vendored into this repo. Every dependency is fetched live
# from its own source at install time -- one companion skill from Hunter's
# GitHub, one package from PyPI, one MCP server cloned from its upstream
# author. See references/onboarding.md for what each one does and why.
set -euo pipefail
export LC_ALL=C

# --- resolve paths -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOME_SKILLS="$HOME/.claude/skills"
DR_HOME="${DR_HOME:-$HOME/.claude/deep-research}"
VENDOR_DIR="$DR_HOME/vendor"

EXA_SEARCH_REPO="https://github.com/Huntehhh/exa-search.git"
PERPLEXITY_SERVER_REPO="https://github.com/wysh3/perplexity-mcp-zerver.git"

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

HAS_GIT=0
if command -v git >/dev/null 2>&1; then
  HAS_GIT=1
  echo "  git: $(git --version)"
else
  echo "  git: NOT FOUND -- install from https://git-scm.com/downloads"
  note_missing "git (skipped: exa-search + perplexity-server fetch)"
fi

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

# --- step 2: clone exa-search skill from GitHub ------------------------------
echo "[2/6] installing exa-search skill (from $EXA_SEARCH_REPO)"
EXA_DST="$HOME_SKILLS/exa-search"
if [ -d "$EXA_DST" ]; then
  echo "  $EXA_DST already exists -- skipping (re-install: 'rm -rf $EXA_DST' then re-run)"
  note_skipped "exa-search skill (already installed)"
elif [ "$HAS_GIT" = "1" ]; then
  mkdir -p "$HOME_SKILLS"
  if git clone --depth 1 "$EXA_SEARCH_REPO" "$EXA_DST" >/dev/null 2>&1; then
    rm -rf "$EXA_DST/.git"
    echo "  cloned -> $EXA_DST"
    note_installed "exa-search skill (cloned from GitHub)"
  else
    echo "  clone failed -- clone manually: git clone $EXA_SEARCH_REPO $EXA_DST"
    note_missing "exa-search skill (clone failed)"
  fi
else
  echo "  skipped (git missing) -- clone manually: git clone $EXA_SEARCH_REPO $EXA_DST"
  note_missing "exa-search skill (git missing)"
fi
echo ""

# --- step 3: install paper-search-mcp from PyPI ------------------------------
echo "[3/6] installing paper-search-mcp (PyPI, MIT license)"
if [ "$HAS_PY" = "1" ]; then
  if $PY_BIN -m pip install paper-search-mcp >/dev/null 2>&1; then
    echo "  installed from PyPI"
    note_installed "paper-search-mcp (PyPI)"
  else
    echo "  pip install failed -- run manually: $PY_BIN -m pip install paper-search-mcp"
    note_missing "paper-search-mcp (pip install failed)"
  fi
else
  echo "  skipped (python missing)"
fi
echo ""

# --- step 4: clone + build perplexity-server ---------------------------------
echo "[4/6] installing perplexity-server (from $PERPLEXITY_SERVER_REPO)"
echo "  License: GPL-3.0-or-later (upstream, not this skill's license -- kept out-of-tree for that reason)."
echo "  How it works: drives the free Perplexity web UI via Puppeteer, no API key. Review Perplexity's"
echo "  Terms of Service before relying on this in a way you're not comfortable with; it is not an"
echo "  officially sanctioned integration."
PERP_DIR="$VENDOR_DIR/perplexity-mcp-zerver"
if [ -d "$PERP_DIR" ]; then
  echo "  $PERP_DIR already exists -- skipping clone (re-install: 'rm -rf $PERP_DIR' then re-run)"
  note_skipped "perplexity-server source (already cloned)"
elif [ "$HAS_GIT" = "1" ]; then
  mkdir -p "$VENDOR_DIR"
  if git clone --depth 1 "$PERPLEXITY_SERVER_REPO" "$PERP_DIR" >/dev/null 2>&1; then
    echo "  cloned -> $PERP_DIR"
  else
    echo "  clone failed -- clone manually: git clone $PERPLEXITY_SERVER_REPO $PERP_DIR"
    note_missing "perplexity-server source (clone failed)"
  fi
else
  echo "  skipped (git missing) -- clone manually: git clone $PERPLEXITY_SERVER_REPO $PERP_DIR"
  note_missing "perplexity-server source (git missing)"
fi

if [ "$HAS_BUN" = "1" ] && [ -d "$PERP_DIR" ]; then
  (
    cd "$PERP_DIR"
    echo "  bun install"
    bun install >/dev/null 2>&1 || { echo "  bun install failed"; exit 1; }
    echo "  bun run build"
    bun run build >/dev/null 2>&1 || { echo "  bun run build failed"; exit 1; }
  ) && { echo "  built: $PERP_DIR/build/main.js"; note_installed "perplexity-server (cloned + built)"; } \
     || note_missing "perplexity-server (build failed)"
elif [ "$HAS_BUN" != "1" ]; then
  echo "  skipped build (bun missing)"
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

  # perplexity-server -- no API key needed, ever (it drives the free web UI).
  if claude mcp get perplexity-server >/dev/null 2>&1; then
    echo "  perplexity-server: already registered -- skipping"
    note_skipped "perplexity-server MCP (already registered)"
  else
    if [ "$HAS_BUN" = "1" ] && [ -f "$PERP_DIR/build/main.js" ]; then
      if claude mcp add --scope user perplexity-server -- bun "$PERP_DIR/build/main.js" >/dev/null 2>&1; then
        echo "  perplexity-server: registered (no API key required)"
        note_installed "perplexity-server MCP registration"
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
echo "  Get a key: https://www.firecrawl.dev/app/api-keys"
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
