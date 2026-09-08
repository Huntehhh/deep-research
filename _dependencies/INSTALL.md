# deep-research -- dependency installer

Nothing in this skill vendors third-party source. The installer fetches everything live at
install time: one companion skill from Hunter's GitHub, one package from PyPI, and one MCP server
cloned straight from its own author's repo. That keeps this repo small, keeps every dependency on
its own upstream's license, and means you're always getting the current version of each, not a
snapshot that drifted the day it was bundled.

## One-command install

**macOS / Linux / Git-Bash / WSL:**

```
bash _dependencies/install.sh
```

**Windows (PowerShell):**

```
powershell -ExecutionPolicy Bypass -File _dependencies/install.ps1
```

Both installers are idempotent -- safe to re-run. They skip anything already in place.

## What gets installed, and from where

| Component | Type | Source | License | Needs a key? |
|---|---|---|---|---|
| **exa-search** | Claude Code skill | `git clone` from [`Huntehhh/exa-search`](https://github.com/Huntehhh/exa-search) → `~/.claude/skills/exa-search` | same as this repo | `EXA_API_KEY` (free, 1,000/mo) |
| **paper-search-mcp** | MCP server | `pip install paper-search-mcp` from PyPI | MIT ([openags/paper-search-mcp](https://github.com/openags/paper-search-mcp)) | none |
| **perplexity-server** | MCP server | `git clone` from [`wysh3/perplexity-mcp-zerver`](https://github.com/wysh3/perplexity-mcp-zerver) → `~/.claude/deep-research/vendor/perplexity-mcp-zerver`, then built with Bun | **GPL-3.0-or-later** -- a different, stronger-copyleft license than this repo's. Kept out of this repo entirely for that reason; the installer clones it fresh instead of bundling it. | none -- it drives the free Perplexity web UI directly (no account, no API key). Review [Perplexity's Terms of Service](https://www.perplexity.ai/hub/legal/terms-of-service) before relying on this; it is not an officially sanctioned integration. |
| **Firecrawl** | MCP server (hosted) | registered via `claude mcp add` after you get a key -- nothing to clone | Firecrawl's own | `FIRECRAWL_API_KEY` (free, ~1,000 pages/mo) |

## What the installer does, step by step

1. Checks prerequisites (`git`, `bun`, `python3 >= 3.10`, `claude` CLI). Missing tools print an install hint and the affected step is skipped; the rest still runs.
2. `git clone`s `exa-search` from GitHub into `~/.claude/skills/exa-search` (skip if it already exists).
3. `pip install paper-search-mcp` from PyPI.
4. `git clone`s `perplexity-mcp-zerver` into `~/.claude/deep-research/vendor/`, then `bun install && bun run build`.
5. Registers both MCPs at user scope (skips if `claude mcp get <name>` already succeeds):
   - `claude mcp add --scope user paper-search -- python3 -m paper_search_mcp.server`
   - `claude mcp add --scope user perplexity-server -- bun <vendor-path>/build/main.js`
6. Prints (does NOT auto-run) the Firecrawl line for you to run after you have a key.
7. Prints a summary of what was installed, skipped, and which keys still need to be set.

## Firecrawl -- manual step

Firecrawl is a hosted MCP; you register it with your own API key. Get a key at https://www.firecrawl.dev/app/api-keys then run:

```
claude mcp add --transport http --scope user firecrawl https://mcp.firecrawl.dev/<FIRECRAWL_API_KEY>/v2/mcp
```

## API keys

`deep-research` reads keys from `~/.claude/deep-research/.env` first, then from the OS environment (OS env always wins). The skill's onboarding flow (`scripts/dr_config.sh set-key`) writes keys to the `.env` file with `chmod 600`. You can also export them in your shell rc:

- `EXA_API_KEY` -- https://dashboard.exa.ai/api-keys
- `FIRECRAWL_API_KEY` -- baked into the Firecrawl MCP URL above (no env var needed)
- engine-specific keys (Tavily, Brave, Serper, etc.) -- see `references/engines.md`

**perplexity-server needs no key of any kind** -- it is browser automation against Perplexity's free web UI, not the paid API. There is no `PERPLEXITY_API_KEY` in this skill's design; see `references/routing.md#perplexity-routing-rule` for why.

## Manual fallback (if the installer fails)

If the one-command install fails, run these by hand:

```
# 1. exa-search skill
mkdir -p ~/.claude/skills
git clone https://github.com/Huntehhh/exa-search.git ~/.claude/skills/exa-search

# 2. paper-search-mcp
python3 -m pip install paper-search-mcp

# 3. perplexity-server
mkdir -p ~/.claude/deep-research/vendor
git clone https://github.com/wysh3/perplexity-mcp-zerver.git ~/.claude/deep-research/vendor/perplexity-mcp-zerver
cd ~/.claude/deep-research/vendor/perplexity-mcp-zerver
bun install
bun run build
cd -

# 4. Register MCPs at user scope
claude mcp add --scope user paper-search -- python3 -m paper_search_mcp.server
claude mcp add --scope user perplexity-server -- bun ~/.claude/deep-research/vendor/perplexity-mcp-zerver/build/main.js
```

## Verify

```
claude mcp list
```

You should see `paper-search` and `perplexity-server` listed. Then trigger the skill with a research query and the skill will run its onboarding flow (category selection + key setup) on first use.

## Uninstall

```
claude mcp remove --scope user paper-search
claude mcp remove --scope user perplexity-server
claude mcp remove --scope user firecrawl
rm -rf ~/.claude/skills/exa-search
rm -rf ~/.claude/deep-research/vendor/perplexity-mcp-zerver
python3 -m pip uninstall paper-search-mcp
```
