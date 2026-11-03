# deep-research

A Claude Code skill for research that routes each query to the right search engine instead of hitting the same one or two APIs for everything. Two modes: **Solo** for a fast, well-sourced answer (3–15 searches), **Team** for a comprehensive report built by 6–12 adversarial sub-agents across three waves (research → gap-filling → synthesis).

## Why "intent-routed"

Most research tools pick one search API and use it for every query. That's fine for general web search and bad for everything else — a clinical question needs PubMed and ClinicalTrials.gov, not a generic web index; a "find the team behind this startup" question needs People Data Labs and GitHub, not Google. This skill classifies the query first (general web, B2B/people, clinical/medical, academic, multi-step synthesis, or page extraction) and only then picks engines — with a primary, a fallback chain, and automatic backup-key failover on every paid one.

## What's code-enforced vs. what's a protocol

This matters enough to put in the README, not just in the skill's own docs. **Exa is mandatory in every run:** a live preflight (`exa_doctor.sh` from [`exa-search`](https://github.com/Huntehhh/exa-search)) runs first, and an Exa key error stops the run and asks you for a working key instead of quietly falling back to other engines. **Backup-key failover is real, tested code** — every engine wrapper retries with a `_BACKUP` key on a 401/402/403/429/5xx or a quota-language match, no exceptions. **Multi-round search (round-2 anti-overlap) and critical-path failure alerting are protocols the orchestrating agent follows**, not scripts that enforce them independently — there's a `dr_config.sh check-failures` command that gives you a real, script-checkable answer to "did anything critical fail during this run" instead of relying purely on the agent remembering to check. Full breakdown in [`SKILL.md`](SKILL.md#whats-code-enforced-vs-protocol-enforced).

## Solo mode

Classify → route → search → weight sources by trust level → synthesize with an executive summary, comparison tables, and prominent conflict callouts. Depth is adjustable ("quick" = 3–4 searches, default 5–10, "exhaustive" = 10–15).

## Team mode

Four templates — **Technical** (benchmarks + real user experience + FOR/AGAINST fact-checking), **Person** (career, worldview, social graph, controversy, philosophy), **Build-vs-Buy** (existing solutions, cost modeling, community health, DIY estimate), **Audience** (community scanning, pain points, competitor analysis, exact language). Wave 1 runs 5–6 agents in parallel; Wave 2 spawns 2–3 targeted agents to fill the gaps Wave 1 missed; Wave 3 synthesizes everything into `QUANTITATIVE.md`, `QUALITATIVE.md`, and a `VERDICT.md` with a confidence-rated recommendation.

## First-run setup: what it asks, and where things come from

The first time you trigger a research query, the skill checks whether it's configured and — if not — walks you through a guided setup instead of silently running with nothing available. It never blocks a research request on setup; it routes with whatever's configured and only flags it when a critical lane is missing its engines. Full flow: [`references/onboarding.md`](references/onboarding.md).

Nothing is bundled into this repo. Every dependency is fetched live, from its own source, with its own license intact:

| Component | Type | Required? | Fetched from | License | Needs a key? |
|---|---|---|---|---|---|
| **[exa-search](https://github.com/Huntehhh/exa-search)** | Claude Code skill | **Required** — semantic-search backbone; general, academic, and extraction all lean on it | `git clone`d from this GitHub account | MIT | `EXA_API_KEY` (free, 1,000/mo) |
| **paper-search-mcp** | MCP server | Required for the Academic lane | `pip install` from PyPI | MIT | none |
| **perplexity-server** | MCP server | Required for Multi-Step research + a free URL-extraction fallback | `git clone`d fresh from its own upstream author at install time — **never bundled here**, because it ships under a different, stronger-copyleft license than this skill | **GPL-3.0-or-later** | none — drives Perplexity's free web UI via browser automation, not the paid API |
| **Firecrawl** | MCP server (hosted) | Recommended — fastest page extraction; the other two extraction paths cover for it if it's absent | registered with your own key, nothing to clone | Firecrawl's own | `FIRECRAWL_API_KEY` (free, ~1,000 pages/mo) |
| **[nano-banana-pro](https://github.com/Huntehhh/nano-banana-pro)** | Claude Code skill | Optional — Team-mode chart generation only | `git clone`d from this GitHub account | MIT | `GEMINI_API_KEY` |
| **chrome-devtools** | MCP server | Optional — last-resort extraction fallback | `npx`, no install | — | none |
| **agent-teams** | Claude Code skill (reference only) | Not invoked at runtime; documented as the coordination-pattern reference this skill's Team mode follows | — | — | — |

**A note on perplexity-server:** it works by driving Perplexity's free web UI with Puppeteer — no account, no API key, effectively unlimited. That's genuinely useful, but it is not an officially sanctioned Perplexity integration, and it's licensed GPL-3.0 by its author — a copyleft license this repo doesn't want to inherit, which is exactly why the installer clones it fresh instead of vendoring its source. Read [Perplexity's Terms of Service](https://www.perplexity.ai/hub/legal/terms-of-service) before deciding how much to lean on it.

## Install

```bash
git clone https://github.com/Huntehhh/deep-research.git ~/.claude/skills/deep-research
cd ~/.claude/skills/deep-research

# macOS / Linux / Git-Bash / WSL:
bash _dependencies/install.sh

# Windows (PowerShell):
powershell -ExecutionPolicy Bypass -File _dependencies/install.ps1
```

The installer is idempotent — safe to re-run, skips anything already present — and prints exactly what it's doing at each step. Full breakdown of every step, plus the manual fallback if it fails partway: [`_dependencies/INSTALL.md`](_dependencies/INSTALL.md).

Then just ask Claude Code a research question. The onboarding flow triggers automatically on first use if nothing is configured yet.

## Layout

```
SKILL.md                    -- routing table, mode selection, execution rules
references/
  onboarding.md              -- the guided first-run setup flow, key-by-key
  routing.md                 -- authoritative engine call order, fallover, alerting
  engines.md                 -- full engine catalog
  architecture.md             -- Team mode pseudocode + gap-detection logic
  agent-templates.md          -- the 32 agent prompts across all 4 Team templates
  medical-sources.md          -- clinical/health-domain source list
  sources.md, output-format.md
scripts/
  dr_config.sh                -- onboarding state, key storage, check-failures
  engines/                    -- one wrapper script per search engine, shared fallover lib
_dependencies/
  install.sh, install.ps1     -- cross-platform installer (fetches everything above)
  INSTALL.md                  -- what gets installed, from where, under what license
```
