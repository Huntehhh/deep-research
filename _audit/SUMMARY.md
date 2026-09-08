# Audit Summary — deep-research

**Path**: `skills/deep-research/SKILL.md`
**Lines**: 351
**Frontmatter**: ok (description trimmed to <=1024 chars on 2026-05-29)
**Tier**: 1
**Purpose**: Intent-routed multi-engine research — solo mode (3-15 queries) or team mode (6-12 adversarial agents across 3 waves). Routes by intent across general web, B2B/people/company, clinical/medical, academic (paper-search MCP, 21 sources), $0 multi-step (perplexity-server MCP), and heavy URL extraction (Firecrawl MCP + free fallbacks). Multi-round anti-overlap search, backup-key fallover, critical-path failure alerting, and a guided first-run setup.
**Triggers**: "research this", "search the web", "compare options", "find alternatives to", "deep dive on", "deep research", "research team", "who is [person]", "find the team behind", "find papers on", "clinical evidence for", "find phone for", "build vs buy", "audience research", "investigate", "comprehensive research"
**Dependencies**: exa-search skill; perplexity-server MCP; paper-search MCP; firecrawl MCP (remote); nano-banana-pro (optional, Team viz); chrome-devtools MCP (optional, extraction fallback); agent-teams (pattern reference)
**Subfiles**: 16 scripts (14 engine wrappers + engine_common.sh + dr_config.sh); 8 references (routing, engines, sources, medical-sources, output-format, architecture, agent-templates, onboarding); `_dependencies/` bundle (perplexity-server + paper-search-mcp source + exa-search skill + install.sh/install.ps1/INSTALL.md)
**Last audit**: 2026-05-29
**Verdict**: KEEP / DISTRIBUTION-READY — de-personalized (no author/drive/IP strings; phantom niche-research dependency removed), dependency-bundled, configuration.json gate + guided onboarding added, Firecrawl-first heavy-extraction with credit-aware escalation. Packaged as `deep-research.skill` under `~/.claude/_distribution/deep-research/`.
