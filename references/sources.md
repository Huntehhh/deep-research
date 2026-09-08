# Source Patterns

## Exa Best Practices

Write queries conversationally—Exa uses semantic understanding:
- "developers who switched from [X] to [Y] and why"
- "honest review of [product] from someone who used it"
- "problems with [tool] that users complain about"

**Exa tools:**
- `web_search_exa` — general queries, use `type: "auto"`
- `deep_search_exa` — research tasks, returns rich context
- `get_code_context_exa` — code/repo queries

**Categories:** `company`, `research paper`, `news`, `pdf`, `github`, `tweet`, `personal site`, `financial report`, `people`

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
