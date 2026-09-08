# Multi-Engine Routing, Multi-Round Search, Fallover & Alerting

The operational brain for multi-engine mode. Loaded when a research query needs more than Exa. This file is the source of truth for routing; `SKILL.md` carries only a short summary that points here.

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

Classify the query, then call that category's engine set. When intent is ambiguous, default to General and widen only if results are thin.

| Query shape (trigger) | Category | Engines (in call order) |
|---|---|---|
| "look this up" / "what is" / generic web | **General** | serper -> brave_search -> exa (via exa-search skill) -> linkup -> tavily / brave_llm_context for cleaned chunks |
| "find the team behind" / "who's at company X" / "look up [person]" / "enrich" | **B2B** | pdl_lookup, github_repo_people (repos), theirstack_jobs (hiring signal), explorium_enrich (company); see Lusha rule for phone |
| clinical / medical / peptide / lab / biomarker / drug / protocol | **Privacy/Clinical** | pubmed_search + clinicaltrials_search + openfda_drug + rxnorm_lookup; brave_search (ZDR-eligible) for general web. PHI never leaves the boundary (below) |
| "latest" / "today" / "recent" / "breaking" | **News/Freshness** | serper (tbs qdr:d) -> brave_search -> perplexity-server MCP for synthesized answer |
| "research this topic" / "compile a brief" / "synthesize evidence" / "deep dive" | **Multi-Step/Agentic** | perplexity-server MCP first; EXA Deep Research and/or OpenRouter `perplexity/sonar-deep-research` or `openai/o4-mini-deep-research` only if MCP can't |
| "find papers on" / "peer-reviewed" / "meta-analysis" / "study" | **Academic** | paper-search MCP (21 sources) first; pubmed_search direct as fallback |
| "scrape" / "extract page content from URL" | **Heavy Extraction** | Firecrawl MCP (fastest) -> perplexity-server `extract_url_content` -> chrome-devtools MCP -> escalate (see [Heavy extraction & credit-aware escalation](#heavy-extraction--credit-aware-escalation)) |

**Wrapper location:** `scripts/engines/<engine>.sh` under this skill. Invoke with `bash scripts/engines/<name>.sh "<args>"`. Exa stays in the separate `exa-search` skill (`bash ~/.claude/skills/exa-search/scripts/exa_search.sh`).

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
1. **Firecrawl MCP** (`firecrawl_scrape` for one page, `firecrawl_extract` for structured fields) — preferred. A hosted API: faster and lighter than any browser-driver, and it clears most Cloudflare / JS-rendered pages. Free tier ~1,000 pages/mo.
2. **perplexity-server `extract_url_content`** — free, but slower (drives a headless browser under the hood).
3. **chrome-devtools MCP** (`navigate_page` -> `take_snapshot`) — free, slowest, last resort.
4. If the category still can't get the page, you MAY reach for another MCP/skill that fits (a stealth browser tool, if the user has one). State which you used and why.

**Firecrawl quota (HTTP 402, or "limit"/"quota"/"insufficient credits" in the response) = stop using Firecrawl for this run.** Fall over to step 2/3 silently, then **tell the user at the very end** (not mid-task):

> Heads up — I used [perplexity extract / chrome-devtools] instead of Firecrawl on [N] page(s) because your Firecrawl plan limit was hit. A bit more compute, but the task still got done.

**High-value-source escalation (lean toward asking).** If a blocked or failing page is **(a) one the user specifically named, (b) clearly high-value, or (c) the missing piece that would close an open research gap**, prefer to STOP and ask rather than quietly skip it:

> This source looks important — [what it is] — and it'd fill [the specific gap]. Want me to: (1) add credits to [the tool most likely to crack it], (2) try another service, or (3) skip it and note the gap?

Honor the answer (the user may also propose a different tool). Push past a blocked high-value source **without** asking only when every available option is already exhausted — then surface it in the degraded-output callout.

---

## Lusha special-case routing

`lusha_phone.sh` is called ONLY when the intent is "find phone for [name]" / "direct dial for [person]". It is phone-lookup only (5 credits/phone, 40 credits/mo free, single key, no backup). Never use Lusha for bulk B2B — that routes to pdl/explorium/theirstack/github.

---

## Backup-key fallover

Handled automatically by `scripts/engines/engine_common.sh` (`dr_run_with_fallover`). Every paid/quota engine has `<ENGINE>_API_KEY` (primary) + `<ENGINE>_API_KEY_BACKUP`. On 401/402/403/429/5xx or a rate/quota body match, the wrapper retries with the backup key. Lusha is single-key (no backup) -> surfaces a critical alert on exhaustion. You do not orchestrate this; just read the wrapper's exit code and check stderr for a `DR_FAILURE:` line.

---

## Per-engine request caps

The router should not burn a low-quota engine on traffic it could send elsewhere for free. Soft cap = start routing elsewhere; hard cap = stop + fall over.

| Engine | Hard cap/mo | Soft cap | At hard cap |
|---|---|---|---|
| serper | 4,500 | 4,000 | fall to brave_search |
| tavily | 1,800 | 1,500 | fall to brave_llm_context |
| brave_search | 1,800 | 1,500 | alert (no further free general option) |
| exa | 900 | 700 | fall to brave/linkup |
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
| B2B / person lookup | pdl + explorium (both fail) | "B2B enrichment unavailable; proceeding with web-search-only results -- confirm before relying on output" |
| Phone lookup | lusha (single key) | "Phone lookup unavailable; Lusha quota exhausted or invalid. Wait until next month or upgrade." |
| Clinical evidence | paper-search MCP + pubmed (both fail) | "Academic search unavailable; results will lack peer-reviewed citations" |
| Privacy-sensitive (HIPAA-adjacent) | brave_search (ZDR-eligible) | "Brave down; falling back to a logged engine would violate ZDR posture. Halting -- ask user." |
| Multi-step research | perplexity-server + OpenRouter perplexity (both fail) | "Deep research unavailable; downgrade to manual exa+claude orchestration?" |

### Silent fallover OK (interchangeable lanes)

| Intent | Order | Behavior |
|---|---|---|
| General research | serper -> brave -> exa -> linkup -> tavily | silently fall over; log only |
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

**Verify, don't just remember.** Run `bash scripts/dr_config.sh check-failures` before finalizing any output — it reads this log for critical-path hits since the run started and exits non-zero if you need to prepend the callout above. The logging is code-enforced; whether the callout actually reaches the user was, until this command existed, entirely dependent on the orchestrating agent's memory.
