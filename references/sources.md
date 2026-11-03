# Source Patterns

## Exa Best Practices

Write queries conversationally—Exa uses semantic understanding:
- "developers who switched from [X] to [Y] and why"
- "honest review of [product] from someone who used it"
- "problems with [tool] that users complain about"

**Exa scripts** (`~/.claude/skills/exa-search/scripts/`; never the `mcp__claude_ai_Exa__*` connector tools):
- `exa_search.sh` — general queries, `type` auto
- `exa_deep_search.sh` — research tasks, returns a synthesized `.output` plus rich context
- `exa_code.sh` — code/repo queries

**Categories:** `company`, `people`, `publication` (replaced `research paper`), `news`, `personal site`, `financial report`. `pdf` and `github` are being deprecated: use `includeDomains` instead (`tweet` is retired: Exa returns 400, and `x.com` domain filters return nothing. For X posts use `serper_search.sh` with `site:x.com` plus a date range, or Exa over thread mirrors via `includeDomains: ["threadreaderapp.com","unrollnow.com"]`.)

**Filters:** `includeDomains`, `excludeDomains`, `startPublishedDate`, `category`

---

## Query Patterns by Category

### Products & SaaS
```
site:reddit.com {query} vs OR alternative OR "switched from"
site:reddit.com/r/SaaS {query}
site:news.ycombinator.com {query}
site:indiehackers.com {query}
"{tool}" limitation OR problem site:reddit.com
```
**Key subreddits:** r/SaaS, r/Entrepreneur, r/startups, r/smallbusiness

### Code & Repos
```
site:github.com {query} stars:>100
site:reddit.com/r/selfhosted {query}
site:reddit.com/r/opensource {query}
site:lobste.rs {query}
site:dev.to {query}
site:news.ycombinator.com "Show HN" {query}
"{repo}" abandoned OR unmaintained
```
**Key sources:** GitHub discussions, r/selfhosted, r/homelab, Lobsters, HN "Show HN"

### Health & Supplements
```
site:pubmed.ncbi.nlm.nih.gov {query}
site:examine.com {supplement}
site:reddit.com/r/Nootropics {query}
site:reddit.com/r/Supplements {query}
{compound} "systematic review" OR "meta-analysis"
"{supplement}" side effects
```
**Notes:** Prioritize RCTs over observational studies. Note sample sizes. Check for industry funding.

### Marketing & Business
```
site:indiehackers.com {query} revenue OR growth
site:substack.com {query}
site:reddit.com/r/marketing {query}
site:reddit.com/r/PPC {query}
```

### General Fallback
```
site:reddit.com {query} "in my experience"
site:news.ycombinator.com {query}
{query} -"top 10" -"best" -"ultimate guide"
```
The `-"top 10"` pattern filters SEO spam.

---

## Source Trust Hierarchy

1. **⭐⭐⭐ Highest:** Reddit (high-karma), HN, GitHub issues, personal blogs with real experience, PubMed/examine.com (health)
2. **⭐⭐ High:** IndieHackers, ProductHunt reviews, dev.to, Lobsters, Substack
3. **⭐ Low:** Official docs, marketing pages (verify with user sources)
4. **⚠️ Avoid:** Affiliate listicles, "Top 10" articles, reviews on vendor's own site

---

## Red Flags

- No specific details or numbers
- Generic praise without tradeoffs
- Suspiciously similar wording across "reviews"
- No negative feedback mentioned
- Heavy ads/popups on source domain
