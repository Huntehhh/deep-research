# deep-research -- bundled dependencies installer

This folder ships everything the `deep-research` skill needs to run on a fresh machine: two MCP servers (Perplexity, paper-search) and one companion skill (exa-search). The installer registers them with the `claude` CLI at user scope so the skill can call them on demand.

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

## What the installer does

1. Checks prerequisites (`bun`, `python3 >= 3.10`, `claude` CLI). Missing tools print an install hint and the affected step is skipped; the rest still runs.
2. Copies `_dependencies/skills/exa-search` to `~/.claude/skills/exa-search` (skip if it already exists).
3. `pip install` the bundled `paper-search-mcp`. Falls back to `pip install paper-search-mcp` from PyPI on failure.
4. `bun install && bun run build` inside `_dependencies/MCPs/perplexity-server`.
5. Registers both MCPs at user scope (skips if `claude mcp get <name>` already succeeds):
   - `claude mcp add --scope user paper-search -- python3 -m paper_search_mcp.server`
   - `claude mcp add --scope user perplexity-server -- bun <SKILL_ROOT>/_dependencies/MCPs/perplexity-server/build/main.js`
6. Prints (does NOT auto-run) the Firecrawl line for you to run after you have a key.
7. Prints a summary of what was installed, skipped, and which keys still need to be set.

## Firecrawl -- manual step

Firecrawl is a hosted MCP; you register it with your own API key. Get a key at https://firecrawl.dev/ then run:

```
claude mcp add --transport http --scope user firecrawl https://mcp.firecrawl.dev/<FIRECRAWL_API_KEY>/v2/mcp
```

## API keys

`deep-research` reads keys from `~/.claude/deep-research/.env` first, then from the OS environment (OS env always wins). The skill's onboarding flow (`scripts/dr_config.sh set-key`) writes keys to the `.env` file with `chmod 600`. You can also export them in your shell rc:

- `EXA_API_KEY` -- https://dashboard.exa.ai/api-keys
- `PERPLEXITY_API_KEY` -- https://docs.perplexity.ai/
- `FIRECRAWL_API_KEY` -- baked into the Firecrawl MCP URL above (no env var needed)
- engine-specific keys (Tavily, Brave, Serper, etc.) -- see `references/engines.md`

## Manual fallback (if the installer fails)

If the one-command install fails, run these by hand:

```
# 1. exa-search skill
mkdir -p ~/.claude/skills
cp -R _dependencies/skills/exa-search ~/.claude/skills/exa-search

# 2. paper-search-mcp
python3 -m pip install _dependencies/MCPs/paper-search-mcp
# or fallback:
python3 -m pip install paper-search-mcp

# 3. perplexity-server
cd _dependencies/MCPs/perplexity-server
bun install
bun run build
cd -

# 4. Register MCPs at user scope
claude mcp add --scope user paper-search -- python3 -m paper_search_mcp.server
claude mcp add --scope user perplexity-server -- bun "$PWD/_dependencies/MCPs/perplexity-server/build/main.js"
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
python3 -m pip uninstall paper-search-mcp
```
