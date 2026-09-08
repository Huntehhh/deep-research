# Engine Arsenal — wrappers, MCPs, and OpenRouter

Every search backend the skill can call. Wrappers live in `scripts/engines/` and read keys from the environment (`<ENGINE>_API_KEY` + `_BACKUP`) via `engine_common.sh`. Exa stays in the sibling `exa-search` skill. The script is the source of truth for the exact endpoint; this table is for routing and operational limits.

## Quick invoke

```bash
bash scripts/engines/<name>.sh "<args>"
```

All wrappers print JSON (or clean text for gov APIs) to stdout. On failure they emit `DR_FAILURE: engine=... reason=...` to stderr and exit 1 — the body still prints so you can inspect the error.

## General web (5)

| Wrapper | Index type | Args | Keys | Free tier |
|---|---|---|---|---|
| `serper_search.sh` | Google SERP wrapper | `<query> [num] [tbs]` (tbs e.g. `qdr:d`) | SERPER_API_KEY (+_BACKUP) | 2,500/mo per key |
| `brave_search.sh` | Independent crawler | `<query> [count]` | BRAVE_API_KEY (+_BACKUP) | ~$5 credit pool/mo per key |
| `brave_llm_context.sh` | Pre-extracted LLM markdown chunks | `<query> [count]` | BRAVE_API_KEY (+_BACKUP) | same Brave credit pool |
| `tavily_search.sh` | AI-cleaned, LangChain-native | `<query> [max_results] [depth]` (default basic) | TAVILY_API_KEY (+_BACKUP) | 1,000 credits/mo per key |
| `linkup_search.sh` | Neural, instruction-aware, EU/GDPR | `<query> [depth]` (standard/deep) | LINKUP_API_KEY (+_BACKUP) | $20 balance per key (one-time) |
| (exa) | Neural semantic | via `exa-search` skill | EXA_API_KEY | 1,000 credits/mo |

## B2B / people / company (5)

| Wrapper | Index type | Args | Keys | Free tier |
|---|---|---|---|---|
| `pdl_lookup.sh` | Aggregated B2B database | `autocomplete <field> <text>` \| `enrich <param>=<value>` | PDL_API_KEY (+_BACKUP) | 100 lookups + 25 IP/mo per key |
| `theirstack_jobs.sh` | Hiring-signal intelligence | `<job_title_or_tech> [limit]` | THEIRSTACK_API_KEY (+_BACKUP) | permanent free tier (JWT) |
| `explorium_enrich.sh` | Aggregated B2B (lowercase `api_key` header) | `<company_domain_or_name>` | EXPLORIUM_API_KEY (+_BACKUP) | 100 credits / 90-day trial per key |
| `lusha_phone.sh` | Phone/direct-dial only | `<firstName> <lastName> <companyName>` | LUSHA_API_KEY (single, no backup) | 40 credits/mo (5/phone) |
| `github_repo_people.sh` | Repo contributors/org via `gh` CLI | `<owner/repo>` | none (gh CLI auth, 5K req/hr) | free |

## Privacy / clinical / government (4, all free, keyless)

PHI never crosses the wire — pass only anonymized clinical terms.

| Wrapper | Source | Args |
|---|---|---|
| `pubmed_search.sh` | NCBI PubMed E-utilities (35M+ citations) | `<query> [retmax]` |
| `clinicaltrials_search.sh` | ClinicalTrials.gov API v2 | `<query> [pageSize]` |
| `openfda_drug.sh` | openFDA drug labels + adverse events | `label <term> [limit]` \| `event <term> [limit]` |
| `rxnorm_lookup.sh` | NLM RxNorm / RxNav (drug normalization) | `<drug_name>` |

## MCP-backed lanes (no wrapper — call the MCP tools directly)

| Lane | MCP | Tools | Cost |
|---|---|---|---|
| Perplexity / multi-step | `perplexity-server` | `search`, `get_documentation`, `find_apis`, `chat_perplexity`, `extract_url_content`, `check_deprecated_code` | $0 (scrapes free web UI) |
| Academic (21 sources) | `paper-search` | `search_pubmed`, `search_arxiv`, `search_semantic`, `search_openalex`, `search_biorxiv`, `search_medrxiv`, `search_europepmc`, `read_*`, `download_*` | $0 |
| Heavy extraction (preferred) | `firecrawl` | firecrawl_scrape, firecrawl_extract | free tier ~1,000 pages/mo (remote MCP) |
| Heavy extraction (last-resort fallback) | `chrome-devtools` | `navigate_page`, `take_snapshot`, `evaluate_script` | $0 |

**Heavy-extraction order:** Firecrawl -> perplexity-server `extract_url_content` -> chrome-devtools.

## OpenRouter deep-research models (fallback only)

POST `https://openrouter.ai/api/v1/chat/completions`, `Authorization: Bearer $OPENROUTER_API_KEY`.

| Model | Use |
|---|---|
| `perplexity/sonar-deep-research` | Perplexity multi-step when MCP can't (paid fallback only) |
| `openai/o4-mini-deep-research` | OpenAI-style reasoning depth (no MCP equivalent) |
| `perplexity/sonar-reasoning-pro`, `perplexity/sonar-pro` | lighter Perplexity tiers |

Reserve `openai/o3-deep-research` — 5x cost; o4-mini delivers ~85-90% quality at 20% price.

## Never present by design

`PERPLEXITY_API_KEY` (use perplexity-server MCP -> OpenRouter fallback), `APOLLO_API_KEY`, `HUNTER_IO_API_KEY` — lanes are covered by the engines above.

## Endpoint quirks (verified live during build)

**General web:**
- **Brave LLM Context:** the dedicated Summarizer + AI-Grounding endpoints are now paywalled (Pro AI / Answers plan). On the free Data-for-Search key the wrapper falls back to web search with `summary=1` + `extra_snippets=1` and returns the dense, citation-marked `results[].description` fields (no fabricated summary). Upgrade path noted in the file header: swap `_req` to `POST /res/v1/chat/completions` `{"model":"brave",...}` if Hunter buys the Answers plan.
- **Brave web:** GET only (`-G --data-urlencode`), header `X-Subscription-Token`, **1 req/sec** rate cap — space Brave calls or you eat a 429 (which wastes a fallover).
- **Tavily:** auth is `Authorization: Bearer tvly-...`; `search_depth` has FOUR values (`basic`=1cr default, `advanced`=2cr, `fast`, `ultra-fast`); `max_results` caps at 20; `include_answer:true` adds a synthesized answer.
- **Linkup:** body uses `q` (not `query`); result title field is **`.name`** (not `.title`) — matters for downstream jq; `depth` = `fast`/`standard`/`deep`; 45s timeout for `deep`.

**B2B:**
- **PDL:** header `X-Api-Key`; enrich is GET via `-G --data-urlencode`; `profile=github.com/<user>` resolves a person from a GitHub URL (verified: torvalds -> Linus Torvalds). `/v5/autocomplete` is the zero-credit smoke endpoint.
- **TheirStack:** `Authorization: Bearer <348-char JWT>`. HARD requirement: body must carry at least one date filter (`posted_at_max_age_days` etc.) or it 422s. Wrapper always sends `posted_at_max_age_days` (default 30, override `THEIRSTACK_MAX_AGE_DAYS`) + `job_title_or` + `job_country_code_or:["US"]`.
- **Explorium:** header lowercase `api_key`. Working body (clean 200): `{"mode":"full","size":N,"page_size":N,"page":1,"filters":{"company_name":{"values":["<name>"]}}}`. Required top-level: `mode` + `page_size`. NO direct `domain` filter — use `company_name` or resolve domain->business_id first. Lists use `{"values":[...]}`, scalars `{"value":x}`.
- **Lusha:** header `api_key`; params are case-sensitive camelCase (`firstName`,`lastName`,`companyName`). Valid combos: name+company, or `email` alone, or `linkedinUrl` alone. Phone path adds `filterBy=phoneNumbers&revealPhones=true`. No-match returns `EMPTY_DATA` with `isCreditCharged:false` (no credit burned).
- **GitHub (cross-platform trap):** call `gh api repos/<owner>/<repo>` WITHOUT a leading slash — Git Bash/MSYS rewrites `/repos/...` into a filesystem path. Wrapper also sets `MSYS_NO_PATHCONV=1` (no-op on macOS/Linux). Requires `gh auth login` with any GitHub account (no API key).

**Clinical / gov (keyless):**
- **PubMed:** two-step (esearch -> esummary, JSON). Keyless ~3 req/s per IP — if a Team wave fans out parallel PubMed calls, throttle to <=3 concurrent or set `NCBI_API_KEY` (lifts to 10/s). `OPENFDA_API_KEY` similarly optional.
- **openFDA:** query string is hand-built (`search=field:term`, `+` = OR/space) — do NOT `--data-urlencode` (it mangles `:` and `+`). Zero hits = HTTP 404 with `.error.code=="NOT_FOUND"` (wrapper exits 0 "No results", not a failure). Event branch surfaces serious-flag + date + de-duped MedDRA reactions, not the co-reported-drug firehose.
- **ClinicalTrials.gov v2:** data nests 3-4 levels in `protocolSection`; `designModule.phases[]` is empty for observational trials -> rendered `N/A`.
- **RxNorm:** `tty` multi-value passed as `"IN PIN SCD"` (curl encodes space->`+`, which RxNav expects). DailyMed SPL lookup is a non-fatal bonus.
