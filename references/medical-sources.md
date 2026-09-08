# Medical Sources

Load this reference when the research question is health, clinical, pharmaceutical,
supplement, peptide, lab-test, protocol, biotech, regulatory, or anything where domain
expertise materially shapes which sources to consult. Sibling to `sources.md` — sources.md
covers general patterns; this file covers medical specifics.

Use these sources by name in Exa queries (e.g., `site:fda.gov "warning letter" {brand}`)
or as starting points the agent can crawl.

---

## Regulatory + safety databases (US)

### FDA
- `fda.gov/safety/recalls-market-withdrawals-safety-alerts` — recall database
- `fda.gov/inspections-compliance-enforcement-and-criminal-investigations/compliance-actions-and-activities/warning-letters` — FDA Warning Letters search (full text)
- `accessdata.fda.gov/scripts/cder/daf/` — Drugs@FDA approval database
- `accessdata.fda.gov/scripts/cder/safetyreports/` — MedWatch + FAERS adverse-event reports
- `fda.gov/drugs/human-drug-compounding/bulk-drug-substances-used-compounding-under-section-503a-fdc-act` — 503A bulk substance list (Category 1/2/3 status — load-bearing for peptide eligibility)
- `fda.gov/drugs/human-drug-compounding/pharmacy-compounding-advisory-committee` — PCAC meeting minutes + transcripts
- `fda.gov/medical-devices/in-vitro-diagnostics/laboratory-developed-tests` — LDT final rule (2024) status
- `fda.gov/regulatory-information/search-fda-guidance-documents` — FDA guidance documents

### DEA
- `deadiversion.usdoj.gov/` — DEA controlled-substance schedules + registrant lookup
- `deadiversion.usdoj.gov/schedules/` — current Schedule I-V listing

### State pharmacy boards
- Per-state pharmacy board lookup (search "[state] board of pharmacy disciplinary actions")
- `nabp.pharmacy/` — National Association of Boards of Pharmacy (search disciplined registrants)

### FTC
- `ftc.gov/news-events/news/press-releases` — FTC enforcement press releases (false advertising, health-claim actions)

---

## Regulatory + safety databases (international)

- `ema.europa.eu/en` — European Medicines Agency
- `gov.uk/government/organisations/medicines-and-healthcare-products-regulatory-agency` — UK MHRA
- `tga.gov.au/` — Australia Therapeutic Goods Administration
- `hc-sc.gc.ca/dhp-mps/index-eng.php` — Health Canada Therapeutic Products Directorate
- `swissmedic.ch/` — Switzerland Swissmedic
- `pmda.go.jp/english/` — Japan PMDA

---

## Compounding pharmacy registries

- `achc.org/programs/pcab/` — PCAB (Pharmacy Compounding Accreditation Board) registry — accredited 503A pharmacies
- FDA's 503B Outsourcing Facility List — search `fda.gov/drugs/human-drug-compounding/registered-outsourcing-facilities`
- `iacprx.org/` — IACP (International Academy of Compounding Pharmacists)

---

## Third-party testing + certification

### Supplements
- `usp.org/verification-services/supplements-verification` — USP Verified products
- `nsfsport.com/certified-products/` — NSF Certified for Sport
- `informed-sport.com/protected-products` — Informed-Sport certified
- `consumerlab.com/` — ConsumerLab independent testing (paywalled)
- `cleanlabelproject.org/purity-award/` — Clean Label Project Purity Award

### Peptides
- `janoshik.com/test-results` — Janoshik (ISO 17025, Slovakia) public peptide test results
- `eurofins.com/` — Eurofins testing (multiple labs globally)

### Food
- `ewg.org/foodscores/` — EWG Food Scores
- `cleanlabelproject.org/` — Clean Label Project (covers food + supplements)
- `consumerreports.org/health-food/` — Consumer Reports food testing

### Lab tests
- `cap.org/laboratory-improvement/laboratory-accreditation` — CAP-accredited labs
- `cms.gov/regulations-and-guidance/legislation/clia/lookup` — CLIA database lookup

---

## Clinical evidence

- `pubmed.ncbi.nlm.nih.gov/` — PubMed (primary literature search)
- `clinicaltrials.gov/` — registered clinical trials
- `cochranelibrary.com/` — Cochrane systematic reviews
- `bmj.com/` — British Medical Journal
- `nejm.org/` — New England Journal of Medicine
- `jamanetwork.com/` — JAMA + JAMA specialty journals
- `mayoclinic.org/` — Mayo Clinic clinical reference
- `examine.com/` — Examine.com supplement research summaries (independent, evidence-tier)

---

## Functional-medicine specialty labs

- `dutchtest.com/` — DUTCH (urinary hormone metabolites)
- `diagnosticsolutionslab.com/` — GI-MAP, Cyrex
- `gdx.net/` — Genova Diagnostics (NutrEval, FMV, GI Effects)
- `doctorsdata.com/` — Doctor's Data (heavy metals, hormone, stool)
- `zrtlab.com/` — ZRT Laboratory (saliva, dried-blood-spot hormones)
- `bostonheartdiagnostics.com/` — advanced cardiovascular panels
- `realtimelab.com/` — Realtime Laboratories (mycotoxins for CIRS)

---

## Consumer-direct biomarker platforms

- `functionhealth.com/`
- `insidetracker.com/`
- `superpower.com/`
- `wildhealth.com/`
- `parsleyhealth.com/`
- `everlywell.com/`

---

## Reference labs

- `questdiagnostics.com/`
- `labcorp.com/`
- `aruplab.com/`

---

## Consumer voice — subreddits

Health & medical:
- r/Peptides, r/PeptideTherapy, r/peptidesource
- r/Nootropics, r/StackAdvice, r/Biohackers
- r/Supplements, r/SupplementSource
- r/Testosterone, r/Trans, r/Menopause, r/HRT
- r/Microdosing, r/Psychonaut
- r/loseit, r/Semaglutide, r/Tirzepatide, r/Mounjaro, r/Wegovy, r/Ozempic
- r/AskDocs, r/medicine, r/FamilyMedicine
- r/functionalmedicine, r/Longevity, r/Biohacking
- r/MTHFR, r/MCAS, r/CFS, r/Lyme, r/MoldToxicity
- r/keto, r/carnivore, r/AIPdiet
- r/AskBattlestations — when looking for ground truth on what people actually use

Use the standard pattern from sources.md: `site:reddit.com/r/Peptides "BPC-157" "in my experience"`

---

## Consumer voice — Twitter/X

Health-influence accounts worth searching:
- Hubermanlab + the Huberman-Verified researchers Andrew links
- PeterAttiaMD
- DaveAsprey
- BenGreenfield
- DrRhondaPatrick
- Dr_Roxanne_Wells, Dr_Gabrielle_Lyon — for women's health framing
- The functional-medicine prescriber community (search "503A" "BPC-157" "compounding")

Pattern: `site:x.com OR site:twitter.com "{compound}" {context}`

---

## Consumer voice — podcasts + transcripts

- **Huberman Lab** — Andrew Huberman, Stanford neuroscientist; clinical depth on neurochemistry, sleep, hormones, supplements. Transcripts: `hubermanlab.com/episodes/`
- **The Drive (Peter Attia)** — longevity + zone-2 cardio + apoB obsession. `peterattiamd.com/podcast/`
- **Found My Fitness (Rhonda Patrick)** — micronutrient research, sauna, omega-3, vitamin D. `foundmyfitness.com/episodes`
- **The Joe Rogan Experience** — when health topics surface (search transcripts for compound names)
- **Bulletproof Radio (Dave Asprey)** — biohacker mainstream
- **The Genius Life (Max Lugavere)** — cognitive health, nutrition
- **Functional Medicine podcast circuit** — Hyman, Gundry, Mercola, Wahls, Bredesen
- **Limitless / The Skeptic's Guide** — counter-balance for biohacker hype

For transcripts: most podcasts publish transcripts on their own site; otherwise use `yt-dlp` to grab YouTube auto-captions or run the `transcribe` skill.

---

## Influencer + content sources

- TikTok health/biohacker — search by hashtag (e.g., `#bpc157`, `#peptides`, `#functionalmedicine`)
- Instagram — clinician accounts often post protocols + before/after; check disclosures
- YouTube biohacker channels — Huberman clips, Thomas DeLauer, More Plates More Dates (especially for peptide reviews + sourcing), Goal Guys
- Substack health stack — Bryan Johnson (Blueprint), William Brown (Curative), Casey Means (Levels), Sarah Ballantyne
- Newsletters: Examine Plus, MoneyAndMuscle, Marginal Revolution health columns

For peptide-specific sourcing chatter — **More Plates More Dates** (Derek) has the deepest YouTube + forum reach.

---

## Search trends + emerging-signal tools

- `trends.google.com/` — Google Trends; compare compound names over time, by region
- `explodingtopics.com/` — Exploding Topics emerging-signal tracker
- `glimpse.com/` — health-trend tracker (uses Google Trends + first-party)
- `pinterest.com/trends/` — useful for consumer-product discovery (especially supplements + tinctures)

---

## Recall + incident catalogs

- Janoshik test results (see above) — gray-market peptide failure rate; ~43% in 2024
- FDA Recalls (see above)
- `fdarecalls.com/` — third-party recall aggregator
- ConsumerSafety.org — class-action + recall aggregator
- TopClassActions.com — pending class actions

---

## Practitioner forums + clinician communities

- **Practical Innovations in Medicine** — functional-medicine clinical podcast + forum
- **Institute for Functional Medicine (IFM)** member directory — for functional-medicine clinicians
- **A4M** (American Academy of Anti-Aging Medicine)
- **AAEM** (American Academy of Environmental Medicine)
- **ACAM** (American College for Advancement in Medicine)
- **IPMS** (International Peptide Society) — for peptide-specific clinician training
- **Reddit r/medicine + r/FamilyMedicine** — physician-only subs (often locked but archivable)

---

## Source Trust Hierarchy (medical-specific)

1. **⭐⭐⭐ Highest:** PubMed-indexed RCTs + systematic reviews; FDA / EMA primary documents; CLIA + CAP labs; Janoshik test results for peptides; ConsumerLab / Clean Label Project / USP / NSF certifications.
2. **⭐⭐ High:** Cochrane reviews; BMJ / NEJM / JAMA articles; Examine.com summaries; first-party clinician statements with credentials; Reddit posts with documented lab results.
3. **⭐ Low:** Single-clinician anecdotes without published outcomes; brand-published "third-party testing" without naming the third party; influencer endorsements with undisclosed sponsorship.
4. **⚠️ Avoid:** "Top 10 peptides" affiliate listicles; vendor's own product reviews; weight-loss / muscle-building claims with no cited evidence; "anti-aging" claims without peer-reviewed support; podcasts where the host sells the supplement being discussed.

---

## Red Flags (medical-specific)

- Compound name used loosely (e.g., "BPC peptide" without "157" — could be any in the BPC family)
- No batch-specific COA cited when the topic is peptide sourcing
- Mismatch between cited study and the claim (study was animal-model; claim is human clinical)
- "Studies show" without specific citations
- Brand-sponsored testing where the sponsor selected the testing entity
- Heavy reliance on a single Reddit thread without corroboration
- Influencer's first promotion of the compound coincides with their first paid placement
- Cherry-picked single RCT when multiple RCTs exist with contradictory results

---

## Query patterns by medical sub-domain

### Peptides
```
site:reddit.com/r/Peptides "{compound}" "in my experience"
site:janoshik.com/test-results {compound}
site:fda.gov/drugs/human-drug-compounding {compound}
"{compound}" "503B" OR "PCAB" OR "outsourcing facility"
"{compound}" "BPC-157" pharmacokinetics
"{compound}" "endotoxin" OR "LAL" -site:vendor.com
```

### Supplements
```
site:usp.org "{brand}"
site:nsfsport.com "{brand}"
site:consumerlab.com "{brand}"
site:cleanlabelproject.org "{brand}"
"{brand}" "warning letter" site:fda.gov
"{ingredient}" "systematic review" OR "meta-analysis"
```

### Lab tests
```
site:cap.org "{lab}"
site:cms.gov/regulations-and-guidance/legislation/clia/lookup "{lab}"
"{platform}" methodology OR validation "mass spectrometry"
"{platform}" "reference range" "optimal" OR "functional"
```

### Protocols
```
"{protocol}" RCT OR "randomized controlled trial"
"{protocol}" contraindication OR "adverse event"
site:pubmed.ncbi.nlm.nih.gov "{protocol}" outcomes
site:examine.com "{protocol}"
"{protocol}" "monitoring" "lab markers"
```

### Regulatory news
```
site:fda.gov/news-events {topic}
site:ftc.gov/news-events {topic}
"PCAC" "{compound}" -site:vendor.com
"{compound}" "Category 2" OR "Category 1" site:fda.gov
"{compound}" "warning letter" site:fda.gov
```

### Consumer buzz
```
site:reddit.com {compound} "in my experience" -"affiliate"
site:reddit.com/r/{relevant_sub} {compound}
site:x.com OR site:twitter.com "{compound}" -is:retweet
site:hubermanlab.com {compound}
site:peterattiamd.com {compound}
site:foundmyfitness.com {compound}
trends.google.com/trends/explore?q={compound}
```
