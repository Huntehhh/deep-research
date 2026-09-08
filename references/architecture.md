# Deep Research Team — Skill Architecture

**Document Type:** Architecture reference for the deep-research skill.

---

## 0. Overview & Design Philosophy

`deep-research-team` is the most powerful research orchestration primitive in the toolkit. It is not a search wrapper — it is a **multi-wave investigative team** that deploys 6–12 specialized agents in coordinated waves, detects its own knowledge gaps, fills them, then synthesizes quantitative and qualitative findings into structured deliverables.

### Design Principles

1. **Waves, not waterfalls.** Wave 1 runs broad and parallel. Wave 2 targets gaps surgically. Wave 3 synthesizes and visualizes. Never skip a wave.
2. **Always adversarial.** Every research run includes a FOR and AGAINST agent to prevent confirmation bias.
3. **Lanes, not overlap.** Each Wave 1 agent owns exactly one information lane. Lanes never overlap. Overlap = waste.
4. **Quality gates, not timers.** Wave 2 triggers on GAP SCORE, not elapsed time.
5. **Quantitative/qualitative split.** Synthesis is always bifurcated — numbers in one column, narratives in another.
6. **Human checkpoint at plan.** Show the team plan before launching. User types "go" or modifies. Never auto-launch.
7. **Token budgets are real.** Design for the smallest viable team, scale up only when the query demands it.

### Integration Map

```
deep-research-team
├── calls: agent-teams (for team orchestration patterns)
├── calls: research skills surfaced in available_skills (assigned to every Wave 1 researcher)
├── calls: exa-search (backend for all searches)
└── calls: nano-banana-pro (Wave 3 visualization generation)
```

---

## 1. Mode Taxonomy

### 1.1 The Five Modes

| Mode | Core Question | Primary Signal | Default Wave 1 Count |
|------|--------------|----------------|---------------------|
| `TECHNICAL` | How does X actually perform? | Benchmarks, evals, comparisons | 5 agents |
| `PERSON` | Who is X, really? | Digital footprint, philosophy, work | 5 agents |
| `BUILD-VS-BUY` | Make or acquire? | Cost, capability, risk, velocity | 6 agents |
| `AUDIENCE` | Who wants this and why? | Demographics, behavior, language | 5 agents |
| `AUTO` | (auto-detected) | Query text analysis | Inherits from detected mode |

### 1.2 AUTO Mode Detection Logic

```pseudocode
function detectMode(query: string): Mode {
  query_lower = query.toLowerCase()

  // TECHNICAL signals
  technical_signals = [
    "benchmark", "performance", "faster", "slower", "latency", "throughput",
    "accuracy", "eval", "compare", "vs", "versus", "best model", "which model",
    "framework comparison", "how does X perform", "test results", "hardware",
    "GPU", "inference speed", "token/s", "cost per token", "VRAM",
    "better than", "worse than", "ranking", "leaderboard"
  ]
  
  // PERSON signals
  person_signals = [
    "who is", "tell me about [person]", "background", "philosophy", "beliefs",
    "work history", "what has X done", "career", "twitter", "substack",
    "research", "papers", "founder", "CEO", "author", "developer",
    "interviews", "talks", "writing style", "influence"
  ]

  // BUILD-VS-BUY signals  
  build_vs_buy_signals = [
    "build vs buy", "make vs buy", "should we build", "existing solutions",
    "open source vs", "self-host", "vendor", "SaaS vs", "DIY", "custom",
    "alternatives to building", "cost to build", "use existing",
    "roll our own", "third party", "integration"
  ]

  // AUDIENCE signals
  audience_signals = [
    "audience", "who are the users", "target market", "who wants",
    "customer profile", "ICP", "buyer persona", "user research",
    "demographics", "psychographics", "what do they want",
    "pain points", "jobs to be done", "customer discovery",
    "market segment", "who would use"
  ]

  // Score each mode
  scores = {
    TECHNICAL: countMatches(query_lower, technical_signals),
    PERSON: countMatches(query_lower, person_signals),
    BUILD_VS_BUY: countMatches(query_lower, build_vs_buy_signals),
    AUDIENCE: countMatches(query_lower, audience_signals)
  }

  winner = argmax(scores)
  
  // Require minimum confidence
  if scores[winner] == 0:
    // Heuristic fallback: named entity = PERSON, product name = TECHNICAL
    if containsNamedPerson(query): return PERSON
    if containsProductOrTech(query): return TECHNICAL
    return TECHNICAL  // safe default

  if scores[winner] >= 2: return winner
  
  // Tie-break: first strong signal wins
  return firstSignal(query_lower, scores)
}
```

**Confidence reporting:** When AUTO selects a mode, always tell the user:
```
🔍 AUTO detected: TECHNICAL mode (signals: "benchmark", "vs", "performance")
Proceed with this? Or specify: TECHNICAL | PERSON | BUILD-VS-BUY | AUDIENCE
```

---

## 2. Universal Skeleton (All Modes)

### 2.1 Three-Wave Structure

```
Wave 1: DISCOVERY (parallel)
├── 4-6 lane-specific researchers
├── 1 FOR advocate (finds strongest supporting evidence)
└── 1 AGAINST devil's advocate (finds contradictions, failures, critiques)

Wave 2: GAP FILL (targeted, parallel)
├── Triggers on gap analysis of Wave 1 outputs
├── 2-3 gap-fill agents (each targeting one specific hole)
└── Only launches if gap_score > threshold (see §5)

Wave 3: SYNTHESIS (sequential)
├── Quantitative Synthesizer (numbers, tables, metrics)
├── Qualitative Synthesizer (narratives, quotes, themes)
├── [OPTIONAL] Visualization Agent (nano-banana-pro, if data supports)
└── Final Report Assembler (combines into deliverable)
```

### 2.2 Agent Role Template (Universal)

Every agent in every wave receives this prompt structure:

```
You are the [ROLE_NAME] on a deep research team.

TOPIC: [topic]
YOUR LANE: [specific_domain — what you cover and what you DO NOT cover]
YOUR MISSION: [one sentence describing your specific research objective]

SKILL: Scan available_skills and read the matching research skill's SKILL.md first.
SEARCH BACKEND: exa-search scripts at ~/.claude/skills/exa-search/scripts/

SEARCH STRATEGY for your lane:
1. [Search query 1 — semantic/Exa]
2. [Search query 2 — targeted web_search]
3. [Search query 3 — source-specific pattern]
4. [Search query 4 — validation/complaints angle]

OUTPUT FORMAT:
Save all findings to: [output_dir]/wave1/[role_name_slug].md

Your file MUST contain these sections:
## Key Findings (bullet list, max 15 items)
## Evidence Quality (table: finding | source | confidence)
## Gaps Identified (what you couldn't find / what's missing)
## Raw Sources (URLs, titles, dates)

BOUNDARIES:
- DO NOT cover: [other agents' lanes]
- FOCUS ONLY ON: [this agent's lane]
- TIME BOX: Target 10-15 searches max
```

### 2.3 FOR/AGAINST Agent Design

**FOR Agent** — finds the strongest case FOR the main hypothesis:
```
YOUR LANE: Strongest supporting evidence, success stories, proponents, 
           best-case scenarios, favorable benchmarks, advocates' arguments.
BIAS INSTRUCTION: Actively seek evidence that supports [hypothesis].
                  Cherry-pick the best numbers. Find the believers.
                  Your job is to STEEL-MAN the positive case.
```

**AGAINST Agent** — finds the strongest case AGAINST:
```
YOUR LANE: Failures, criticisms, limitations, edge cases, contrarian views,
           "it broke in production", forum complaints, known failure modes.
BIAS INSTRUCTION: Actively seek evidence against [hypothesis].
                  Find the people who tried it and failed.
                  Find the hidden costs, the quiet disasters, the "actually..."
                  Your job is to STEEL-MAN the negative case.
```

**Why both?** The Synthesizer in Wave 3 needs both poles to produce a calibrated view. A team without an AGAINST agent will produce hype. A team without a FOR agent will miss real value.

### 2.4 Gap Detection Logic

After Wave 1 completes, the orchestrator runs gap analysis before launching Wave 2:

```pseudocode
function analyzeGaps(wave1_outputs: dict[role → markdown_file]): GapReport {
  
  all_gaps = []
  
  for each output in wave1_outputs:
    // Extract "## Gaps Identified" sections
    gaps = extractSection(output, "Gaps Identified")
    all_gaps.extend(gaps)
  
  // Deduplicate and cluster similar gaps
  clustered = clusterSimilar(all_gaps, similarity_threshold=0.7)
  
  // Score each gap cluster
  scored_gaps = []
  for cluster in clustered:
    score = GapScore {
      frequency: len(cluster),        // how many agents mentioned it
      recurrence: countCrossRef(cluster, wave1_outputs),  // how often referenced
      criticality: estimateCriticality(cluster, research_mode),  // mode-specific
    }
    scored_gaps.append((cluster.representative, score))
  
  // Sort by total score: frequency*3 + recurrence*2 + criticality*5
  scored_gaps.sort(key=lambda x: x.score.total(), reverse=True)
  
  // Threshold: launch Wave 2 if any gap has score >= 6
  critical_gaps = [g for g in scored_gaps if g.score.total() >= 6]
  
  return GapReport {
    gaps: scored_gaps,
    critical_gaps: critical_gaps,
    launch_wave2: len(critical_gaps) > 0,
    wave2_targets: critical_gaps[:3]  // max 3 gap agents
  }
}
```

**Criticality estimation by mode:**
- `TECHNICAL`: Missing benchmark data = high criticality; missing opinion = low
- `PERSON`: Missing primary sources (their own writing) = critical; secondhand = medium
- `BUILD-VS-BUY`: Missing cost data = critical; missing edge cases = medium
- `AUDIENCE`: Missing behavioral data = critical; missing demographics = medium

### 2.5 Error Handling

```pseudocode
function runAgentWithRetry(agent_config: AgentConfig, max_retries: int = 2): Result {
  
  for attempt in range(max_retries + 1):
    try:
      result = spawnAgent(agent_config)
      
      if result.status == "completed":
        // Validate output has required sections
        if validateOutputFormat(result.output, agent_config.role):
          return Result.ok(result)
        else:
          // Output malformed — retry with reminder
          agent_config.prompt += "\n\nPREVIOUS ATTEMPT FAILED: Your output was missing required sections. You MUST include: ## Key Findings, ## Evidence Quality, ## Gaps Identified, ## Raw Sources"
          continue
      
      elif result.status == "failed":
        if attempt < max_retries:
          log(f"Agent {agent_config.role} failed (attempt {attempt+1}), retrying...")
          sleep(2 ** attempt)  // exponential backoff
          continue
        else:
          // Final failure — return degraded result
          return Result.degraded(
            role=agent_config.role,
            error=result.error,
            fallback=generateFallbackFindings(agent_config.lane, topic)
          )
    
    catch AgentTimeout:
      // Agent ran too long — capture partial output if available
      partial = result.partial_output or ""
      return Result.degraded(role=agent_config.role, partial=partial, error="timeout")
  
  return Result.failed(agent_config.role)
}

// At synthesis time:
function handleDegradedResults(results: list[Result]): void {
  failed_roles = [r for r in results if r.is_degraded or r.is_failed]
  
  if len(failed_roles) > 0:
    warn_message = f"""
⚠️ Research degraded: {len(failed_roles)} agents had issues:
{format_failed_list(failed_roles)}

Proceeding with available data. Missing lanes may create blind spots in analysis.
Wave 3 synthesis will flag areas where coverage was limited.
"""
    emit(warn_message)
}
```

### 2.6 Token Budget & Subagent Limits

```pseudocode
// Subagent depth limit is typically 2 (depth 0 = main, depth 1 = subagent, depth 2 = sub-subagent)
// This means: deep-research-team runs as depth 1, its agents run as depth 2 — AT THE LIMIT.

SUBAGENT_BUDGET = {
  wave1_max: 8,      // Hard cap for Wave 1 agents
  wave2_max: 3,      // Hard cap for Wave 2 agents
  wave3_max: 4,      // Synthesizers (can be sequential, not all parallel)
  total_max: 12      // Never exceed this across all waves
}

function calculateTeamSize(mode: Mode, query_complexity: int, user_depth: string): TeamConfig {
  
  base_sizes = {
    TECHNICAL: { wave1: 5, wave2: 2, wave3: 3 },
    PERSON:    { wave1: 5, wave2: 2, wave3: 3 },
    BUILD_VS_BUY: { wave1: 6, wave2: 3, wave3: 3 },
    AUDIENCE:  { wave1: 5, wave2: 2, wave3: 3 }
  }
  
  config = base_sizes[mode]
  
  // User depth modifier
  if user_depth == "quick":
    config.wave1 = max(3, config.wave1 - 2)
    config.wave2 = 0  // skip gap fill
    config.wave3 = 2  // minimal synthesis
  
  elif user_depth == "exhaustive":
    config.wave1 = min(SUBAGENT_BUDGET.wave1_max, config.wave1 + 2)
    config.wave2 = min(SUBAGENT_BUDGET.wave2_max, config.wave2 + 1)
  
  // Hard cap enforcement
  config.wave1 = min(config.wave1, SUBAGENT_BUDGET.wave1_max)
  config.wave2 = min(config.wave2, SUBAGENT_BUDGET.wave2_max)
  total = config.wave1 + config.wave2 + config.wave3
  
  if total > SUBAGENT_BUDGET.total_max:
    // Trim wave3 first (it can run more sequentially), then wave2
    overflow = total - SUBAGENT_BUDGET.total_max
    config.wave3 = max(2, config.wave3 - overflow)
  
  return config
}
```

**Important note on depth:** Since subagents spawned by this skill are at depth 2, they **cannot themselves spawn subagents**. They must be self-contained. Wave 3 synthesizers run sequentially (not in a new subagent wave) to respect this limit.

---

## 3. Mode: TECHNICAL

### 3.1 Purpose
Answers: "How does X actually perform?" — benchmarks, real-world evals, framework comparisons, hardware tests, latency/throughput/cost data.

### 3.2 Wave 1 Agent Roster (5 agents + 2 universal)

| Agent | Lane | Primary Sources | Search Patterns |
|-------|------|----------------|-----------------|
| **Benchmark Miner** | Official benchmarks, leaderboards, published evals | Papers With Code, LMSYS, MLflow, arXiv | "X benchmark results", "X leaderboard", "X eval" |
| **Practitioner Voice** | Real-world usage reports, production deployments | Reddit r/MachineLearning, HN, dev blogs, GitHub issues | "using X in production", "X real world performance", "X vs Y in practice" |
| **Cost Analyst** | Pricing, compute costs, operational economics | Provider pricing pages, indie benchmarks, community cost threads | "X cost per token", "X pricing comparison", "X total cost of ownership" |
| **Limitations Hunter** | Known failure modes, edge cases, degradation conditions | GitHub issues, forum complaints, academic critiques | "X fails at", "X limitations", "X doesn't work when", "problems with X" |
| **Hardware Mapper** | Hardware requirements, VRAM, memory, scaling behavior | GGUF releases, Ollama benchmarks, LM Studio benchmarks | "X VRAM requirements", "X on 8GB GPU", "X memory usage" |
| **FOR Advocate** | Best-case scenarios, champions, strongest positive results | Blog posts from advocates, cherry-picked benchmarks | "X outperforms", "X achieves state of art", "why X is best" |
| **AGAINST Devil's Advocate** | Failure cases, overblown claims, quiet disasters | Post-mortems, "switched away from X", underperformance reports | "X disappointment", "X overhyped", "moved away from X", "X failure" |

### 3.3 Wave 2 Gap Targets (TECHNICAL-specific)

High-criticality gaps for TECHNICAL mode:
- Missing benchmark on a specific task type → spawn **Task-Specific Benchmark Agent**
- No real production data → spawn **Production Case Studies Agent**
- Missing cost comparison → spawn **Competitive Cost Matrix Agent**
- Conflicting benchmark results → spawn **Conflict Resolver** (finds methodology differences)

### 3.4 Wave 3 Synthesis (TECHNICAL)

```
Quantitative Synthesizer:
- Extract all numeric data from wave1+wave2 outputs
- Build comparison table: [Model/Tool] × [Metric] with source citations
- Flag contradictions (same metric, different numbers from different sources)
- Output: tables/quantitative-comparison.md

Qualitative Synthesizer:
- Extract practitioner narratives and themes
- Find recurring praise and recurring complaints
- Extract "the thing nobody talks about" — hidden signals
- Output: tables/qualitative-themes.md

Visualization Agent (nano-banana-pro) — CONDITIONAL:
- Trigger if: quantitative table has ≥3 models × ≥3 metrics
- Generate: bar chart or radar chart of performance metrics
- Prompt template: "Technical comparison chart showing [metrics] for [tools], 
  clean data visualization style, white background, labeled axes"
- Output: visuals/comparison-chart.png

Final Report Assembler:
- Opens: executive-summary.md template
- Populates: verdict, top finding, confidence level, key tradeoffs
- Merges quant + qual + visual into: report/final-report.md
```

### 3.5 Output Files (TECHNICAL)

```
research/[topic-slug]/
├── wave1/
│   ├── benchmark-miner.md
│   ├── practitioner-voice.md
│   ├── cost-analyst.md
│   ├── limitations-hunter.md
│   ├── hardware-mapper.md
│   ├── for-advocate.md
│   └── against-devil.md
├── wave2/
│   ├── gap-analysis.md         ← generated by orchestrator
│   └── [gap-agent-name].md     ← 0-3 files depending on gaps
├── tables/
│   ├── quantitative-comparison.md
│   └── qualitative-themes.md
├── visuals/
│   └── comparison-chart.png    ← if generated
└── report/
    └── final-report.md
```

---

## 4. Mode: PERSON

### 4.1 Purpose
Answers: "Who is X, really?" — digital footprint (everything they've published/said), philosophical DNA (their worldview, values, intellectual lineage), work trajectory, influence, and reputation.

### 4.2 Wave 1 Agent Roster (5 agents + 2 universal)

| Agent | Lane | Primary Sources | Search Patterns |
|-------|------|----------------|-----------------|
| **Primary Source Archaeologist** | Everything the person wrote in their own words | Their blog, Substack, published papers, GitHub repos, talks | "[name] blog", "[name] substack", "[name] github", "[name] writing" |
| **Interview Miner** | Interviews, podcasts, Q&As, recorded talks | YouTube transcripts, podcast platforms, conference talks | "[name] interview", "[name] podcast", "[name] talk transcript" |
| **Career Archaeologist** | Work history, projects, companies, collaborations | LinkedIn, Crunchbase, academic profiles, company sites | "[name] career", "[name] founder", "[name] previously at" |
| **Influence Mapper** | Who influenced them, who they influenced, intellectual lineage | "inspired by", "credits", "recommended reading", followers | "[name] recommended by", "[name] influenced", "who follows [name]" |
| **Reputation Scanner** | How others describe them, criticism, controversy | Twitter/X threads, HN discussions, peer reviews | "[name] controversial", "criticism of [name]", "what people say about [name]" |
| **FOR Advocate** | Their strongest ideas, greatest contributions, most cited work | Academic citations, best received pieces, advocates | "best work [name]", "[name] influential paper", "[name] celebrated for" |
| **AGAINST Devil's Advocate** | Failures, blind spots, retractions, controversies | Criticism threads, failed projects, retractions | "[name] wrong about", "[name] criticized", "[name] failed project" |

### 4.3 Wave 2 Gap Targets (PERSON-specific)

- No primary sources found → spawn **Deep Crawl Agent** (crawls their personal site/blog exhaustively)
- Missing philosophical framework → spawn **Intellectual DNA Agent** (searches for worldview connections)
- Missing recent activity → spawn **Recent Activity Agent** (focuses on last 12 months only)

### 4.4 Wave 3 Synthesis (PERSON)

```
Quantitative Synthesizer:
- Count: publications, talks, companies founded, papers cited
- Timeline: career milestones in chronological order
- Influence graph: who they cite / who cites them (text representation)
- Output: tables/career-timeline.md, tables/influence-map.md

Qualitative Synthesizer:
- Extract: recurring themes in their work (3-5 core themes)
- Identify: philosophical DNA (what worldview underlies their work)
- Summarize: how others describe them (supporter vs critic voices)
- Find: the thing they say differently than everyone else
- Output: tables/philosophical-dna.md, tables/reputation-summary.md

Visualization Agent (nano-banana-pro) — CONDITIONAL:
- Trigger if: timeline has ≥5 career events
- Generate: career/influence timeline visualization
- Prompt: "Clean timeline infographic of [name]'s career milestones, 
  minimalist design, key dates labeled"

Final Report Assembler:
- Structure: Bio summary → Philosophical DNA → Key Works → Influence → 
  Reputation (FOR/AGAINST) → How to engage with their work
- Output: report/final-report.md
```

### 4.5 Output Files (PERSON)

```
research/[person-slug]/
├── wave1/
│   ├── primary-source-archaeologist.md
│   ├── interview-miner.md
│   ├── career-archaeologist.md
│   ├── influence-mapper.md
│   ├── reputation-scanner.md
│   ├── for-advocate.md
│   └── against-devil.md
├── wave2/
│   ├── gap-analysis.md
│   └── [gap-agent-name].md
├── tables/
│   ├── career-timeline.md
│   ├── influence-map.md
│   └── philosophical-dna.md
├── visuals/
│   └── career-timeline.png    ← if generated
└── report/
    └── final-report.md
```

---

## 5. Mode: BUILD-VS-BUY

### 5.1 Purpose
Answers: "Should we build X ourselves or use an existing solution?" — full cost accounting (build cost + maintenance + team), capability gaps, vendor risk, speed to value, integration complexity.

### 5.2 Wave 1 Agent Roster (6 agents + 2 universal)

| Agent | Lane | Primary Sources | Search Patterns |
|-------|------|----------------|-----------------|
| **Build Cost Estimator** | Real cost to build: engineering time, infra, maintenance | Stack Overflow surveys, agency rate surveys, engineering blogs | "how long to build X", "engineer hours for X", "build X from scratch cost" |
| **Existing Solutions Scout** | What solutions exist, their capabilities, pricing | G2, ProductHunt, GitHub repos, official docs | "best X tools", "X open source alternatives", "X SaaS pricing" |
| **Integration Complexity Analyst** | How hard to integrate either option | GitHub issues, developer forums, integration guides | "X integration difficulty", "X API complexity", "integrating X took" |
| **Vendor Risk Assessor** | Lock-in risk, company stability, pricing volatility, open source health | HN discussions, acquisition history, GitHub activity, pricing change history | "X vendor lock-in", "X pricing increase", "is X company stable", "X acquired" |
| **Make vs Buy Case Studies** | Real companies who faced this exact decision | Indie Hackers, engineering blogs, post-mortems | "we built X instead of using Y", "switched from building to using", "buy vs build [domain]" |
| **Hidden Cost Hunter** | Operational costs often not in TCO calculations | Reddit r/devops, r/sre, HN "ask HN", post-mortems | "hidden costs of X", "operational overhead of self-hosting X", "X maintenance burden" |
| **FOR (Build Advocate)** | Cases where building wins: control, differentiation, cost at scale | Engineering blogs from teams who built custom | "why we built our own X", "building X was worth it" |
| **AGAINST (Buy Advocate)** | Cases where buying wins: speed, expertise, reliability | "we stopped maintaining X", "switched to vendor for X", "self-hosting mistake" |

### 5.3 Wave 2 Gap Targets (BUILD-VS-BUY-specific)

- Missing TCO at scale numbers → spawn **Scale Economics Agent**
- No migration path data → spawn **Migration Cost Agent** (what happens if you start wrong)
- Missing team size context → spawn **Team Capability Agent** (do we have the skills to build?)

### 5.4 Wave 3 Synthesis (BUILD-VS-BUY)

```
Quantitative Synthesizer:
- Build: total cost estimate (Y1, Y2, Y3 with maintenance)
- Buy: total cost estimate (per option, Y1, Y2, Y3)
- Crossover point: at what scale does building become cheaper?
- Output: tables/cost-comparison.md (time-series table)

Qualitative Synthesizer:
- Build wins when: [conditions list]
- Buy wins when: [conditions list]  
- The real question is: [reframe — often the wrong question was asked]
- Red flags for each path
- Output: tables/decision-criteria.md

Visualization Agent (nano-banana-pro) — CONDITIONAL:
- Trigger if: cost data exists for ≥2 time periods
- Generate: line chart of cumulative cost over time (build vs top-2 buy options)
- Prompt: "Cost comparison chart showing cumulative cost over 3 years for 
  building vs buying [solution], showing crossover point clearly"

Final Report Assembler:
- Structure: VERDICT (1 paragraph) → Cost Table → Decision Criteria → 
  Risk Assessment → Recommendation with conditions
- Output: report/final-report.md
```

### 5.5 Output Files (BUILD-VS-BUY)

```
research/[decision-slug]/
├── wave1/
│   ├── build-cost-estimator.md
│   ├── existing-solutions-scout.md
│   ├── integration-complexity.md
│   ├── vendor-risk-assessor.md
│   ├── case-studies.md
│   ├── hidden-cost-hunter.md
│   ├── for-build.md
│   └── against-build.md
├── wave2/
│   ├── gap-analysis.md
│   └── [gap-agent-name].md
├── tables/
│   ├── cost-comparison.md
│   └── decision-criteria.md
├── visuals/
│   └── cost-curve.png         ← if generated
└── report/
    └── final-report.md
```

---

## 6. Mode: AUDIENCE

### 6.1 Purpose
Answers: "Who is the audience for X and what do they want?" — audience demographics, psychographics, jobs-to-be-done, language patterns, pain points, what they already use, where they hang out, what would actually convert them.

### 6.2 Wave 1 Agent Roster (5 agents + 2 universal)

| Agent | Lane | Primary Sources | Search Patterns |
|-------|------|----------------|-----------------|
| **Demographic Profiler** | Age, job titles, company sizes, geographic distribution | LinkedIn surveys, industry reports, Twitter analytics discussions | "who uses X demographics", "X user survey", "X customer profile" |
| **Language Miner** | Exact phrases, words, metaphors the audience uses | Reddit, forums, product reviews, community discussions | subreddit search for [topic], "how people describe X problem", community language |
| **Pain Point Excavator** | What frustrates them, what's broken, what they complain about | 1-star reviews, forum complaints, "help me with X" posts | "hate about X", "problem with X", "frustrating when X", r/[topic] complaints |
| **Jobs-To-Be-Done Mapper** | What they're trying to accomplish (functional + emotional + social) | Interview transcripts, case studies, "I hired X to do Y" patterns | "I use X because", "X helps me", "what I actually want is", testimonials |
| **Watering Holes Scout** | Where they congregate, which communities, influencers they follow | Platform-specific research, newsletter discovery, YouTube channels | "[topic] community", "[topic] forum", "best [topic] newsletter", "[topic] discord" |
| **FOR (Audience Size Optimist)** | Evidence of large, underserved, motivated audience | TAM research, growing subreddits, trending searches | "[topic] growing", "demand for X", "market size X", Google Trends data |
| **AGAINST (Audience Size Skeptic)** | Evidence audience is small, saturated, or hard to reach | Declining interest signals, competition density, niche-ness | "[topic] declining", "X audience shrinking", "too competitive", "niche too small" |

### 6.3 Wave 2 Gap Targets (AUDIENCE-specific)

- Missing behavioral data → spawn **Usage Behavior Agent** (what do they actually DO)
- No willingness-to-pay signals → spawn **Monetization Signal Agent**
- Missing competitor audience data → spawn **Competitor Audience Agent** (who buys from competitors)

### 6.4 Wave 3 Synthesis (AUDIENCE)

```
Quantitative Synthesizer:
- Audience size estimates (with confidence bands)
- Platform distribution (% on each platform)
- Engagement metrics where findable
- Output: tables/audience-size-estimates.md, tables/platform-distribution.md

Qualitative Synthesizer:
- Audience persona cards (3-5 distinct segment types)
- Language glossary (exact phrases they use vs phrases to avoid)
- Jobs-to-be-done hierarchy (primary, secondary, emotional)
- The thing they want but don't know how to say
- Output: tables/persona-cards.md, tables/jtbd-map.md, tables/language-guide.md

Visualization Agent (nano-banana-pro) — CONDITIONAL:
- Trigger if: ≥3 distinct audience segments identified
- Generate: audience segmentation visual (pie chart style or venn)
- Prompt: "Clean audience segmentation diagram showing [3-5 segments] 
  with percentage breakdown, professional infographic style"

Final Report Assembler:
- Structure: Audience Summary → Personas → JTBD → Language Guide → 
  Watering Holes → Where to Reach Them → What to Say
- Output: report/final-report.md
```

### 6.5 Output Files (AUDIENCE)

```
research/[audience-slug]/
├── wave1/
│   ├── demographic-profiler.md
│   ├── language-miner.md
│   ├── pain-point-excavator.md
│   ├── jtbd-mapper.md
│   ├── watering-holes-scout.md
│   ├── for-audience-optimist.md
│   └── against-audience-skeptic.md
├── wave2/
│   ├── gap-analysis.md
│   └── [gap-agent-name].md
├── tables/
│   ├── persona-cards.md
│   ├── jtbd-map.md
│   └── language-guide.md
├── visuals/
│   └── audience-segments.png  ← if generated
└── report/
    └── final-report.md
```

---

## 7. Confirmation Flow

### 7.1 Plan Presentation Format

Before launching a single agent, the orchestrator presents:

```
🔬 DEEP RESEARCH TEAM — [MODE] MODE
Topic: [topic]
[If AUTO]: Mode detected from: [signals found]

WAVE 1 — Discovery (parallel, ~10-15 min)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Agent 1: [Role] — Lane: [domain]
  Agent 2: [Role] — Lane: [domain]
  Agent 3: [Role] — Lane: [domain]
  Agent 4: [Role] — Lane: [domain]
  Agent 5: [Role] — Lane: [domain]
  Agent 6: FOR Advocate — Lane: strongest supporting evidence
  Agent 7: AGAINST Devil's Advocate — Lane: failures, critiques, limits

WAVE 2 — Gap Fill (triggered if gaps found, ~5-10 min)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Up to 3 agents, targeting holes found in Wave 1
  (Team determined after Wave 1 completes)

WAVE 3 — Synthesis (sequential, ~5-10 min)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Quantitative Synthesizer
  Qualitative Synthesizer
  [Visualization] if sufficient numeric data
  Final Report Assembler

OUTPUT: research/[slug]/ (full folder structure)
DEPTH: [Standard / Quick / Exhaustive]
TOTAL AGENTS: ~[N] | ESTIMATED TIME: ~[X] minutes

Type "go" to launch, or modify: 
  • "quick" — skip Wave 2, minimal Wave 3
  • "exhaustive" — add 2 more research lanes
  • "mode: [MODE]" — switch mode
  • "add [lane]" — add a specific research angle
  • "skip visualization" — no image generation
```

### 7.2 Modification Handling

```pseudocode
function handleConfirmation(user_response: string, current_plan: TeamPlan): Action {
  
  response_lower = user_response.toLowerCase().trim()
  
  if response_lower in ["go", "launch", "yes", "do it", "word"]:
    return Action.LAUNCH(current_plan)
  
  if "quick" in response_lower:
    return Action.REPLAN(modify(current_plan, depth="quick"))
  
  if "exhaustive" in response_lower:
    return Action.REPLAN(modify(current_plan, depth="exhaustive"))
  
  if response_lower.startswith("mode:"):
    new_mode = parseMode(response_lower)
    return Action.REPLAN(buildPlan(topic, new_mode))
  
  if response_lower.startswith("add "):
    lane = response_lower.removeprefix("add ")
    new_agent = synthesizeAgentForLane(lane, current_plan.topic, current_plan.mode)
    return Action.REPLAN(addAgent(current_plan, new_agent))
  
  if "skip" in response_lower and "visual" in response_lower:
    return Action.REPLAN(disableVisualization(current_plan))
  
  // Unrecognized — ask once
  return Action.ASK("I can adjust the plan. What would you like to change?\n" +
                    "Options: quick, exhaustive, mode: [MODE], add [lane], skip visualization")
}
```

---

## 8. Output Folder Structure

### 8.1 Base Path

```
~/.claude/deep-research-output/[topic-slug]/
```

Where `[topic-slug]` is derived:
```pseudocode
function makeSlug(topic: string, mode: str): string {
  date_prefix = datetime.now().strftime("%Y-%m-%d")
  clean_topic = topic.lower()
    .replace(/[^a-z0-9 ]/g, "")
    .replace(/ +/g, "-")
    [:50]  // max 50 chars
  return f"{date_prefix}-{mode.lower()}-{clean_topic}"
}
// Example: "2026-03-19-technical-gpt4o-vs-claude-opus-benchmarks"
```

### 8.2 Full Folder Template

```
research/[topic-slug]/
├── README.md                    ← auto-generated index with links to all files
├── meta.json                    ← research metadata (mode, topic, agents, timestamps)
├── wave1/                       ← all Wave 1 agent outputs
│   ├── [agent-slug].md          
│   └── ...
├── wave2/                       ← gap analysis + Wave 2 outputs
│   ├── gap-analysis.md          ← generated by orchestrator after Wave 1
│   └── [gap-agent-slug].md      ← 0-3 files
├── tables/                      ← structured data tables (Wave 3 quant + qual)
│   ├── quantitative-*.md
│   └── qualitative-*.md
├── visuals/                     ← nano-banana-pro generated images
│   └── *.png
└── report/
    └── final-report.md          ← THE deliverable
```

### 8.3 meta.json Format

```json
{
  "topic": "GPT-4o vs Claude Opus 4 benchmarks",
  "mode": "TECHNICAL",
  "auto_detected": false,
  "depth": "standard",
  "created": "2026-03-19T21:34:00Z",
  "agents": {
    "wave1": ["benchmark-miner", "practitioner-voice", "cost-analyst", 
              "limitations-hunter", "hardware-mapper", "for-advocate", "against-devil"],
    "wave2": ["production-case-studies"],
    "wave3": ["quantitative-synthesizer", "qualitative-synthesizer", 
              "visualization-agent", "report-assembler"]
  },
  "wave2_triggered": true,
  "wave2_reason": "Missing production deployment data (gap score: 8)",
  "visualization_generated": true,
  "status": "complete"
}
```

---

## 9. Orchestration Pseudocode

### 9.1 Main Entry Point

```pseudocode
function deepResearchTeam(
  topic: string,
  mode: Mode = AUTO,
  depth: string = "standard",
  output_dir: string = null
): ResearchResult {

  // 1. Mode detection
  if mode == AUTO:
    detected_mode = detectMode(topic)
    show(f"🔍 AUTO detected: {detected_mode} mode")
  else:
    detected_mode = mode

  // 2. Build team plan
  team_config = calculateTeamSize(detected_mode, estimateComplexity(topic), depth)
  team_plan = buildTeamPlan(topic, detected_mode, team_config)
  
  // 3. Create output directory
  slug = makeSlug(topic, detected_mode)
  if output_dir == null:
    output_dir = f"~/.claude/deep-research-output/{slug}"
  createDirectory(output_dir)
  saveMeta(output_dir, topic, detected_mode, depth, team_plan)

  // 4. Present plan and wait for confirmation
  presentPlan(team_plan)
  confirmed_plan = awaitConfirmation(team_plan)  // blocks until user responds

  // 5. WAVE 1 — Parallel launch
  show("🌊 Launching Wave 1...")
  wave1_agents = buildWave1Agents(confirmed_plan, topic, output_dir)
  wave1_results = runParallel(wave1_agents, withRetry=true, maxRetries=2)
  handleDegradedResults(wave1_results)

  // 6. GAP ANALYSIS
  show("🔍 Analyzing Wave 1 for gaps...")
  gap_report = analyzeGaps(wave1_results)
  saveGapAnalysis(output_dir, gap_report)

  // 7. WAVE 2 — Conditional gap fill
  wave2_results = []
  if gap_report.launch_wave2 and depth != "quick":
    show(f"🌊 Launching Wave 2 ({len(gap_report.wave2_targets)} gap agents)...")
    wave2_agents = buildWave2Agents(gap_report.wave2_targets, topic, output_dir, detected_mode)
    wave2_results = runParallel(wave2_agents, withRetry=true, maxRetries=2)
    handleDegradedResults(wave2_results)
  else:
    show("✅ Wave 1 coverage sufficient — skipping Wave 2")

  // 8. WAVE 3 — Sequential synthesis
  show("🌊 Launching Wave 3 synthesis...")
  all_research = wave1_results + wave2_results
  
  quant_output = runQuantitativeSynthesizer(all_research, topic, detected_mode, output_dir)
  qual_output = runQualitativeSynthesizer(all_research, topic, detected_mode, output_dir)
  
  // Visualization — conditional
  viz_output = null
  if shouldVisualize(quant_output, detected_mode, depth):
    viz_output = runVisualizationAgent(quant_output, qual_output, topic, detected_mode, output_dir)
  
  // Final assembly
  final_report = runReportAssembler(quant_output, qual_output, viz_output, topic, detected_mode, output_dir)

  // 9. Update meta.json
  updateMeta(output_dir, status="complete", visualization_generated=(viz_output != null))

  // 10. Deliver
  return ResearchResult {
    report_path: final_report,
    output_dir: output_dir,
    mode: detected_mode,
    wave2_triggered: gap_report.launch_wave2,
    visualization: viz_output
  }
}
```

### 9.2 Wave 3 Synthesizer Pattern

```pseudocode
function runQuantitativeSynthesizer(all_research, topic, mode, output_dir): string {
  
  // Collect all research files
  research_files = listFiles(output_dir + "/wave1/") + listFiles(output_dir + "/wave2/")
  
  // Build context for the synthesizer
  combined_context = ""
  for file in research_files:
    content = readFile(file)
    combined_context += f"\n\n--- From {basename(file)} ---\n{content}"
  
  // Mode-specific synthesis instructions
  quant_instructions = QUANT_PROMPTS[mode]  // see §10.1

  // Run as a single Claude call (not a subagent — we're at depth limit)
  prompt = f"""
You are the Quantitative Synthesizer for a deep research team.

TOPIC: {topic}
MODE: {mode}

Your job: Extract ONLY numeric, measurable, comparable data from the research below.
Build structured comparison tables. Flag contradictions between sources.
Do NOT include opinions or narratives — only numbers, dates, costs, and citations.

{quant_instructions}

RESEARCH DATA:
{combined_context}

Save your output to: {output_dir}/tables/quantitative-synthesis.md
"""
  
  result = callClaude(prompt)  // inline call, not subagent
  writeFile(output_dir + "/tables/quantitative-synthesis.md", result)
  return output_dir + "/tables/quantitative-synthesis.md"
}
```

### 9.3 Visualization Decision Logic

```pseudocode
function shouldVisualize(quant_output: string, mode: Mode, depth: str): bool {
  
  if depth == "quick": return false
  
  content = readFile(quant_output)
  
  // Count data points
  table_rows = countTableRows(content)
  numeric_mentions = countRegex(content, r'\d+\.?\d*\s*(%|ms|GB|TB|\$|k|M|tokens?)')
  
  thresholds = {
    TECHNICAL:    { min_rows: 3, min_numeric: 6 },
    PERSON:       { min_rows: 4, min_numeric: 3 },  // timeline events
    BUILD_VS_BUY: { min_rows: 2, min_numeric: 4 },  // cost data
    AUDIENCE:     { min_rows: 3, min_numeric: 4 },  // segment sizes
  }
  
  threshold = thresholds[mode]
  return table_rows >= threshold.min_rows and numeric_mentions >= threshold.min_numeric
}
```

---

## 10. Mode-Specific Synthesis Prompts

### 10.1 Quantitative Synthesis Prompts by Mode

```
QUANT_PROMPTS = {

  TECHNICAL: """
Extract and build:
1. Performance comparison table: [Model/Tool] × [Metrics] — include units, source, date
2. Cost comparison table: pricing per unit across tools
3. Hardware requirements table: VRAM, RAM, CPU requirements
4. Benchmark contradiction log: same metric, different numbers — flag with both values
Flag staleness: any data older than 6 months get a ⚠️ warning.
""",

  PERSON: """
Extract and build:
1. Career timeline: date | event | organization | significance
2. Publication/work count: papers, posts, talks, repos — with link counts where available
3. Influence metrics: citation counts, follower counts, fork counts (where available)
Note: many numbers will be approximate — use ranges and flag uncertainty.
""",

  BUILD_VS_BUY: """
Extract and build:
1. Cost table: Year 1 / Year 2 / Year 3 costs for: Build | Option A | Option B | Option C
2. Time-to-value: weeks/months to working solution for each path
3. Team size requirement: engineers needed for each option
4. Operational overhead: hours/week maintenance for each option
5. Crossover analysis: at what scale does building become cheaper than buying?
""",

  AUDIENCE: """
Extract and build:
1. Audience size estimates: platform | estimated size | confidence | source
2. Demographic breakdown table: segment | % of audience | key characteristics
3. Engagement metrics: if found — post frequency, comment rates, community activity
4. Willingness-to-pay signals: price points mentioned, products they buy, spending behavior
"""
}
```

---

## 11. Integration Contracts

### 11.1 Research-skill Integration

Every Wave 1 and Wave 2 agent uses an available research skill as their research method. The agent prompt MUST include:

```
MANDATORY: Scan available_skills and read the matching research skill's SKILL.md first.
1. Read the matching SKILL.md in ~/.claude/skills/<research-skill>/
2. Use exa-search as the primary backend: bash ~/.claude/skills/exa-search/scripts/exa_search.sh
3. Search strategy for your lane:
   - 2-3 Exa semantic searches (conversational query style)
   - 2-3 targeted web_search with site: operators
   - 1-2 validation searches (complaints, limitations, "switched from")
4. Weight sources per the research skill's trust table
5. Save findings to [output_dir]/[wave]/[role-slug].md with required sections
```

### 11.2 exa-search Integration

The exa-search skill provides the search backbone. Key scripts used:

| Script | Used For |
|--------|----------|
| `exa_search.sh` | Standard search queries |
| `exa_deep_search.sh` | Complex multi-faceted queries in Wave 1 |
| `exa_company.sh` | Company/organization research (BUILD-VS-BUY, PERSON) |
| `exa_crawl.sh` | Deep-dive on specific URLs found in Wave 1 |
| `exa_researcher.sh` | Long-running async research for complex topics |

### 11.3 nano-banana-pro Integration

Called only by the Visualization Agent in Wave 3. Prompt must include:

```
MANDATORY: Use nano-banana-pro skill.
1. Read ~/.claude/skills/nano-banana-pro/SKILL.md
2. Use flash model by default (speed), pro model if visualization is the key deliverable
3. Filename: {output_dir}/visuals/{mode}-{topic-slug}-chart.png
4. Output format: 1K resolution by default
5. After generation, report ONLY the saved path — do not read the image back
```

### 11.4 agent-teams Integration

The orchestrator uses agent-teams patterns directly:

- **Wave 1** uses **Fan-out / Fan-in** pattern
- **Wave 2** uses **Independent** pattern (gap agents don't depend on each other)
- **Wave 3** uses **Pipeline** pattern (quant → qual → viz → assemble)
- Coordination pattern selected at plan time and shown to user

---

## 12. Quality Gates

### 12.1 Wave 1 Quality Gate

Before proceeding to gap analysis, validate:

```pseudocode
function validateWave1Quality(results: list[AgentResult]): QualityReport {
  
  checks = []
  
  // Coverage: minimum 60% of agents must have succeeded
  success_rate = len([r for r in results if r.status == "ok"]) / len(results)
  checks.append(QCheck("Coverage", success_rate >= 0.6, f"{success_rate*100:.0f}%"))
  
  // Balance: both FOR and AGAINST must be present
  has_for = any(r.role == "for-advocate" and r.status == "ok" for r in results)
  has_against = any(r.role == "against-devil" and r.status == "ok" for r in results)
  checks.append(QCheck("Balance", has_for and has_against, "FOR+AGAINST present"))
  
  // Volume: minimum 10 unique findings across all outputs
  total_findings = sum(countFindings(r.output) for r in results if r.status == "ok")
  checks.append(QCheck("Volume", total_findings >= 10, f"{total_findings} findings"))
  
  // Primary source: at least one high-trust source (reddit, HN, GitHub, academic)
  has_primary = any(hasHighTrustSource(r.output) for r in results if r.status == "ok")
  checks.append(QCheck("Primary Sources", has_primary, "High-trust sources present"))
  
  passed = all(c.passed for c in checks)
  
  if not passed:
    failed = [c for c in checks if not c.passed]
    warn(f"Wave 1 quality issues: {[c.name for c in failed]}")
    // Don't abort — proceed with warning, note in final report
  
  return QualityReport(checks=checks, passed=passed)
}
```

### 12.2 Final Report Quality Gate

Before delivering the report, check:

```pseudocode
function validateFinalReport(report_path: string): bool {
  
  content = readFile(report_path)
  
  required_sections = {
    "TECHNICAL":    ["## Verdict", "## Performance Data", "## Tradeoffs", "## Recommendations"],
    "PERSON":       ["## Who They Are", "## Philosophical DNA", "## Key Works", "## Reputation"],
    "BUILD_VS_BUY": ["## Recommendation", "## Cost Analysis", "## Risk Assessment"],
    "AUDIENCE":     ["## Audience Profile", "## Personas", "## Language Guide", "## Where to Find Them"]
  }
  
  for section in required_sections[current_mode]:
    if section not in content:
      warn(f"Final report missing: {section} — synthesizer may have omitted it")
      return false
  
  // Minimum word count
  if wordCount(content) < 500:
    warn("Final report suspiciously short (<500 words)")
    return false
  
  return true
}
```

---

## 13. SKILL.md Authoring Notes

When building the actual `SKILL.md` from this blueprint:

### 13.1 File Location
`~/.claude/skills/deep-research/SKILL.md`

### 13.2 Trigger Phrases to Include in Description
```
"deep research", "research team", "multi-agent research", "full research report",
"who is X", "how does X perform", "build vs buy", "audience research",
"technical comparison", "comprehensive research", "research X for me",
"deep dive on X", "investigate X", "full analysis of X"
```

### 13.3 Required Skill Metadata

```yaml
name: deep-research-team
requires:
  skills: [exa-search, nano-banana-pro, agent-teams]
  env: [EXA_API_KEY, GEMINI_API_KEY]
output_dir: ~/.claude/deep-research-output/
```

### 13.4 SKILL.md Structure Outline

```
1. Prerequisites & skill dependencies
2. Quick Start (mode selection)
3. Mode Reference (5 modes, 1 paragraph each)
4. Execution Pipeline (waves 1-3)
5. Confirmation flow instructions
6. Output folder reference
7. Error handling notes
8. Integration notes for each child skill
```

### 13.5 What NOT to Put in SKILL.md

- Don't include all the pseudocode (too much token load)
- Don't replicate each agent's full prompt (reference this architecture doc instead)
- Don't duplicate research-skill or exa-search instructions (reference them)
- Keep SKILL.md under 800 lines for token efficiency

---

## 14. Appendix: Source Priority by Mode

### TECHNICAL Mode Sources (ranked by trust)
1. arXiv papers with code + benchmarks
2. Papers With Code leaderboards
3. Independent benchmark repos on GitHub
4. Reddit r/MachineLearning + r/LocalLLaMA
5. HN threads with technical depth
6. Developer blog posts with methodology
7. Official docs and release notes
8. Marketing copy (verify everything)

### PERSON Mode Sources (ranked by trust)
1. Their own writing (blog, Substack, papers)
2. Long-form interviews
3. Conference talk transcripts
4. Peer/colleague assessments
5. Secondhand reports with citations
6. Twitter/X threads
7. Wikipedia (verify every claim)

### BUILD-VS-BUY Mode Sources (ranked by trust)
1. Post-mortems from teams who actually did it
2. Indie Hackers / engineering blogs with real numbers
3. Reddit r/devops, r/sre discussions
4. HN "Ask HN: build vs buy X" threads
5. Vendor pricing pages (current, with date)
6. Industry analyst reports
7. Vendor case studies (high bias — discount)

### AUDIENCE Mode Sources (ranked by trust)
1. Community discussion in their own words
2. Reddit + forum threads where they're talking
3. Review sites (G2, Capterra) — real buyer language
4. Interview transcripts / podcast listeners describing themselves
5. Survey data with methodology
6. Industry reports (abstract, verify with primary)
7. Analyst persona frameworks (treat as starting point only)
