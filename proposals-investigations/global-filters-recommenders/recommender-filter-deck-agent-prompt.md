# Agent prompt — global filters in the recommender pipeline (analysis + HTML)

Copy everything below the line into the other agent.

---

## Role and occasion

You are producing a focused analysis and a single-page HTML deck for an internal working session with the recommender and product teams at Frontiers. The subject is narrow and must stay narrow: **we are proposing a new global permissibility filter inside the recommender pipeline, and this deck shows how it would work and what it would do to real recommender output.**

This is not a company-wide population deck. Do not build a funnel from all researchers on record. Do not introduce Perfect Profile coverage, Target Audience denominators, or population-scale counts except as a single appendix reference. Earlier drafts failed by being too broad.

## Tone — read this before writing a single line

The filter being proposed **does not exist yet**. It is a new capability we are asking for, not a control that someone failed to implement.

Therefore:

- Never describe the current pipeline as leaking, missing controls, having gaps, being unguarded, or losing filters.
- Never imply that any team should already have been doing this.
- Describe how each retrieval channel's population is currently constituted as a matter of **design consequence**, not deficiency. The channels were built to answer retrieval questions and they answer them.
- The argument is about **ownership and coupling**: permissibility has never been any step's job, so it currently emerges as a side effect of decisions made for other reasons. We are proposing to give it a home.

If a sentence would make the recommender team defensive, rewrite it.

## The pipeline this is about

```
Input Context (LLM summarized)
  → Retrieval ─┬─ Publications DB
               └─ Researcher Profiles DB  (AI expertise profiles + embeddings)
  → Merge Results
  → Filtering: global        ← THE STEP WE ARE PROPOSING TO DEFINE
  → Filtering: use case specific
  → Scope matcher
  → Engagement score ranking
```

## How each channel's population is actually constituted

This section is the intellectual core of the deck. Present it factually.

### Publications channel ("similar publication")

Retrieval constraints applied inside the channel:

- Publication within the last 36 months
- First and last author only

These are relevance heuristics: recency and likely responsibility for the work.

### Researcher Profiles channel ("similar expertise embedding")

This channel can only retrieve a researcher who has an AI expertise profile and embeddings. A researcher gets those if and only if **all** of the following hold:

1. The AIRA profile was reached and selected by a segment loader (Stage 01).
2. It survived augmentation exclusion (Stage 02.01): not over-merged, has a current organization, has a DOI, has fields of study.
3. The expertise LLM call succeeded — no `empty_input`, no `citation_policy_violation`, no transient error — and returned `identification.uniquely_identified = "TRUE"` with a populated `research_focus_and_expertise` section (Stage 02.02).
4. The result was successfully MERGEd into `..._output_all` with a non-null `profile_expertise`.
5. In `01_extract_facts_for_embeddings.py`: not already present in `researchers_profile_facts`, and the fact-extraction call returned at least one fact.
6. In `02_embed_facts.py`: the fact was not already in `researchers_profile_facts_embeddings`, `fact_text` was non-empty, and the embedding call succeeded.

Two current behaviours to flag factually, without judgement:

- **The h-index exclusions in Stage 02.01 are explicitly disabled.** Both `h-index = 0` and `h-index > 5` are hard-coded to FALSE, so those researchers are no longer excluded at augmentation. This is a concrete, recent example of the eligible population changing as a consequence of an enrichment decision.
- **Researchers where the LLM returned `uniquely_identified = FALSE` are stored with `profile_expertise = NULL` and never reach the embeddings pipeline.** They are therefore absent from this channel entirely, and that absence is not currently visible anywhere.

### The point to draw from this

The Researcher Profiles channel's population is determined by whether an enrichment pipeline could successfully describe a person — a question about data completeness and LLM success, asked for good reasons that have nothing to do with outreach. Some of its preconditions incidentally overlap with permissibility: "not over-merged" is an identity-trust rule, and "has a current organization" is an affiliation rule. But they are enforced because enrichment needs them, not because outreach requires them.

The Publications channel has no equivalent preconditions, because it does not need them.

So the two channels contain structurally different populations, and channel overlap is very small in both samples — 165 of 12,809 candidates for Research Topics, and 1 to 7 candidates per manuscript for reviewers. Neither channel was ever asked to decide whether a researcher may be contacted. That question currently has no owner, and its answer today is an emergent property of enrichment engineering. **That is what the proposed global filter is for.**

## The organising principle

> **Retrieval decides who is relevant. The global filter decides who is permissible.**

Classification to present and respect throughout:

| Rule | Where it sits today | What it is | Proposal |
|---|---|---|---|
| Publication within 36 months | Publications channel | Relevance | Unchanged, stays in retrieval |
| First and last author only | Publications channel | Relevance | Unchanged, stays in retrieval |
| Has a DOI, has fields of study | Profiles channel, enrichment precondition | Enrichment feasibility | Unchanged, stays in the enrichment pipeline |
| Has a current organization | Profiles channel, enrichment precondition | Affiliation — overlaps permissibility | Also asserted centrally, so it holds for both channels |
| Not over-merged | Profiles channel, enrichment precondition | Identity trust — permissibility | Asserted centrally, so it holds for both channels |
| Consent and opt-out | No step owns it | Permissibility | Global filter |
| Ethics, integrity, country, competitor, SPP | No step owns it | Permissibility | Global filter |
| Email validity and deliverability | No step owns it | Permissibility | Global filter |
| Duplicate record, missing name | No step owns it | Permissibility | Global filter |
| Already committed, recently invited | No step owns it | Timing | Global filter emits a **signal**; the product decides |

State prominently that this proposal **does not change the relevance heuristics inside retrieval and does not change the enrichment preconditions**. It adds one step that asserts permissibility consistently for candidates from both channels. Without that, the audience will assume you are proposing to rewrite their retrieval logic and the meeting will be about that instead.

## Input data

Two real recommender outputs. Use both. Keep them separate throughout — never pool them into one number.

### Sample A — Research Topic contributors
`/Users/tzui.liao/Downloads/bquxjob_757bfd36_19ffbc11041.csv`

- 12,859 rows, 12,809 unique `aira_id`, 5 `research_topic_id` across 5 journals
- Columns: `journal`, `research_topic_id`, `topic_title`, `aira_id`, `in_profiles`, `in_publications`
- `in_profiles` / `in_publications` are the channel attribution flags
- Observed channel mix: publications only 7,859 · profiles only 4,835 · both 165
- Candidates per topic: min 2,168 · mean 2,572 · max 2,751
- No ranking information

### Sample B — Manuscript reviewers
`/Users/tzui.liao/Downloads/review-recommender-retrieval-results.xlsx`

- Sheets: `Read Me`, `Overview`, then one per journal: `Cognition`, `Hematology`, `Immunology`, `Marine Science`, `Nutrition`
- `Overview` columns: Article ID, Journal, Title, Stage, Submitted At, Latest Reviewer Invitation At, Channel Result Rows, Distinct Candidates, Profile DB Rows, Publication DB Rows, Overlap Candidates
- Per-journal sheet columns: `AIRA ID`, `Retrieval Channel`, `Channel Rank`, `Channels Found In`, `Other Channel Rank`, `RRF Pool Rank (Pre-Ranking)`, `Profile Score`, `Profile Match Breadth`
- 1,000 rows per manuscript = **top 500 per channel, truncated by construction**. Distinct candidates 993–999; channel overlap 1–7.
- Read the `Read Me` sheet and honour anything it says about how the sample was built.

### One discrepancy to resolve before you rely on it

An earlier description of the Profiles channel said it required "3 or more publications." The precondition chain above specifies "has a DOI" but not a publication-count threshold. Establish which is correct — the threshold may sit in the segment loader at Stage 01 — and state what you found. Do not assume either version.

## Analyses to run

Join both samples to the outreach exclusion data by AIRA ID. Use the Researcher Profile Service where a rule has a primary reason code, and BigQuery (`ocean-breeze-tier-1.airak`, `ocean-breeze-tier-2.researcher_availability`) where it does not. State per rule which source you used. Use one snapshot date for everything and print it.

### A. The headline — impact on what a human actually sees

**The most important analysis in the deck.** Aggregate rates across a thousand candidates are abstract. What lands is the rate inside the list that reaches a handling editor.

Using `RRF Pool Rank (Pre-Ranking)` on Sample B, report the share failing at least one proposed rule within the top 10, 20, 50, 100 and the full pool — per manuscript and pooled across the five. Then answer plainly: **if we surface N reviewers, how many are people we should not or cannot contact?**

Flag that RRF rank is pre-ranking, so this is a proxy for the delivered list, not the delivered list. Sample A has no ranking, so this analysis exists only for reviewers; say so rather than inventing a proxy.

### B. Impact on the full pool, per request

Per sample: candidates evaluated, share failing at least one rule, share clean. Then the same per request — five research topics and five manuscripts, listed individually as named rows. N is 5 in each case, so no distributions, no means presented as population estimates, no extrapolation.

Report absolute surviving counts too, because "2,572 candidates became 430" is the operationally meaningful statement.

### C. Failure composition, ordered by size

Per sample, share failing each group, largest first, not by tier number:

- Cannot reach — no email on file, no deliverable address, bounced
- Identity not resolved — over-merged, duplicate record, missing name, missing affiliation
- Should not contact — watchlist, integrity retractions, ineligible country, competitor, SPP
- Not permitted — globally unsubscribed, opted out of contact, opted out of lead
- Should wait — active campaign, recently invited, open opportunity, recently closed opportunity

Mark each rule **irreversible** (consent) or **recoverable** (data gap, timing). Show the "not permitted" and "cannot reach" subtotals side by side; the expected finding is that consent costs a few percent while email costs the majority, which makes this a data-supply roadmap rather than a compliance gate.

Also compute **failing exactly one group**, and specifically **blocked on email alone**.

### D. Channel attribution

Split every figure above by channel: publications-only, profiles-only, both.

Then characterise what each channel's population actually looks like against the proposed rules — descriptively, as a comparison of two differently-constituted populations, not as a scorecard:

1. **Identity resolution by channel.** Over-merge and duplicate rates in each. The enrichment preconditions mean the profiles channel should be near zero on over-merge; report what the publications channel looks like. This quantifies what asserting the rule centrally would add.
2. **Affiliation by channel.** Share with no current organization, by channel.
3. **Recency by channel.** Last-publication-year distribution for profiles-channel candidates.
4. **Publication count by channel.** Distribution for publications-channel candidates.
5. **Email and consent by channel.** These should look similar across channels, since neither channel selects on them. Confirm or refute; if they differ, that is interesting and worth explaining.

Also report the overlap candidates (165 in Sample A, 1–7 per manuscript in Sample B) and their failure rate, noting that with numbers this small it is directionally interesting and statistically useless.

### E. The AI expertise profile funnel

Quantify the precondition chain, since it determines who the profiles channel can ever return:

- AIRA profiles considered by the segment loader, and how many were selected
- Dropped at augmentation exclusion (Stage 02.01), by reason: over-merged, no current organization, no DOI, no fields of study
- Expertise LLM outcomes: succeeded, `empty_input`, `citation_policy_violation`, transient error
- Of successes, how many returned `uniquely_identified = FALSE` and are therefore stored with `profile_expertise = NULL` — these never reach embeddings and can never be recommended through this channel
- Merged with non-null `profile_expertise`
- Reached `researchers_profile_facts` with at least one fact
- Reached `researchers_profile_facts_embeddings`

Then two specific questions:

- **What the disabled h-index exclusions admit.** Among candidates in both samples, how many have h-index = 0, and how many have h-index > 5 — the two groups Stage 02.01 no longer excludes. Present as a factual consequence of a live configuration, not as an error.
- **How large is the `uniquely_identified = FALSE` population**, and what does it look like against the proposed rules? These are identity-resolution outcomes currently expressed as absence from the candidate pool.

If any of these stages cannot be counted from available tables, list them under section F rather than estimating.

### F. What cannot be measured

Every rule with no usable signal, and why. Known cases to carry forward and re-verify:

- `IsDeceased` and `IsRetired` are empty on all author rows
- Out of office has no signal in BigQuery; the DEO screen count of 938 counts editorial roles, not people
- "Unsubscribed for Research Topic communication" has no code in the 22-code dictionary
- The `ANV` "no verified email" code is unusable because it only ever appears alongside another exclusion; measure email from address validity instead
- Several timing rules (recent review or handling assignment, active or recent submission, recently closed Research Topic) carry no exclusion code, so any "should wait" figure is an upper bound

## Deck structure

One page. Tabs only if genuinely needed.

1. **Where this plugs in.** The pipeline diagram with the proposed step highlighted. State the scope: retrieval heuristics and enrichment preconditions are unchanged; we are defining one new step. 
2. **How each channel's population is constituted.** The publications channel's relevance constraints, and the AI expertise precondition chain. Factual, no evaluation.
3. **Which questions are answered where.** The rule classification table. The point to land: permissibility currently has no owner, and where it is partially satisfied today it is a side effect of enrichment feasibility. Use the disabled h-index exclusions as the concrete illustration that eligibility can change without an outreach decision.
4. **Impact on the delivered list.** Analysis A. Largest number on the page.
5. **Impact on the full pool.** Analysis B, both samples, five named requests each.
6. **What drives the loss.** Analysis C, ordered by size, irreversible versus recoverable, consent-versus-email contrast called out.
7. **Block versus signal.** Permissibility rules return a block, identical across products. Timing rules return a reason code the recommender uses to demote rather than remove, since removing a good candidate for a timing reason loses them permanently.
8. **The ask.** One service at the proposed step; one reason-code vocabulary; permissibility asserted centrally so it holds for candidates from both channels; email coverage as the top data priority because it is the binding constraint; timing rules delivered as ranking input; one named owner for rule definitions and their version history.

Appendix: the AI profile funnel from analysis E, per-rule tables per sample, sources and snapshot date, unmeasurable rules, conventions.

## Hard constraints

1. **Tone.** Re-read the tone section before writing. No leak, gap, missing-control or should-have-been language anywhere.
2. **Keep the two samples separate.** Research Topic contributors and manuscript reviewers are different populations retrieved differently. Never merge them into a single headline number.
3. **State the base for every percentage**, in the label or immediately beside it.
4. **N is 5 per sample.** Five named requests. No error bars, no extrapolation to "all manuscripts."
5. **Disclose the truncation.** Sample B is the top 500 per channel, so full-pool statistics are conditioned on that cut and per-request survival counts are floors. Establish whether Sample A is also capped; if you cannot, label its counts as floors too.
6. **Rules overlap.** Individual counts never sum to the combined total. Always show a "fails at least one" row, labelled as the honest total.
7. **One email definition** across the deck, and name it. Do not mix the `hasVerifiedEmail` proxy with address-level validity.
8. **No invented numbers.** Anything illustrative is labelled illustrative on the face of the slide. Unsourceable figures go in section F.
9. **Vocabulary.** Use "global filter", "retrieval channel", "enrichment precondition", "permissible", "relevant", "block", "signal". Do not introduce "addressable", "actionable audience", "profilable", or "Target Audience" — this deck is about a pipeline step, not an audience definition.
10. **Verify the arithmetic** at every stage and say in the appendix that you did.

## Output

Three files:

1. `recommender-filters.html` — self-contained single page, no external dependencies, print-friendly, clean executive styling.
2. `recommender-filters.sql` — every query, commented with which figure it produces.
3. A short written summary of: which figures you could not source and why; what you found on the "3 or more publications" discrepancy; and anything in the data that contradicts the argument the deck is making.

That last item matters. If the data does not support the argument, say so plainly rather than presenting it anyway.
