---
name: deep-research
description: >
  Research any topic via an intent-routed multi-engine search backend - solo mode for quick lookups, team mode for comprehensive adversarial reports. Routes each query by intent: general web, B2B/people/company, clinical/medical, academic papers (paper-search MCP, 21 sources), $0 multi-step research (perplexity-server MCP), and heavy URL extraction (Firecrawl MCP + fallbacks). Multi-round search with anti-overlap round 2, automatic backup-key fallover, and critical-path failure alerting. Solo: 3-15 queries. Team: 6-12 adversarial agents across 3 waves. Auto-detects mode + intent. Run via sub-agent to protect the main context window; incidental mid-task lookups (checking a version, confirming syntax) need only a single search tool call, not this skill. Chains: exa-search, nano-banana-pro, agent-teams. Triggers on (non-exhaustive): "research this", "search the web", "compare options", "find alternatives to", "deep dive on", "deep research", "research team", "who is [person]", "find the team behind", "find papers on", "clinical evidence for", "find phone for", "build vs buy", "audience research", "investigate", "comprehensive research".
---

# Deep Research

One skill, two modes, one engine arsenal. **Solo** for fast lookups. **Team** for comprehensive adversarial reports. Both ride on an **intent-routed multi-engine backend** — the query's shape decides which engines fire.

---

## First-run setup check (gate)

Before researching, check setup state once — run `bash scripts/dr_config.sh status` (reads `~/.claude/deep-research/configuration.json`):
- **No config file** -> first run. Briefly offer the guided setup ([references/onboarding.md](references/onboarding.md)), then proceed.
- **`onboarding.status == complete`** OR **`reminderPreference == stop_asking`** -> skip setup; go straight to research.
- **`not_started` / `in_progress`** (and not silenced) -> one non-blocking line: *finish setup / ask next time / stop asking*. Persist the answer via `dr_config.sh`.

**Never block research on setup.** Route with whatever is configured; surface a degraded-output callout only when a *critical* lane (B2B / clinical / multi-step / phone) lacks its engines. Full choose-your-own-adventure setup, per-category keys + signup URLs: [references/onboarding.md](references/onboarding.md).

---

## Engine Arsenal & Intent Routing

Before searching, classify the query and route it to the right engine category. This replaces "Exa + web_search for everything." Quick map below; **[references/routing.md](references/routing.md) is authoritative** for full call-order, fallover, caps, and the heavy-extraction credit-aware escalation.

| Query shape | Category | Primary engine (full order -> routing.md) |
|---|---|---|
| generic web / "what is" / "look this up" | **General** | `serper_search.sh` (+ brave/exa/linkup/tavily) |
| "find the team behind" / "look up [person/company]" / enrich | **B2B** | `pdl_lookup.sh` (+ github/theirstack/explorium) |
| clinical / peptide / drug / biomarker / lab / protocol | **Privacy/Clinical** | `pubmed_search.sh` (+ clinicaltrials/openfda/rxnorm) |
| "latest" / "today" / "breaking" | **News** | `serper_search.sh` (qdr:d) -> brave -> perplexity-server |
| "research this" / "compile a brief" / "synthesize" | **Multi-Step** | perplexity-server MCP (OpenRouter `perplexity/*` fallback only) |
| "find papers on" / "peer-reviewed" / "meta-analysis" | **Academic** | paper-search MCP (21 sources) |
| "scrape" / "extract URL content" | **Heavy Extraction** | Firecrawl MCP (-> perplexity extract -> chrome-devtools; credit-aware) |
| "find phone for [person]" / "direct dial" | **Phone** | `lusha_phone.sh` ONLY (router-gated) |

Wrappers: `bash scripts/engines/<name>.sh "<args>"` (keys read from env, primary->backup fallover automatic). Full catalog: [references/engines.md](references/engines.md). Full routing/multi-round/alerting rules: [references/routing.md](references/routing.md).

**Three load-bearing rules** (do not violate):
1. **Multi-round, default 2.** Round 1 fires half the budget (medium=8 -> 4+4, max=15 -> 7+8). Round 2 MUST inject the anti-overlap prompt (filter out round-1 URLs; find only gaps/contradictions/new angles). See [references/routing.md#multi-round-search](references/routing.md#multi-round-search).
2. **Perplexity = perplexity-server MCP first**, OpenRouter `perplexity/*` fallback ONLY, **never** a direct `PERPLEXITY_API_KEY`.
3. **Alert on critical-path failure.** B2B / phone / clinical-evidence / privacy / multi-step lanes must surface a degraded-output callout when their engines fail — never silently downgrade. General/news/extraction lanes fall over silently. See [references/routing.md#api-failure-alerting](references/routing.md#api-failure-alerting).

**PHI safety rule:** for clinical queries, send only the anonymized term (drug/condition/biomarker) to external APIs. Patient identifiers never cross the wire.

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

Solo mode routes by intent (see [Engine Arsenal & Intent Routing](#engine-arsenal--intent-routing) above). Don't default to Exa-only — pick the category, fire its engines, fall over per [references/routing.md](references/routing.md).

**Resolution order within the General category:**
1. `scripts/engines/serper_search.sh` (biggest free quota) -> `brave_search.sh` (independent index)
2. `exa-search` skill for semantic/neural queries -> `bash ~/.claude/skills/exa-search/scripts/exa_search.sh` (needs `EXA_API_KEY`)
3. `linkup_search.sh` / `tavily_search.sh` / `brave_llm_context.sh` for cleaned LLM-ready content
4. All down on a critical lane -> surface the degraded-output callout and ask the user.

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

1. **Exa semantic** (2-4 queries) — conversational queries like "developers who switched from X to Y and why"
   - `deep_search_exa` for research tasks
   - `get_code_context_exa` for code/repos
   - Apply categories: `company`, `research paper`, `news`, `github`, `tweet`, `personal site`

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

DATA SOURCE ESCALATION (use the engine arsenal — see references/engines.md):
- Route by intent first: General -> serper/brave/exa/linkup/tavily; B2B -> pdl/github/theirstack/explorium; clinical -> pubmed/clinicaltrials/openfda/rxnorm; academic -> paper-search MCP
- Synthesized multi-step answer: perplexity-server MCP (then OpenRouter perplexity/* fallback)
- Paywalled / JS-rendered URL: Firecrawl MCP -> perplexity-server extract_url_content -> chrome-devtools MCP
- If bot detection persists: consider a stealth browser tool, if you have one
- Always try the lightest engine in the category first; the wrappers handle backup-key fallover
```

**Concurrency:** Max 5 subagents at once. If mode needs 6, launch 5, then 1 when first completes.

**Flexibility:** The plan is NOT rigid. As agents return findings, ADAPT:
- If an agent surfaces something unexpected → adjust Wave 2 targets
- If FOR and AGAINST agents agree on everything → one probably failed, investigate
- Check agents regularly for insights that redirect the research

**Error handling:**
- Agent timeout (10 min) → note gap, proceed
- Agent failure → retry once simplified, then mark as Wave 2 gap
- All agents fail → fall back to solo mode

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

First-time setup is guided — run the onboarding (see [First-run setup check](#first-run-setup-check-gate) + [references/onboarding.md](references/onboarding.md)). Bundled dependency snapshots + cross-platform installers live in `_dependencies/` (`install.sh` / `install.ps1`).

Required / recommended skills + MCPs:
- `exa-search` skill — semantic/neural backend (Solo + Team). A lightweight superset of the Exa MCP (curl + jq, no server).
- `firecrawl` MCP — preferred heavy extraction (remote URL, free tier ~1,000 pages/mo)
- `perplexity-server` MCP — $0 Perplexity for multi-step + URL extraction (browser automation, no key)
- `paper-search` MCP — 21-source academic aggregator
- `nano-banana-pro` skill — Wave 3 visualization (Team, when data supports graphs; optional)
- `chrome-devtools` MCP — heavy-extraction last-resort fallback (optional)

Keys are read from the OS environment, OR from `~/.claude/deep-research/.env` (sourced by `engine_common.sh`; **OS env wins**). The onboarding flow writes keys there and tracks state in `~/.claude/deep-research/configuration.json` (no secrets). Every paid/quota engine also supports a `_BACKUP` key.
- General: `SERPER_API_KEY`, `BRAVE_API_KEY`, `TAVILY_API_KEY`, `LINKUP_API_KEY`, `EXA_API_KEY`
- B2B: `PDL_API_KEY`, `THEIRSTACK_API_KEY`, `EXPLORIUM_API_KEY`, `LUSHA_API_KEY` (single, no backup); GitHub via `gh` CLI auth
- Heavy extraction: `FIRECRAWL_API_KEY` (Firecrawl MCP)
- Multi-step fallback: `OPENROUTER_API_KEY` (for `perplexity/*` + `openai/o4-mini-deep-research`)
- Clinical/gov wrappers (PubMed, ClinicalTrials, openFDA, RxNorm) need NO key (optional `NCBI_API_KEY` / `OPENFDA_API_KEY` lift rate limits)
- `GEMINI_API_KEY` — optional, for nano-banana-pro

**By design never present:** `PERPLEXITY_API_KEY` (use perplexity-server MCP, OpenRouter fallback), `APOLLO_API_KEY`, `HUNTER_IO_API_KEY`.

Missing a key? The wrapper logs `DR_FAILURE: ... reason=no-key` and the router falls over per [references/routing.md](references/routing.md).

---

## Chained Skills

| Skill / MCP | Role | When |
|-------|------|------|
| exa-search | Semantic search backend | General + semantic queries |
| firecrawl MCP | Fast hosted page extraction | Heavy extraction (preferred; credit-aware fallback to perplexity/chrome) |
| perplexity-server MCP | $0 Perplexity + URL extraction | Multi-step, news synthesis, heavy extraction |
| paper-search MCP | 21-source academic aggregator | Academic / peer-reviewed queries |
| nano-banana-pro | Graph/chart generation | Team Wave 3, when data supports |
| chrome-devtools MCP | Dynamic-site extraction | Fallback from perplexity-server extract |
| agent-teams | Orchestration patterns | Reference for team coordination |
