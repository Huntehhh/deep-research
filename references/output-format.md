# Output Format Examples

These are **flexible templates**, not rigid requirements. Adapt structure, fields, and depth to the user's specific query. Add what's relevant, remove what isn't.

## Structure

### 1. Executive Summary (Always include)

2-3 sentences covering:
- Clear recommendation for their specific situation
- Why this ranking (criteria that mattered)
- Confidence level based on source quality

**Example:**
> "For cold email at your scale, **Instantly** edges out competitors on deliverability, though **Smartlead** offers better value under 5k contacts. Based on r/Emailmarketing consensus + IndieHackers reports. High confidence—8 sources across 3 platforms."

### 2. Comparison Table (When comparing options)

**Example fields** (adapt to query):

| Option | Best For | Key Limitation | Price | Sources |
|--------|----------|----------------|-------|---------|
| **Tool A** | [specific use case] | [real drawback] | $X/mo | ⭐⭐⭐ (Reddit, HN) |

**Other useful fields depending on query:**
- Learning curve, Integration ecosystem, Self-hosted option
- Study quality (for health), Maintenance status (for repos)
- Team size fit, Migration difficulty, API quality
- Whatever matters for the user's decision

### 3. Differentiators & Conflicts (When opinions differ)

| Comparison | Key Difference | Pro View | Con View | Verdict |
|------------|----------------|----------|----------|---------|
| **A vs B** | [factual difference] | "quote" — source | "quote" — source | [weighted take] |

### 4. Sources

Group by confidence. Note gaps.

**High-confidence:** Reddit thread on X, HN discussion, GitHub issue #123
**Supporting:** Blog post by Y, ProductHunt review
**Gaps:** No user reviews found for Tool C

---

## Flexibility Examples

**For a "best X for Y" query:** Heavy on comparison table, light on conflicts
**For a "A vs B" query:** Heavy on differentiators table, include both perspectives
**For health/supplement query:** Add columns for study type, sample size, effect size
**For repo query:** Add columns for stars, last commit, license, language
**For quick lookup:** Skip tables entirely if a direct answer suffices

**The user's query determines the format.** These examples exist to show what's possible, not to constrain the response.
