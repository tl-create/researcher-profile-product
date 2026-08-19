# Perfect Profile — guardrail funnel dashboard (fork kit)

Everything needed to run, modify, or rebuild the dashboard.

## Contents
| File | What it is |
|---|---|
| `pp-ceo-summary.html` | The dashboard. One self-contained file — no server, no build, no external dependencies. Open it in any browser or host it anywhere. |
| `recommender-guardrail-rules-and-queries.md` | The 19 rules, their sources, the funnel logic, sample results, and the QA-verified data defects. Read this first. |
| `recommender-filters.sql` | The BigQuery queries that produce every number (candidate → rule flags, aggregations). |
| `pp-ceo-queries.sql` | Full annotated query set for the CEO summary, incl. the RPS (GraphQL) equivalents used for verification. |
| `recommender-filter-deck-agent-prompt.md` | The generation prompt used to (re)build the deck with an AI agent. Useful if you want to regenerate rather than hand-edit. |

## How the dashboard works
- **Tabs:** Impact summary → Sample A (RT contributors) → Sample B (reviewers) → Full Context (universe funnel + appendix).
- **All data is embedded** in a single JSON block: `<script id="fxdata" type="application/json">`. It holds:
  - `rules` — the 19 rules (id, name, description). Array index = bit index.
  - `stages` — the 4 funnel layers, each listing which rule bits it applies (`active: [0,1,2,9]`, `eligible: [3–8]`, `identifiable: [10,11,12]`, `contactable: [13–18]`).
  - `universe` / `sampleA` / `sampleB` — candidate rows as `[id, …, channel, mask]`, where `mask` is a 19-bit integer: bit *n* set = the candidate passes rule *n*.
- The JS `compute()` function ANDs the enabled rule bits cumulatively per stage, so the funnel, per-rule drops, source splits, and live rule toggles are all derived client-side from the masks. Static text/tables (Impact tab tiles, layer table) are plain HTML — update them by hand if the data changes.

## To fork with new data
1. Run Q1 in `recommender-filters.sql` with your candidate id list (remap ids through `airak.AuthorSourceHistory` first — see the .md, defect 5a).
2. Build one integer mask per candidate (bit *n* = passes rule *n*, same bit order as `rules`).
3. Replace the rows in the `fxdata` JSON block.
4. Update the hardcoded numbers on the Impact tab (tiles, layer table, drop lines) to match.

## Known caveats (see the .md for detail)
- Activity flags (bits 0–2) over-drop genuinely active researchers: stale merged ids + a post-2023 author→publication linkage gap in AIRA. Both AIRAK and RPS inherit this.
- BigQuery access: bill to `gcp-innovation-hub`, read data via fully-qualified `ocean-breeze-tier-*` table names.
