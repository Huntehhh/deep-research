---
name: deep-research
description: >
  Research any topic via an intent-routed multi-engine search backend - solo mode for quick lookups, team mode for comprehensive adversarial reports. Routes each query by intent: general web, B2B/people/company, clinical/medical, academic papers (paper-search MCP, 21 sources), $0 multi-step research (perplexity-server MCP), and heavy URL extraction (Firecrawl MCP + fallbacks). Exa (exa-search skill, global EXA_API_KEY) is mandatory in every run: a live preflight gate (`exa_doctor.sh`) runs first, and on any Exa key error the protocol is to stop and ask the user for a working key. Other engines get code-enforced backup-key fallover (engine_common.sh); multi-round search and critical-path alerting are agent protocols, checked at run end by `dr_config.sh check-failures`. Solo: 3-15 queries. Team: 6-12 adversarial agents across 3 waves. Auto-detects mode + intent. Run via sub-agent to protect the main context window; incidental mid-task lookups (checking a version, confirming syntax) need only a single search tool call, not this skill. Chains: exa-search, nano-banana-pro, agent-teams. Triggers on (non-exhaustive): "research this", "search the web", "compare options", "find alternatives to", "deep dive on", "deep research", "research team", "who is [person]", "find the team behind", "find papers on", "clinical evidence for", "find phone for", "build vs buy", "audience research", "investigate", "comprehensive research".
---

# Deep Research

One skill, two modes, one engine arsenal. **Solo** for fast lookups. **Team** for comprehensive adversarial reports. Both ride on an **intent-routed multi-engine backend** — the query's shape decides which engines fire.

---

## Exa gate (first step of every run, hard stop)

Exa is this skill's semantic backbone and is **mandatory in every run**: solo or team, every Wave-1 agent, every gap-fill, every category. Reach it **only through the `exa-search` skill's scripts**. They read the key from the **global environment** (`EXA_API_KEY`; on Windows the User-scope variable wins over whatever the process inherited). Never use the claude.ai Exa connector (`mcp__claude_ai_Exa__*`): it holds its own copy of a key, can return 401 while yours works, and agents then wrongly report "Exa unavailable". Never put the Exa key in this skill's `.env` either; exa-search doesn't read it.

1. **Before any search or agent spawn**, run `bash ~/.claude/skills/exa-search/scripts/exa_doctor.sh`. It passes only when Exa actually answers, and ends with `Exa gate passed at <UTC time>`. Keep that time for `check-failures --since` at the end.
2. **It fails, or exa-search isn't installed: STOP.** No other engine, no agents, no partial answer. Show the user the exact error lines and ask for a working key, e.g.:
   > Exa isn't working, so I stopped before researching. The error:
   > `EXA_FATAL: reason=invalid-key status=401 endpoint=/search` *(paste the real lines)*
   > Paste a working Exa API key (https://dashboard.exa.ai/api-keys) and I'll check it, save it as your global `EXA_API_KEY`, and pick up where we left off.

   Running as a sub-agent? You can't ask the user. Return at once with `EXA_FAILURE:` plus the verbatim error; the parent session asks.
3. **They paste a key:** `bash ~/.claude/skills/exa-search/scripts/exa_set_key.sh <key>`. It checks the key live, never saves one that fails, and writes the global variable. Re-run step 1, then resume.
4. **Mid-run, every Exa script failure starts with one marker on stderr:**
   - `EXA_FATAL:` (exit 3): key missing, rejected, out of credits, over budget, or team blocked. Stop the whole run now: stop running agents, launch nothing new, don't synthesize partial results. Show the verbatim error and ask for a working key (step 2).
   - `EXA_ERROR:` (exit 1): bad parameter, plan-disabled option, content filter, rate limit, overload, timeout. Fix what the message says, or wait a few seconds, and retry once. If the retry fails too, stop and show the user the verbatim error. Never carry on quietly without Exa.
5. **No backup key for Exa**, by design. Every run uses the one global key; `EXA_API_KEY_BACKUP` is never read.

**Privacy-sensitive (HIPAA-adjacent) queries use Exa too, with anonymized terms only** (the PHI rule below). That's a deliberate trade: Exa offers zero data retention only on Enterprise plans, and on a standard key its privacy policy lets it train on queries. No other logged engine joins that lane.

## First-run setup check

Then check setup state once — run `bash scripts/dr_config.sh status` (reads `~/.claude/deep-research/configuration.json`):
- **No config file** -> first run. Briefly offer the guided setup ([references/onboarding.md](references/onboarding.md)), then proceed.
- **`onboarding.status == complete`** OR **`reminderPreference == stop_asking`** -> skip setup; go straight to research.
- **`not_started` / `in_progress`** (and not silenced) -> one non-blocking line: *finish setup / ask next time / stop asking*. Persist the answer via `dr_config.sh`.

**Never block research on setup, except for Exa** (the gate above). Route with whatever else is configured; surface a degraded-output callout only when a *critical* lane (B2B / clinical / multi-step / phone) lacks its engines. Full choose-your-own-adventure setup, per-category keys + signup URLs: [references/onboarding.md](references/onboarding.md).

---

## Engine Arsenal & Intent Routing

Before searching, classify the query, then fire **Exa plus that category's engines**. Exa runs in every category (the gate above); the category decides what joins it. Quick map below; **[references/routing.md](references/routing.md) is authoritative** for full call-order, fallover, caps, and the heavy-extraction credit-aware escalation. Exa scripts live in `~/.claude/skills/exa-search/scripts/`.

| Query shape | Category | Exa's job (every run) | Category engines (full order -> routing.md) |
|---|---|---|---|
| generic web / "what is" / "look this up" | **General** | `exa_search.sh` (+ `exa_deep_search.sh` for depth) | `serper_search.sh` -> brave -> linkup / tavily |
| "find the team behind" / "look up [person/company]" / enrich | **B2B** | `exa_company.sh`, `exa_linkedin.sh`; `exa_agent.sh --sources fiber,similarweb,baselayer` for premium firmographics, traffic, KYB | `pdl_lookup.sh` (+ github/theirstack/explorium) |
| clinical / peptide / drug / biomarker / lab / protocol | **Clinical** | `exa_search.sh` category `publication` (anonymized term only) | `pubmed_search.sh` (+ clinicaltrials/openfda/rxnorm) |
| a specific person's labs / symptoms / case (HIPAA-adjacent) | **Privacy** | `exa_search.sh`, anonymized terms only | `brave_search.sh`; no other logged engine |
| "latest" / "today" / "breaking" | **News** | `exa_search.sh` category `news` + `startPublishedDate` | `serper_search.sh` (qdr:d) -> brave -> perplexity-server |
| "research this" / "compile a brief" / "synthesize" | **Multi-Step** | `exa_deep_search.sh`, two-phase, for an answer in seconds; `exa_agent.sh --effort medium` (`high` when stakes are high) to research it properly | perplexity-server MCP (OpenRouter `perplexity/*` fallback only) |
| "find all" / "list every" / "enrich these rows" | **Lists** | `exa_agent.sh --effort auto` + bounded `--schema`; rows via `--input` (ultra asks first) | pdl / theirstack / explorium for B2B fields |
| "find papers on" / "peer-reviewed" / "meta-analysis" | **Academic** | `exa_search.sh` category `publication` (350M papers) | paper-search MCP (21 sources) |
| "scrape" / "extract URL content" | **Heavy Extraction** | `exa_crawl.sh` first | Firecrawl MCP (-> perplexity extract -> chrome-devtools; credit-aware) |
| "find phone / email for [person]" / "direct dial" | **Contacts** | `exa_linkedin.sh` to pin down *who* they are, never their contact data | `lusha_phone.sh`, then `pdl_lookup.sh` only if Lusha fails (contacts never come from Exa) |
| "watch" / "monitor" / "alert me when" | **Monitoring** | exa-search **Monitors mode** (`references/monitors-mode.md` there): set up once, Exa runs it | — |

Wrappers: `bash scripts/engines/<name>.sh "<args>"` (keys read from env, primary->backup fallover automatic). Exa: the exa-search scripts, one global key, no fallover. Full catalog: [references/engines.md](references/engines.md). Full routing/multi-round/alerting rules: [references/routing.md](references/routing.md).

**Four load-bearing rules** (do not violate):
1. **Exa in every run, through the exa-search scripts only**, behind the [Exa gate](#exa-gate-first-step-of-every-run-hard-stop). An Exa failure that survives one retry halts the run; it never falls over to another engine.
2. **Multi-round, default 2.** Round 1 fires half the budget (medium=8 -> 4+4, max=15 -> 7+8). Round 2 MUST inject the anti-overlap prompt (filter out round-1 URLs; find only gaps/contradictions/new angles). See [references/routing.md#multi-round-search](references/routing.md#multi-round-search).
3. **Perplexity = perplexity-server MCP first**, OpenRouter `perplexity/*` fallback ONLY, **never** a direct `PERPLEXITY_API_KEY`.
4. **Alert on critical-path failure.** B2B / phone / clinical-evidence / privacy / multi-step lanes must surface a degraded-output callout when their engines fail — never silently downgrade. General/news/extraction lanes fall over silently. See [references/routing.md#api-failure-alerting](references/routing.md#api-failure-alerting).

**PHI safety rule:** for clinical queries, send only the anonymized term (drug/condition/biomarker) to external APIs. Patient identifiers never cross the wire.

**Before finalizing any output (solo or team), run `bash scripts/dr_config.sh check-failures --since <the gate's pass time>`.** It reads the wrappers' own failure log (exa-search writes to it too) and tells you whether anything critical failed during this run — a real backstop against forgetting, not just a reminder to remember. Exit 3 = an Exa key failure was logged: don't deliver; stop and ask for a working key ([Exa gate](#exa-gate-first-step-of-every-run-hard-stop), step 2). Exit 1 = a critical-path engine failed; prepend the callout from [references/routing.md#api-failure-alerting](references/routing.md#api-failure-alerting) before answering.

---

## Mode Selection

When triggered, auto-detect mode from the user's request:

### Default to Solo Mode when:
- Simple factual query ("what is X", "find Y", "look this up")
- Quick comparison ("X vs Y" with clear criteria)
- User says "quick", "look up", "search for", or doesn't need depth
- Product research, competitive intel, repo discovery
- Short questions that can be answered with 3-15 searches

### Auto-Select Team Mode when:
- Query explicitly says "deep research", "research team", "full analysis", "comprehensive", "investigate"
- Person profiling ("who is X", "tell me about [person]")
- Build-vs-buy ("should we build", "existing solutions for")
- Audience discovery ("who wants", "target market", "audience for")
- Adversarial analysis ("pros and cons", "for and against", "devil's advocate")

### Suggest Team Mode (50-89% confidence) when:
- Query is broad enough that solo would miss angles ("research X" where X is complex)
- Multiple comparison targets ("X vs Y vs Z")
- Contested claims where FOR/AGAINST would help

**When suggesting, present options:**
```
This looks like it'd benefit from team research. Options:
1. TECHNICAL team (5 agents) — benchmarks, user experiences, fact-checking, practical tips
2. PERSON team (5 agents) — career, worldview, social graph, controversy, philosophy
3. BUILD-VS-BUY team (6 agents) — solutions, FOR/AGAINST, cost modeling, community health
4. AUDIENCE team (5 agents) — communities, pain points, competitors, language, watering holes
5. Quick solo (5-10 searches) — fast answer, no agents

Which one? Or just say "go" for my recommendation.
```

**Explicit user choice always wins.** Never override a user who asks for "quick" or "team".

---

## Solo Mode

### Prerequisites — the engine arsenal

Solo mode routes by intent (see [Engine Arsenal & Intent Routing](#engine-arsenal--intent-routing) above). Exa always fires; don't stop at Exa either — pick the category, fire its engines too, fall over per [references/routing.md](references/routing.md).

**Resolution order within the General category:**
1. **Exa, always:** `bash ~/.claude/skills/exa-search/scripts/exa_search.sh` for semantic discovery, `exa_deep_search.sh` when the question needs synthesis
2. `scripts/engines/serper_search.sh` (biggest free quota) -> `brave_search.sh` (independent index) for keyword/SERP coverage
3. `linkup_search.sh` / `tavily_search.sh` / `brave_llm_context.sh` for cleaned LLM-ready content
4. Exa failing -> the [Exa gate](#exa-gate-first-step-of-every-run-hard-stop) (stop and ask). Every other engine down on a critical lane -> surface the degraded-output callout and ask the user.

For B2B, clinical, academic, multi-step, news, phone, and extraction queries, route to that category's engines/MCPs instead.

### Execution

#### 1. Plan Based on User Query

**Depth** (user can override with "quick", "exhaustive", or "searches: N"):
- Quick: 3-4 searches
- Default: 5-10 searches
- Exhaustive: 10-15 searches

**Tailor everything to the query.** Identify:
- What decision is the user trying to make?
- What criteria matter most for their use case?
- What would make this response genuinely useful to them?

#### 2. Search Strategy

Execute in order, adapting to query type:

1. **Exa semantic** (2-4 queries) — conversational queries like "developers who switched from X to Y and why", through the exa-search scripts (never the `mcp__claude_ai_Exa__*` tools)
   - `exa_deep_search.sh` for research tasks
   - `exa_code.sh` for code/repos
   - `exa_search.sh "<query>" 8 auto "<category>"` when the content type is known: `company`, `people`, `publication`, `news`, `personal site`, `financial report` (`research paper` became `publication`; `pdf`/`github` are being deprecated; `tweet` is gone)
   - Set `EXA_OBJECTIVE="<what this research needs>"` so Exa ranks for the task, not just the query
   - `lite` instead of `auto` when one step fires 10+ searches (near-identical answers, half the latency)

2. **Targeted web_search** (3-5 queries) — site-specific patterns
   - See `references/sources.md` for query patterns by category
   - **For medical / clinical / health / pharmaceutical / supplement / peptide / lab-test / protocol / biotech / regulatory topics, ALSO load `references/medical-sources.md`** — exhaustive medical-domain source list (FDA / DEA / 503A/B / PCAC databases, USP / NSF / ConsumerLab / Janoshik testing, ClinicalTrials.gov + PubMed + Cochrane, functional-medicine specialty labs, peptide + biohacker subreddits, clinician podcasts like Huberman/Attia/Patrick, influencer + search-trend tools, practitioner forums, plus query-pattern templates per medical sub-domain).

3. **Validation** (1-2 queries) — complaints, limitations, "switched from X", pricing changes

#### 3. Weight & Synthesize

| Source Type | Trust Level |
|-------------|-------------|
| Reddit threads, HN, GitHub issues, personal blogs | High |
| IndieHackers, ProductHunt, dev.to, Lobsters, Substack | Medium |
| PubMed, examine.com, Google Scholar | High (health) |
| Official docs, marketing pages | Low — verify with user sources |
| Affiliate listicles | Ignore |

**Key rules:**
- Corroboration across 2+ sources = high confidence
- Conflicting opinions = highlight prominently (valuable signal)
- Single-source claims = flag as unverified

### Solo Output Format

See `references/output-format.md` for structure examples.

**Core principles:**
- Open with 2-3 sentence summary: recommendation + reasoning + confidence
- Use comparison tables for 2+ options
- Surface conflicts/tradeoffs prominently — don't bury negatives
- Cite source types for transparency
- Save structured output to markdown file

### Query-Specific Notes

- **Products/tools**: Frame around "who should use this"
- **Health/supplements**: Note study quality (RCT vs observational), sample sizes, conflicts of interest
- **Code/repos**: Include maintenance status, license, ecosystem fit
- **"vs" queries**: Structure around the user's likely decision criteria
- **"alternative to X"**: Identify what's wrong with X first, then solve those pain points

---

## Team Mode (Multi-Agent Adversarial Research)

When Team mode is selected (auto or by user), run the full 3-wave pipeline.

**Architecture doc:** `references/architecture.md` (detailed blueprint with pseudocode, gap detection logic, quality gates)
**Agent templates:** `references/agent-templates.md` (32 detailed prompts for all 4 modes)

### Team Templates

#### TECHNICAL — "How does X actually perform?"
**Wave 1 (5 agents, parallel):**
1. **Quantitative Benchmarker** — Hard numbers only. Scores, latency, cost at specific configurations.
2. **Qualitative Experience Researcher** — Real user experiences only. Reddit, HN, Substack quotes.
3. **Fact-Checker FOR** — Verify claims supporting X. Strongest affirmative case.
4. **Fact-Checker AGAINST** — Devil's advocate. Counter-evidence, weaknesses, competitors that beat X.
5. **Practical Strategy Researcher** — HOW to use X. Gotchas, optimization tips, patterns.

#### PERSON — "Who is X, really?"
**Wave 1 (5 agents, parallel):**
1. **Professional History** — Career, companies, roles, education, achievements.
2. **Content/Worldview Analyzer** — What they write/say. Recurring themes, frameworks, beliefs.
3. **Social Graph Mapper** — Who they know, co-appearances, collaborators.
4. **Controversy/Risk Scanner** — Lawsuits, negative press, red flags, disputes.
5. **Philosophical DNA Extractor** — Deep beliefs, values, influences from interviews/podcasts.

#### BUILD-VS-BUY — "Should we build X or use existing?"
**Wave 1 (6 agents, parallel — batch 5 then 1):**
1. **Solution Finder** — Every existing tool/service that does X.
2. **FOR Case** — Strongest advocate for the top solution.
3. **AGAINST Case** — Devil's advocate. Lock-in, hidden costs, limitations.
4. **Cost/Complexity Modeler** — Pricing at scale, integration effort, maintenance.
5. **Community Health Assessor** — Is the project alive? Stars, commits, funding.
6. **DIY Estimator** — Time/cost to build ourselves.

#### AUDIENCE — "Who wants X and why?"
**Wave 1 (5 agents, parallel):**
1. **Community Scanner** — Reddit, Discord, Facebook groups. Recurring questions.
2. **Pain Point Miner** — Complaints, frustrations, unmet needs.
3. **Competitor Audience Analyzer** — Who else serves them? Review analysis.
4. **Language/Phrase Extractor** — Exact words this audience uses.
5. **Watering Hole Mapper** — Where they hang out online.

### Wave 2: Gap Detection & Filling

After Wave 1 completes:
1. Read all output files
2. Score gaps: frequency (x3) + recurrence (x2) + criticality (x5)
3. Top 2-3 gaps become Wave 2 agent targets
4. Brief user: "Wave 1 complete. Gaps found: [list]. Filling them now."
5. Spawn 2-3 gap-filling agents with targeted search instructions

### Wave 3: Synthesis + Visualization

After Wave 2 completes:
1. Read ALL outputs (Wave 1 + Wave 2)
2. Create TWO synthesis files:
   - `QUANTITATIVE.md` — Numbers, benchmarks, data tables, CSV for graphing
   - `QUALITATIVE.md` — User experiences, perceptions, strategies, quotes
3. Create `VERDICT.md` — Executive summary with recommendation + confidence
4. If data supports visualization → generate graph via `nano-banana-pro` (use `--model pro` for quality)
5. Deliver: summary message + files + graph

### Team Execution Rules

**Agent prompts — EVERY agent MUST include:**
```
MANDATORY: Before executing, scan your available_skills list. If a skill matches this task:
1. READ the SKILL.md at the listed path — this is 100% required, no exceptions
2. FOLLOW the skill's documented pipeline exactly as written
3. If any step fails, use the skill's built-in fallback chain before improvising
4. NEVER say "I already have this loaded" as a reason to skip reading the skill file

EXA (mandatory, every agent):
- Run Exa through the exa-search scripts: bash ~/.claude/skills/exa-search/scripts/exa_search.sh | exa_deep_search.sh | exa_crawl.sh | exa_company.sh | exa_linkedin.sh | exa_code.sh. They read the global EXA_API_KEY.
- NEVER call the claude.ai Exa connector tools (mcp__claude_ai_Exa__*), even if they're in your tool list.
- A script prints EXA_FATAL (exit 3): stop at once, write nothing more, and return "EXA_FAILURE:" plus the verbatim error lines.
- A script prints EXA_ERROR (exit 1): fix the request or wait a few seconds, retry once; if it fails again, stop and return the same way.
- Never switch to other engines to cover for a broken Exa.

DATA SOURCE ESCALATION (use the engine arsenal — see references/engines.md):
- Route by intent first, Exa always included: General -> exa + serper/brave/linkup/tavily; B2B -> exa_company/exa_linkedin + pdl/github/theirstack/explorium; clinical -> exa (category publication, anonymized terms) + pubmed/clinicaltrials/openfda/rxnorm; privacy-sensitive (a specific person's case) -> exa (anonymized terms) + brave_search only; academic -> exa (category publication) + paper-search MCP
- Contacts (emails, phones): lusha_phone.sh, then pdl_lookup.sh only if Lusha fails. Never ask Exa for contact data; its scripts refuse (EXA_POLICY)
- Synthesized multi-step answer: exa_deep_search.sh + perplexity-server MCP (then OpenRouter perplexity/* fallback); multi-hop or per-claim verification: exa_agent.sh --effort medium
- A script printing EXA_CONFIRM (exit 4) wants the user's OK for spend over $5: stop and return "EXA_CONFIRM:" plus the line, so the parent asks
- Paywalled / JS-rendered URL: exa_crawl.sh -> Firecrawl MCP -> perplexity-server extract_url_content -> chrome-devtools MCP
- If bot detection persists: consider a stealth browser tool, if you have one
- Always try the lightest engine in the category first; the wrappers handle backup-key fallover (Exa has none: its failures stop you)
```

**Concurrency:** Max 5 subagents at once. If mode needs 6, launch 5, then 1 when first completes.

**Flexibility:** The plan is NOT rigid. As agents return findings, ADAPT:
- If an agent surfaces something unexpected → adjust Wave 2 targets
- If FOR and AGAINST agents agree on everything → one probably failed, investigate
- Check agents regularly for insights that redirect the research

**Error handling:**
- **Agent returns `EXA_FAILURE:`** → stop the run: stop the other running agents (TaskStop), launch nothing new, don't synthesize partial results. Show the user the verbatim error and ask for a working key ([Exa gate](#exa-gate-first-step-of-every-run-hard-stop), step 2). Once the gate passes again, relaunch the agents that hadn't finished.
- Agent timeout (10 min) → note gap, proceed
- Agent failure → retry once simplified, then mark as Wave 2 gap
- All agents fail → fall back to solo mode (unless they failed on Exa: that's the stop above)

---

## Confirmation Flow (Team Mode)

Present plan, wait for user response:
- **"go" / "launch" / "yes"** → Execute as planned
- **"quick"** → Solo mode instead
- **"exhaustive"** → Add extra agents, increase search depth
- **"add [role]"** → Add specific agent to the team
- **"skip [role]"** → Remove agent from plan
- **Mode override** → "actually do PERSON mode" → switch

Never auto-launch team mode without confirmation.

---

## Output Format

### Solo Output
See `references/output-format.md` — flexible templates adapted to query type. Executive summary + comparison tables + source citations.

### Team Output

```
research/[topic-slug]/
├── 01-[role].md          (Wave 1 agents)
├── 02-[role].md
├── 03-fact-check-for.md
├── 04-fact-check-against.md
├── 05-[role].md
├── 09-gap-[topic].md     (Wave 2 gap fills)
├── 10-gap-[topic].md
├── QUANTITATIVE.md        (Wave 3 synthesis)
├── QUALITATIVE.md         (Wave 3 synthesis)
├── VERDICT.md             (Final recommendation)
├── chart-[desc].png       (Visualization if applicable)
└── meta.json              (Mode, query, agents, timestamps)
```

### Quality Gates

**Wave 1:**
- [ ] All agents completed (or noted gaps)
- [ ] Each output has 3+ unique sources
- [ ] FOR and AGAINST have opposing findings
- [ ] No output <200 words (silent failure indicator)

**Final report:**
- [ ] QUANTITATIVE.md has data tables with sources
- [ ] QUALITATIVE.md has direct quotes with attributions
- [ ] VERDICT.md has clear recommendation + confidence level

---

## Prerequisites

First-time setup is guided — run the onboarding (see [First-run setup check](#first-run-setup-check) + [references/onboarding.md](references/onboarding.md)). Cross-platform installers live in `_dependencies/` (`install.sh` / `install.ps1`); they fetch every dependency live at install time — nothing is vendored into this repo. See `_dependencies/INSTALL.md` for exactly what comes from where and under what license.

Required / recommended skills + MCPs:
- `exa-search` skill — **required**: the semantic backbone of every run (Solo + Team) and the Exa gate. A lightweight superset of the Exa MCP (curl + jq, no server).
- `firecrawl` MCP — preferred heavy extraction (remote URL, free tier ~1,000 pages/mo)
- `perplexity-server` MCP — free Perplexity for multi-step + URL extraction (browser automation, no key)
- `paper-search` MCP — 21-source academic aggregator
- `nano-banana-pro` skill — Wave 3 visualization (Team, when data supports graphs; optional)
- `chrome-devtools` MCP — heavy-extraction last-resort fallback (optional)

Keys are read from the OS environment, OR from `~/.claude/deep-research/.env` (sourced by `engine_common.sh`; **OS env wins**). The onboarding flow writes keys there and tracks state in `~/.claude/deep-research/configuration.json` (no secrets). Every paid/quota engine also supports a `_BACKUP` key. **Exa is the exception:** `EXA_API_KEY` lives in the global environment only. Set it with `bash ~/.claude/skills/exa-search/scripts/exa_set_key.sh <key>` (`dr_config.sh set-key EXA_API_KEY ...` calls it for you): no `.env` copy, no `_BACKUP`.
- General: `SERPER_API_KEY`, `BRAVE_API_KEY`, `TAVILY_API_KEY`, `LINKUP_API_KEY`, `EXA_API_KEY`
- B2B: `PDL_API_KEY`, `THEIRSTACK_API_KEY`, `EXPLORIUM_API_KEY`, `LUSHA_API_KEY` (single, no backup); GitHub via `gh` CLI auth
- Heavy extraction: `FIRECRAWL_API_KEY` (Firecrawl MCP)
- Multi-step fallback: `OPENROUTER_API_KEY` (for `perplexity/*` + `openai/o4-mini-deep-research`)
- Clinical/gov wrappers (PubMed, ClinicalTrials, openFDA, RxNorm) need NO key (optional `NCBI_API_KEY` / `OPENFDA_API_KEY` lift rate limits)
- `GEMINI_API_KEY` — optional, for nano-banana-pro

**By design never present:** `PERPLEXITY_API_KEY` (use perplexity-server MCP, OpenRouter fallback), `APOLLO_API_KEY`, `HUNTER_IO_API_KEY`.

Missing a key? The wrapper logs `DR_FAILURE: ... reason=no-key` and the router falls over per [references/routing.md](references/routing.md). (Exa prints `EXA_FATAL: reason=no-key` instead, and the gate stops the run.)

---

## What's code-enforced vs. protocol-enforced

Being precise about this matters more than it costs to admit it:

- **The Exa gate is code plus protocol.** Code: `exa_doctor.sh` exits non-zero unless Exa answers live; every exa-search script classifies failures into `EXA_FATAL` (exit 3) / `EXA_ERROR` (exit 1) from Exa's own error tags and logs them to `api-failures.jsonl`; `check-failures` exits 3 when an Exa fatal was logged. Protocol: actually stopping and asking the user is the orchestrating agent's job. The exit codes make skipping it visible, not impossible.
- **Backup-key fallover is real code.** `scripts/engines/engine_common.sh` (`dr_run_with_fallover`) tries the primary key, detects 401/402/403/429/5xx or a quota-language body match, and retries with the `_BACKUP` key automatically. Every engine wrapper calls it. This one you can trust unconditionally. (Exa is deliberately excluded: no fallover.)
- **Round-2 anti-overlap is a protocol the orchestrating agent runs**, not a script. `references/routing.md` specifies the exact prompt injection, but nothing outside the agent's own diligence carries the round-1 URL list forward. If a context-compacted or distracted turn skips it, round 2 just repeats round 1 — there's no guard against that today.
- **Critical-path failure alerting has a real signal and a real gap.** Every failed engine call is logged to `~/.claude/deep-research-logs/api-failures.jsonl` by code (`dr_log_failure`). Whether that failure actually reaches the user as a degraded-output callout used to depend entirely on the orchestrating agent remembering to check. `scripts/dr_config.sh check-failures` closes most of that gap — run it before finalizing and treat a non-zero exit as a hard stop, not a suggestion.

If you're extending this skill: don't add a claim to the frontmatter description that only the orchestrating agent's good behavior makes true. Say what's code and what's convention.

---

## Chained Skills

| Skill / MCP | Role | When |
|-------|------|------|
| exa-search | Mandatory semantic backbone + the Exa gate | Every run, every category |
| firecrawl MCP | Fast hosted page extraction | Heavy extraction (preferred; credit-aware fallback to perplexity/chrome) |
| perplexity-server MCP | Free Perplexity + URL extraction | Multi-step, news synthesis, heavy extraction |
| paper-search MCP | 21-source academic aggregator | Academic / peer-reviewed queries |
| nano-banana-pro | Graph/chart generation | Team Wave 3, when data supports |
| chrome-devtools MCP | Dynamic-site extraction | Fallback from perplexity-server extract |
| agent-teams | Orchestration patterns | Reference for team coordination |
