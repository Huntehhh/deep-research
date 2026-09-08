# Deep Research — Guided Setup (choose-your-own-adventure)

How the skill onboards a new user: detect what's installed, walk them through the **required baseline** (the ~70% - the minimum for effective general deep research), then pitch the powerful other ~30% and let them pick the categories they care about. State is tracked in one file so the skill never re-scans the machine and never nags after the user is done.

## Table of contents
- [How setup works](#how-setup-works)
- [configuration.json](#configurationjson)
- [The flow](#the-flow)
- [Tier 1 - the recommended baseline](#tier-1---the-recommended-baseline)
- [Step 1 - the required baseline (the ~70%)](#step-1---the-required-baseline-the-70)
- [Step 2 - the other 30%: pick your categories](#step-2---the-other-30-pick-your-categories)
- [Per-category situational keys](#per-category-situational-keys)
- [Install mechanics](#install-mechanics)
- [dr_config.sh helper](#dr_configsh-helper)
- [Re-prompt behavior](#re-prompt-behavior)

---

## How setup works

Three pieces, all under `~/.claude/deep-research/`:

- **`configuration.json`** - tracks onboarding status + which components are confirmed/installed/keyed. **No secrets** live here. The gate-check reads it instead of probing the whole machine.
- **`.env`** - where the user's API keys are written (gitignored, never packaged). `engine_common.sh` sources it, but **OS environment variables win** if already set - so this never overrides a key the user already exported.
- **`_dependencies/`** (inside the skill) - bundled MCP source + the `exa-search` skill + cross-platform installers.

The flow **presents a required baseline** (the minimum that makes deep research effective) and walks the user through it - but the gate **never hard-blocks**: a user who just wants to research is routed with whatever's available, and only a *critical* lane missing its engines triggers a degraded-output callout. "Required" is firm guidance, not a wall.

---

## configuration.json

Seed it with `bash scripts/dr_config.sh init`. Shape (values shown are the empty-state defaults):

```jsonc
{
  "schemaVersion": 1,
  "onboarding": {
    "status": "not_started",          // not_started | in_progress | complete | declined
    "reminderPreference": "ask_next_time",  // ask_next_time | stop_asking
    "selectedCategories": [],         // any of: deep_general, academic_medical, b2b_intel, scraping_extraction
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
    "apiKeys": {
      "EXA_API_KEY":        { "tier": "baseline", "categories": ["deep_general","academic_medical","b2b_intel","scraping_extraction"], "confirmed": false, "hasKey": false, "status": "missing", "signupUrl": "https://dashboard.exa.ai/api-keys", "checkedAt": null }
      // ...one entry per key below; status: missing | present | invalid | untested
    }
  }
}
```

Field meaning: `confirmed` = the user said yes to setting it up; `installed` = detected present (`claude mcp list` / skill folder exists); `hasKey` = a value exists in `.env` or OS env; `status` for keys = `missing` (none), `present` (found), `untested` (found, not pinged), `invalid` (pinged, failed). **Never write a key value into this file** - only the boolean + status.

---

## The flow

1. **Gate-check** (SKILL.md): read `configuration.json`. Missing -> first run. `complete`/`stop_asking` -> straight to research. Otherwise a one-line nudge.
2. **Required baseline (the ~70%)**: present the minimum that makes general deep research effective - Exa + Firecrawl - framed as required, and walk the user through setting them up (perplexity-server + paper-search are already free + live). No quick/skip menu; just guide them through it.
3. **The other 30% + categories**: pitch what else the tool can do, with concrete examples per category, then multi-select "which categories are you interested in?"
4. **Per-category situational keys**: for each selected category, show its *additional* keys + signup URLs (Exa/Firecrawl already done). Install free skills/MCPs while the user fetches keys; write each key to `.env`, update config.
5. **Completion**: set `onboarding.status`; offer a live `doctor` ping of configured keys.

Always persist progress via `dr_config.sh` as you go, so a half-finished setup resumes cleanly next time.

---

## Tier 1 - the recommended baseline

Recommend these to everyone first. Three of the four are free with no key.

| Component | Type | Key needed | Free tier | Get it |
|---|---|---|---|---|
| **deep-research** | skill | - | - | already installed (this skill) |
| **exa-search** | skill | `EXA_API_KEY` | 1,000 credits/mo | installer copies it; key at https://dashboard.exa.ai/api-keys |
| **perplexity-server** | MCP | none | $0, effectively unlimited (browser automation) | installer builds it (Bun) |
| **paper-search** | MCP | none | $0 (21 academic sources) | installer installs it (pip) |
| **Firecrawl** | MCP | `FIRECRAWL_API_KEY` | 1,000 pages/mo, 2 concurrent | key at https://www.firecrawl.dev/app/api-keys |

Framing to use with the user:
- **exa-search** is a lightweight superset of the Exa MCP (curl + jq, no server) - it can replace the Exa MCP and adds deep-search, crawl, company/people, code-context, and find-similar. If they only want one general-web key, **Exa** is the one to get. **Tavily** (https://app.tavily.com, 1,000 credits/mo) is the budget alternative.
- **perplexity-server** drives the free Perplexity web UI via browser automation - **no API key, unlimited**. If they already run a Perplexity MCP, ours still installs cleanly alongside.
- **Firecrawl** is the preferred page-extraction engine (faster than any browser-driver). The free tier is generous; when it runs out the skill silently falls back and tells them at the end.

---

## Step 1 - the required baseline (the ~70%)

**Lead with this, framed as required** - it's the minimum that makes deep research genuinely effective and unlocks ~70% of the tool. Walk the user through it; do **not** offer a quick/skip menu. (If they truly don't want to, fall back to the gate's "ask next time / stop asking" - never force.)

Two keys are the baseline. perplexity-server + paper-search are already free and running after the installer, so the general + academic engines work out of the box - these two complete the picture:

- **`EXA_API_KEY`** - the semantic-search backbone; general, academic, and extraction all lean on it. https://dashboard.exa.ai/api-keys (1,000/mo free)
- **`FIRECRAWL_API_KEY`** - fast, reliable page extraction. https://www.firecrawl.dev/app/api-keys (1,000 pages/mo free)

Say something like:

> To make deep research genuinely effective there are two keys to set up - this is the required baseline, and it unlocks about 70% of what the tool does. perplexity-server and paper-search are already free and running, so this is quick. Let's grab them:
> 1. **Exa** (semantic search) - https://dashboard.exa.ai/api-keys
> 2. **Firecrawl** (fast extraction) - https://www.firecrawl.dev/app/api-keys

Walk them through one at a time: point to the URL, take the pasted key, `dr_config.sh set-key <NAME> <VALUE>`; for Firecrawl also `claude mcp add --transport http --scope user firecrawl https://mcp.firecrawl.dev/<KEY>/v2/mcp`. (Optional, keep it light: offer broader general-web breadth here too - Serper / Brave / Tavily / Linkup, all free tiers - but it's a nice-to-have, not required.) Then move to Step 2.

---

## Step 2 - the other 30%: pick your categories

With the baseline in, pitch the rest - **there's a lot more, and the other ~30% is where it gets powerful.** Give concrete examples so the user sees what each category unlocks, then run the multi-select.

Frame it like:

> That's the core covered - you can now do strong general deep research. There's a ton more this tool can do, and the other ~30% is very powerful. A taste of what each category adds:
> - **B2B, people & companies** - "find the team behind [startup] and their funding", "who's hiring [role] at [company]", "direct dial for [person]"
> - **Academic, studies & medical** - "peer-reviewed + clinical evidence for [compound]", "trials on [condition]", "compare [supplements] by study quality + interpret labs vs optimal ranges"
> - **Page scraping & extraction** - "pull clean content from these 10 paywalled / JS-heavy URLs", "extract structured fields from [site]"
> - **Broader general-web reach** - add more engines (Serper / Brave / Tavily / Linkup) for wider coverage on top of Exa
>
> Which categories are you interested in? (pick any - I'll set up just the extra keys each needs)

Multi-select (maps to `selectedCategories`):

> 1. **B2B, people & companies** -> `b2b_intel`
> 2. **Academic, studies & medical** -> `academic_medical`
> 3. **Page scraping & extraction** -> `scraping_extraction`
> 4. **Broader general-web reach** -> `deep_general`

Lane -> router categories (which engines each turns on):

| Lane | `selectedCategories` key | Router categories enabled |
|---|---|---|
| Deep general & niche findings | `deep_general` | General + Multi-Step/Agentic |
| Academic, studies & medical | `academic_medical` | Academic + Privacy/Clinical + Heavy-Extraction |
| B2B, investments & competitive intel | `b2b_intel` | B2B + Heavy-Extraction + Exa deep |
| Page scraping & extraction | `scraping_extraction` | Heavy-Extraction |

Record the picks: `bash scripts/dr_config.sh select-categories deep_general,academic_medical`.

---

## Per-category situational keys

Essentials (Exa, Firecrawl) are already done in Step 1 - this is the *situational* depth for each category the user picked from the other 30%. Present its extra keys (recommended first, then optional), each with a signup URL. Offer: *"Tell me which you want and I'll set them up - go to the URL, make an account, paste the key back."* Write each with `dr_config.sh set-key`. Items marked **(baseline)** below are already covered - listed only so the user sees the full picture.

### Lane 1 - Deep general & niche findings
**Recommended:** Exa (`EXA_API_KEY`, baseline) - perplexity-server (baseline, no key) - **Serper** (`SERPER_API_KEY`, https://serper.dev, 2,500 free queries one-time; biggest single-shot general-web quota).
**Optional:** Brave (`BRAVE_API_KEY`, https://brave.com/search/api/) - Tavily (`TAVILY_API_KEY`, https://app.tavily.com, 1,000/mo) - Linkup (`LINKUP_API_KEY`, https://app.linkup.so, 4,000 free queries) - **OpenRouter** (`OPENROUTER_API_KEY`, https://openrouter.ai/keys) for paid deep multi-step when the free perplexity-server can't reach.

### Lane 2 - Academic, studies & medical
**Recommended:** paper-search MCP (baseline, no key, 21 sources) - the clinical/gov wrappers PubMed / ClinicalTrials.gov / openFDA / RxNorm (**no key**) - Firecrawl (baseline) for fresh medical pages.
**Optional:** Unpaywall email (`PAPER_SEARCH_MCP_UNPAYWALL_EMAIL`, any email) - `NCBI_API_KEY` (https://www.ncbi.nlm.nih.gov/account/ -> Account settings -> API Key Management; lifts PubMed 3->10 req/s) - `OPENFDA_API_KEY` (https://open.fda.gov/apis/authentication/; 1k->120k/day) - Exa (`research paper` category, baseline).

### Lane 3 - B2B, investments & competitive intel
**Recommended:** **GitHub** via `gh` CLI (https://cli.github.com, then `gh auth login` - free, no key) - **PDL** (`PDL_API_KEY`, https://www.peopledatalabs.com/signup -> API Keys; free tier, limited fields).
**Optional:** TheirStack (`THEIRSTACK_API_KEY`, https://app.theirstack.com - hiring-signal, permanent free tier) - Explorium (`EXPLORIUM_API_KEY`, https://www.explorium.ai -> sign up -> API page; 500 enrich/mo) - Lusha (`LUSHA_API_KEY`, https://www.lusha.com -> Settings > API; phone lookups only, 40 credits/mo, API access may require a paid Lusha tier) - Exa deep + Firecrawl (baseline) for due-diligence reading.

### Lane 4 - Page scraping & extraction
**Recommended:** **Firecrawl** (baseline, preferred) - perplexity-server `extract_url_content` (baseline, free).
**Optional:** Brave (`BRAVE_API_KEY`) for `brave_llm_context` clean page text - Exa crawl (`EXA_API_KEY`, baseline) - **chrome-devtools** MCP (free, last-resort fallback for the toughest JS/Cloudflare pages; install with `claude mcp add`).

> Why several extraction options: no single scraper clears every site. Firecrawl handles most; perplexity/chrome catch what it can't; Brave's LLM-context endpoint returns pre-cleaned text. The router tries them cheapest-first and escalates to the user on a high-value page (see routing.md).

### Master key reference

| Key var | Service | Signup URL | Free tier |
|---|---|---|---|
| `EXA_API_KEY` | Exa | https://dashboard.exa.ai/api-keys | 1,000 credits/mo |
| `TAVILY_API_KEY` | Tavily | https://app.tavily.com | 1,000 credits/mo |
| `FIRECRAWL_API_KEY` | Firecrawl | https://www.firecrawl.dev/app/api-keys | 1,000 pages/mo |
| `SERPER_API_KEY` | Serper | https://serper.dev | 2,500 queries (one-time) |
| `BRAVE_API_KEY` | Brave Search | https://brave.com/search/api/ | free credit/mo |
| `LINKUP_API_KEY` | Linkup | https://app.linkup.so | 4,000 queries |
| `OPENROUTER_API_KEY` | OpenRouter | https://openrouter.ai/keys | pay-as-you-go |
| `PDL_API_KEY` | People Data Labs | https://www.peopledatalabs.com/signup | free (limited fields) |
| `THEIRSTACK_API_KEY` | TheirStack | https://app.theirstack.com | permanent free tier |
| `EXPLORIUM_API_KEY` | Explorium | https://www.explorium.ai | 500 enrich/mo |
| `LUSHA_API_KEY` | Lusha | https://www.lusha.com (Settings > API) | 40 credits/mo |
| `NCBI_API_KEY` | NCBI (optional) | https://www.ncbi.nlm.nih.gov/account/ | keyless 3/s -> 10/s |
| `OPENFDA_API_KEY` | openFDA (optional) | https://open.fda.gov/apis/authentication/ | keyless 1k/day -> 120k/day |
| (gh auth) | GitHub | https://cli.github.com | free |

Every paid/quota key also accepts a `<KEY>_BACKUP` variant for automatic fallover (Lusha is single-key, no backup).

---

## Install mechanics

The free components install with one command. Run the bundled installer:

- **macOS / Linux:** `bash _dependencies/install.sh`
- **Windows:** `powershell -ExecutionPolicy Bypass -File _dependencies/install.ps1`

It is idempotent (skips what's already present) and prints every command it runs. What it does:

1. Copies `_dependencies/skills/exa-search/` -> `~/.claude/skills/exa-search/` (skip if present).
2. `python -m pip install ./_dependencies/MCPs/paper-search-mcp` (PyPI `paper-search-mcp` as fallback).
3. `cd _dependencies/MCPs/perplexity-server && bun install && bun run build`.
4. Registers MCPs at **user scope** so they work in every project:
   - `claude mcp add --scope user paper-search -- python -m paper_search_mcp.server`
   - `claude mcp add --scope user perplexity-server -- bun <abs-path>/build/main.js`
   - Firecrawl (after the user has a key): `claude mcp add --transport http --scope user firecrawl https://mcp.firecrawl.dev/<FIRECRAWL_API_KEY>/v2/mcp`
5. Checks for Bun / Python 3.10+ / the `claude` CLI and prints install hints rather than failing silently.

Note for the user: `python -m pip` is the ASR-safe / cross-platform invocation. On Windows, the two stdio MCPs call `python`/`bun` directly (no `cmd /c` wrapper needed); only `npx`/`uvx`-based servers need that.

---

## dr_config.sh helper

`bash scripts/dr_config.sh <command>` (pure bash + jq, same dependencies as the rest of the skill):

| Command | Does |
|---|---|
| `init` | Seed `configuration.json` (status `not_started`) if absent |
| `status` | Print onboarding status + per-component state; runs the live checks below |
| `check` | Detect installed MCPs (`claude mcp list`) + key presence (`.env` / OS env); update `installed`/`hasKey`/`status` + `checkedAt` |
| `select-categories <c1,c2>` | Record the chosen lanes |
| `set-key <NAME> <VALUE>` | Write the key to `~/.claude/deep-research/.env` (chmod 600), set `hasKey=true` + `status=present` |
| `set <dotted.path> <value>` | Generic setter (e.g. `onboarding.status complete`, `onboarding.reminderPreference stop_asking`) |

---

## Re-prompt behavior

When the gate sees `not_started`/`in_progress` and the user isn't silenced, offer one non-blocking line:

> I noticed deep-research setup isn't finished ([N] of [M] recommended components ready). Want to (1) finish setup, (2) be asked next time, or (3) stop asking? I can also just research now with what's configured.

Map the answer: finish -> resume the flow; next time -> leave `ask_next_time`, set `lastPromptedAt`; stop asking -> `reminderPreference = stop_asking`. If the user just gives a research request, do that first and only mention setup if a critical lane is missing.
