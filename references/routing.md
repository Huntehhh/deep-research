# Multi-Engine Routing, Multi-Round Search, Fallover & Alerting

The operational brain for multi-engine mode. Exa runs in every category (SKILL.md, "Exa gate"); this file decides which engines join it and in what order. This file is the source of truth for routing; `SKILL.md` carries only a short summary that points here.

## Table of contents
- [Intent -> engine-category routing](#intent--engine-category-routing)
- [Multi-round search (the anti-overlap trick)](#multi-round-search)
- [Perplexity routing rule (load-bearing)](#perplexity-routing-rule)
- [Heavy extraction & credit-aware escalation](#heavy-extraction--credit-aware-escalation)
- [Lusha special-case routing](#lusha-special-case-routing)
- [Backup-key fallover](#backup-key-fallover)
- [Per-engine request caps](#per-engine-request-caps)
- [API failure alerting](#api-failure-alerting)

---

## Intent -> engine-category routing

Classify the query, then call that category's engine set. When intent is ambiguous, default to General and widen only if results are thin. **Exa is in every row:** it always runs, through the exa-search scripts, and the row decides what joins it.

| Query shape (trigger) | Category | Engines (in call order) |
|---|---|---|
| "look this up" / "what is" / generic web | **General** | **exa_search** (always) + serper -> brave_search -> linkup -> tavily / brave_llm_context for cleaned chunks |
| "find the team behind" / "who's at company X" / "look up [person]" / "enrich" | **B2B** | **exa_company / exa_linkedin** (always; `exa_agent.sh --sources fiber,similarweb,baselayer` for premium firmographics, traffic, KYB) + pdl_lookup, github_repo_people (repos), theirstack_jobs (hiring signal), explorium_enrich (company); contacts per the contact chain below |
| "find all" / "list every" / "enrich these rows" | **Lists** | **exa_agent.sh --effort auto** + a bounded `--schema`, rows via `--input` (ultra and budgets over $5 ask the user first) + pdl / theirstack / explorium for B2B fields |
| clinical / medical / peptide / lab / biomarker / drug / protocol | **Clinical** | **exa_search category `publication`** (always; anonymized term only) + pubmed_search + clinicaltrials_search + openfda_drug + rxnorm_lookup; brave_search (ZDR-eligible) for general web. PHI never leaves the boundary (below) |
| a specific person's labs / symptoms / case (HIPAA-adjacent) | **Privacy** | **exa_search** (always; anonymized terms only, accepted even though a standard Exa key has no zero data retention) + brave_search (ZDR-eligible). No other logged engine (serper / tavily / linkup) |
| "latest" / "today" / "recent" / "breaking" | **News/Freshness** | **exa_search category `news` + `startPublishedDate`** (always) + serper (tbs qdr:d) -> brave_search -> perplexity-server MCP for synthesized answer |
| "research this topic" / "compile a brief" / "synthesize evidence" / "deep dive" | **Multi-Step/Agentic** | **exa_deep_search, two-phase** (always) for an answer in seconds; **exa_agent.sh --effort medium** (high/xhigh when stakes are high) when it needs multi-hop research or per-claim verification + perplexity-server MCP; OpenRouter `perplexity/sonar-deep-research` or `openai/o4-mini-deep-research` only if the MCP can't |
| "find papers on" / "peer-reviewed" / "meta-analysis" / "study" | **Academic** | **exa_search category `publication`** (always; 350M papers) + paper-search MCP (21 sources); pubmed_search direct as fallback |
| "watch" / "monitor" / "alert me when" | **Monitoring** | exa-search **Monitors mode**: a short Q&A, then a monitor Exa runs on its own schedule |
| "scrape" / "extract page content from URL" | **Heavy Extraction** | **exa_crawl** (always first) -> Firecrawl MCP -> perplexity-server `extract_url_content` -> chrome-devtools MCP -> escalate (see [Heavy extraction & credit-aware escalation](#heavy-extraction--credit-aware-escalation)) |

**Wrapper location:** `scripts/engines/<engine>.sh` under this skill. Invoke with `bash scripts/engines/<name>.sh "<args>"`. Exa stays in the separate `exa-search` skill (`bash ~/.claude/skills/exa-search/scripts/exa_search.sh` and siblings). Never the claude.ai Exa connector (`mcp__claude_ai_Exa__*`).

---

## Multi-round search

Default to 2 rounds. Round 1 fires half the budget; round 2 explicitly filters out round-1 results and fills gaps. Without the anti-overlap injection, round 2 just repeats round 1 — that injection is the whole point.

| Depth | Total searches | Split | Rounds |
|---|---|---|---|
| **Basic** | 3 | 3 | single round |
| **Medium** (default) | 8 | 4 + 4 | round 1 + anti-overlap round 2 |
| **Max** | 15 | 7 + 8 | round 1 + anti-overlap round 2 |

User can override: "quick"/"basic", "deep"/"max", or "searches: N".

**Round-2 anti-overlap prompt (inject verbatim into the round-2 planning step):**

> Round 1 returned these URLs/sources: [list every round-1 result URL]. For round 2, find ONLY: (a) sources NOT in this list, (b) contradicting evidence, (c) unanswered open questions, (d) niche angles round 1 missed. Explicitly filter out anything overlapping with the list above.

Carry the round-1 URL list forward and dedupe round-2 hits against it before synthesizing.

**This is a protocol you (the orchestrating agent) execute, not a script that enforces it for you.** Nothing catches a skipped round 2 or a round 2 that quietly repeats round 1 — that's on you, every time.

---

## Perplexity routing rule

Load-bearing, non-negotiable:

1. **perplexity-server MCP first** — `$0`, scrapes the free web UI. Tools: `search`, `get_documentation`, `find_apis`, `chat_perplexity`, `extract_url_content`, `check_deprecated_code`.
2. **OpenRouter `perplexity/*` fallback ONLY** — when the MCP cannot expose a needed capability. Models: `perplexity/sonar-deep-research`, `perplexity/sonar-reasoning-pro`, `perplexity/sonar-pro`. Uses `OPENROUTER_API_KEY`.
3. **NEVER** manage a direct `PERPLEXITY_API_KEY`. It does not exist in the env by design.

OpenRouter call shape: POST `https://openrouter.ai/api/v1/chat/completions`, header `Authorization: Bearer $OPENROUTER_API_KEY`, body `{"model":"perplexity/sonar-deep-research","messages":[...]}`.

---

## Heavy extraction & credit-aware escalation

Extraction routes to the fastest capable tool, then degrades gracefully and **keeps the user in the loop on cost**.

**Order:**
1. **`exa_crawl.sh`** (Exa `/contents`) — always first: cheap and fast, from Exa's cache or a live crawl. A single URL that comes back empty, truncated, a block page, or with a per-URL error status (e.g. `CRAWL_NOT_FOUND`) is a miss, not an Exa failure: move on to step 2. Only an `EXA_FATAL`/`EXA_ERROR` marker triggers the Exa gate.
2. **Firecrawl MCP** (`firecrawl_scrape` for one page, `firecrawl_extract` for structured fields) — preferred after Exa. A hosted API: faster and lighter than any browser-driver, and it clears most Cloudflare / JS-rendered pages. Free tier ~1,000 pages/mo.
3. **perplexity-server `extract_url_content`** — free, but slower (drives a headless browser under the hood).
4. **chrome-devtools MCP** (`navigate_page` -> `take_snapshot`) — free, slowest, last resort.
5. If the category still can't get the page, you MAY reach for another MCP/skill that fits (a stealth browser tool, if the user has one). State which you used and why.

**Firecrawl quota (HTTP 402, or "limit"/"quota"/"insufficient credits" in the response) = stop using Firecrawl for this run.** Fall over to step 3/4 silently, then **tell the user at the very end** (not mid-task):

> Heads up — I used [perplexity extract / chrome-devtools] instead of Firecrawl on [N] page(s) because your Firecrawl plan limit was hit. A bit more compute, but the task still got done.

**High-value-source escalation (lean toward asking).** If a blocked or failing page is **(a) one the user specifically named, (b) clearly high-value, or (c) the missing piece that would close an open research gap**, prefer to STOP and ask rather than quietly skip it:

> This source looks important — [what it is] — and it'd fill [the specific gap]. Want me to: (1) add credits to [the tool most likely to crack it], (2) try another service, or (3) skip it and note the gap?

Honor the answer (the user may also propose a different tool). Push past a blocked high-value source **without** asking only when every available option is already exhausted — then surface it in the degraded-output callout.

---

## Lusha special-case routing

`lusha_phone.sh` is called ONLY when the intent is "find phone for [name]" / "direct dial for [person]". It is phone-lookup only (5 credits/phone, 40 credits/mo free, single key, no backup). Never use Lusha for bulk B2B — that routes to pdl/explorium/theirstack/github. Run `exa_linkedin.sh` first to pin down which person you mean (Exa runs in every lane).

### The contact chain (phones and emails)

Contact lookups use the existing tools, no more and no less, each tried only if the one before fails or comes back empty:

1. **`lusha_phone.sh <first> <last> <company>`**: phone numbers
2. **`pdl_lookup.sh enrich profile=<linkedin-or-github-url>`** (or `email=`, `name=` + `company=`): whatever contact fields the PDL plan returns

Exa never looks up contacts. Agent contact enrichment ($0.02/email, $0.07/phone) is off by design, and every exa-search script refuses an email or phone request with `EXA_POLICY` (exit 5). Both tools down → say so with the degraded-output callout ("Phone lookup unavailable"); don't route around it.

---

## Backup-key fallover

Handled automatically by `scripts/engines/engine_common.sh` (`dr_run_with_fallover`). Every paid/quota engine has `<ENGINE>_API_KEY` (primary) + `<ENGINE>_API_KEY_BACKUP`. On 401/402/403/429/5xx or a rate/quota body match, the wrapper retries with the backup key. Lusha is single-key (no backup) -> surfaces a critical alert on exhaustion. You do not orchestrate this; just read the wrapper's exit code and check stderr for a `DR_FAILURE:` line.

**Exa is the exception: no backup-key fallover, ever.** Every run uses the one global `EXA_API_KEY`; `EXA_API_KEY_BACKUP` is never read. An Exa failure is a hard stop (SKILL.md, "Exa gate"), and the exa-search scripts mark it with `EXA_FATAL:` / `EXA_ERROR:` rather than `DR_FAILURE:`.

---

## Per-engine request caps

The router should not burn a low-quota engine on traffic it could send elsewhere for free. Soft cap = start routing elsewhere; hard cap = stop + fall over.

| Engine | Hard cap/mo | Soft cap | At hard cap |
|---|---|---|---|
| serper | 4,500 | 4,000 | fall to brave_search |
| tavily | 1,800 | 1,500 | fall to brave_llm_context |
| brave_search | 1,800 | 1,500 | alert (no further free general option) |
| exa | your plan's credits | none | never diverted: Exa stays in every run. Out of credits = Exa returns 402 `NO_MORE_CREDITS`, the scripts print `EXA_FATAL`, and the run stops for a working key |
| linkup | $36 balance | $30 | alert + halt new linkup calls |
| pdl | 180 | 150 | fall to theirstack + github |
| lusha | 36 | 30 | alert (phone capacity exhausted) |
| explorium | 180 / 90d | 150 | alert; trial accounts time-bomb |
| theirstack | 90/day | 75/day | throttle hourly; alert if persistent |
| github | 4,500/hr | 4,000 | wait + retry (1hr reset) |

perplexity-server, paper-search MCP, and gov APIs (pubmed/openfda/rxnorm/clinicaltrials) have no practical cap.

---

## API failure alerting

Rule: if a **critical-path** query fails (engine down / quota-exhausted / key-invalid), ALERT the user. Do NOT silently downgrade a critical lane.

### Critical-path lanes (must alert on failure)

| Intent | Critical engines | Alert message |
|---|---|---|
| **Any lane** | exa (`EXA_FATAL`, or an `EXA_ERROR` that survives one retry) | Not a callout but a **halt**: "Exa isn't working, so I stopped. The error: [verbatim]. Paste a working Exa key and I'll continue." (SKILL.md, "Exa gate") |
| B2B / person lookup | pdl + explorium (both fail) | "B2B enrichment unavailable; proceeding with web-search-only results -- confirm before relying on output" |
| Phone lookup | lusha (single key) | "Phone lookup unavailable; Lusha quota exhausted or invalid. Wait until next month or upgrade." |
| Clinical evidence | paper-search MCP + pubmed (both fail) | "Academic search unavailable; results will lack peer-reviewed citations" |
| Privacy-sensitive (HIPAA-adjacent) | brave_search (ZDR-eligible) | "Brave down; this lane may use only Exa (anonymized) and Brave. Are Exa-only results enough? I won't fall back to another logged engine." -- ask the user |
| Multi-step research | perplexity-server + OpenRouter perplexity (both fail) | "Deep research unavailable; downgrade to manual exa+claude orchestration?" |

### Silent fallover OK (interchangeable lanes)

| Intent | Order | Behavior |
|---|---|---|
| General research | serper -> brave -> linkup -> tavily | silently fall over; log only. Exa is never in a silent chain: it always runs, and its failures halt |
| News/freshness | serper -> brave -> perplexity-server | silently fall over |
| Heavy extraction | Firecrawl MCP -> perplexity-server extract -> chrome-devtools | silently fall over between tools; surface the Firecrawl-quota + high-value-source notices per [Heavy extraction & credit-aware escalation](#heavy-extraction--credit-aware-escalation) |

### Degraded-output callout (prepend to final synthesis on a critical failure)

```
> [!WARNING] DEGRADED OUTPUT -- [engine class] unavailable
> [specific failure reason]
> Still in the output: [...] / Missing: [...]
> Suggested action: [retry later / sign up for X / upgrade Y]
```

Incidents are auto-logged by the wrappers to `~/.claude/deep-research-logs/api-failures.jsonl` (one JSON line per incident) for post-hoc rate-limit analysis.

**Verify, don't just remember.** Run `bash scripts/dr_config.sh check-failures --since <the Exa gate's pass time>` before finalizing any output — it reads this log (exa-search writes to it too) for hits since the run started. Exit 1: prepend the callout above. Exit 3: an Exa key failure was logged; don't deliver, stop and ask for a working key. The logging is code-enforced; whether the callout actually reaches the user was, until this command existed, entirely dependent on the orchestrating agent's memory.
