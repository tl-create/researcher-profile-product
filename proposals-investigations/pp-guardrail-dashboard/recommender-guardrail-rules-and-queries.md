# Recommender guardrail funnel — rules & queries

**Owner:** Tzu-i Liao · **Data snapshot:** AIRAK `airak_version = 2026-08-05` · **Last updated:** 19 Aug 2026
**Deck:** Perfect Profile CEO summary (`pp-ceo-summary.html`) · **Full SQL:** `recommender-filters.sql`

Every recommendation — any retrieval channel, any use case — passes one central permissibility gate before a person is surfaced. The gate is four layers of AND-ed rules. This doc lists the rules, where each one reads from, the queries behind the numbers, and two known data defects.

---

## 1 · The funnel

```
Merged results from recommenders
  → ACTIVE        (activity & quality)
  → ELIGIBLE      (ethics & compliance)
  → IDENTIFIED    (one real, resolvable person)
  → CONTACTABLE   (reachable & consented)
  = Surfaced recommendation
```

A candidate must pass **every enabled rule** of a layer to enter the next one. Order changes which layer gets credit for a drop, never the final population (all cuts are AND).

## 2 · The rules (19)

Primary sources: `ocean-breeze-tier-1.airak` (Author, AuthorMetric, Publication, PublicationAuthor, AuthorEmail) and `ocean-breeze-tier-2.researcher_availability` (reason codes per researcher).

### Active — activity & quality
| Rule | Definition | Source |
|---|---|---|
| Active | Publication in the last 36 months (forthcoming included) | `airak.Publication` + `airak.PublicationAuthor`, `PublishedDate ≥ CURRENT_DATE − 36 months` |
| Productive | ≥ 3 publications | `airak.AuthorMetric.PublicationCount` |
| H-index | H-index ≥ 1 | `airak.AuthorMetric.Hindex` |
| Affiliated | Current affiliation known | `airak.Author.HasAffiliation` |

### Eligible — ethics & compliance
| Rule | Definition | Source (reason code) |
|---|---|---|
| Not watchlisted | No open research-integrity flags | `AWL` |
| No integrity retractions | No retractions on integrity grounds | `ART` |
| Eligible country | No sanctions / compliance restrictions | `ABC` |
| Not SPP restricted | No SPP restriction | `SSR` |
| Not SPP exclusive | No SPP exclusivity | `SSX` |
| Not a competitor | Not associated with a competitor | `SCP` |

### Identified — one real, resolvable person
| Rule | Definition | Source |
|---|---|---|
| Not over-merged | Profile not potentially over-merged | `airak.Author.IsPotentialOvermerged` |
| No duplicate record | No duplicate Salesforce record | code `SDD` |
| Has last name | Last name on record | `airak.Author.LastName` / code `ALN` |

### Contactable — reachable & consented
| Rule | Definition | Source |
|---|---|---|
| Email on file | ≥ 1 email address | `airak.AuthorEmail` (any row) |
| Deliverable email | ≥ 1 address with `ValidityId IN (1,2)` | `airak.AuthorEmail` |
| Not bounced | Email has not bounced | code `SBE` |
| Not globally unsubscribed | | code `SGU` |
| Not opted out (contact) | | code `SOC` |
| Not opted out (lead) | | code `SOL` |

Timing codes (`SAC`, `SCI`, `SOP`, `SCO`, `SRT` — e.g. recently contacted) are treated as a **signal, not a block**, and sit outside the funnel.

## 3 · Current sample results (all four layers applied)

| | Sample A · RT contributors | Sample B · Reviewers |
|---|---|---|
| Base (candidate rows) | 12,859 | 4,977 |
| Active | 10,127 (78.8% kept) | 4,173 (83.8%) |
| Eligible | 9,244 (91.3%) | 3,826 (91.7%) |
| Identified | 7,561 (81.8%) | 3,345 (87.4%) |
| **Contactable = surfaced** | **4,009 (31.2% yield)** | **1,727 (34.7% yield)** |

The contact layer is the biggest leak in both samples; ~⅔ of its losses are simply *no email on record* (A −2,164, B −1,072).

## 4 · The core query — candidate → rule flags

One BigQuery query produces every flag; all funnel numbers are aggregations over its output. Billing project `gcp-innovation-hub`, cross-project reads.

```sql
WITH ids AS (SELECT id FROM UNNEST([<AIRA_ID_LIST>]) id),
r AS (  -- ALL exclusion codes per researcher
  SELECT author_id, ARRAY_AGG(DISTINCT reason_code) c
  FROM `ocean-breeze-tier-2.researcher_availability.researcher_availability_status_reason`
  WHERE author_id IN (SELECT id FROM ids) GROUP BY 1),
em AS (  -- deliverable = at least one address with ValidityId IN (1,2)
  SELECT AuthorId, LOGICAL_OR(ValidityId IN (1,2)) hd, COUNT(*) n
  FROM `ocean-breeze-tier-1.airak.AuthorEmail`
  WHERE AuthorId IN (SELECT id FROM ids) GROUP BY 1)
SELECT i.id AS aira_id,
  a.AuthorId IS NOT NULL                          AS in_airak,
  IFNULL(a.IsPotentialOvermerged,FALSE)           AS om,
  (a.LastName IS NULL OR TRIM(a.LastName)='')     AS mln,
  IFNULL(a.HasAffiliation,FALSE)                  AS aff,
  IFNULL(r.c,[])                                  AS codes,
  IFNULL(em.n,0)>0                                AS any_email,
  IFNULL(em.hd,FALSE)                             AS has_deliverable,
  m.LastYearAsAuthor, IFNULL(m.PublicationCount,0) AS pubs, IFNULL(m.Hindex,0) AS hindex
FROM ids i
LEFT JOIN `ocean-breeze-tier-1.airak.Author`       a ON a.AuthorId = i.id
LEFT JOIN `ocean-breeze-tier-1.airak.AuthorMetric` m ON m.AuthorId = i.id
LEFT JOIN r  ON r.author_id = i.id
LEFT JOIN em ON em.AuthorId = i.id;
```

The 36-month Active window is evaluated against `airak.Publication`/`airak.PublicationAuthor` directly:

```sql
SELECT pa.AuthorId, COUNT(DISTINCT p.PublicationId) pubs_36m
FROM `ocean-breeze-tier-1.airak.PublicationAuthor` pa
JOIN `ocean-breeze-tier-1.airak.Publication` p ON p.PublicationId = pa.PublicationId
WHERE pa.AuthorId IN (SELECT id FROM ids)
  AND p.PublishedDate >= DATE_SUB(CURRENT_DATE(), INTERVAL 36 MONTH)
GROUP BY 1;
```

Rule dictionary (22 codes, priorities, source systems):

```sql
SELECT reason_code, reason, exclusion_grade, source_system
FROM `ocean-breeze-tier-2.researcher_availability.dim_researcher_availability_reason`
ORDER BY exclusion_priority;
```

Candidates with no `airak.Author` row (382 of 17,750 unique ids; 293 rows in A, 91 in B) are carried through and fail at the identity cut.

## 5 · Known data defects (QA-verified)

A team QA of **153 authors dropped as "no publication in 36 months"** found every one has indexed papers in the window. Root-causing split this into two distinct defects:

### 5a · Stale-ID defect — fixable internally
Neither the recommender export nor the funnel remaps ids through AIRA's merge history. When profiles merge, publications move to the surviving id; a candidate carrying the old id looks publication-less and is cut as "inactive".

- 82/153 (54%) of the QA cohort are merged-away former ids — vs 5.0% (887/17,750) of all candidate ids. Stale ids concentrate exactly in the "dropped as inactive" pool.
- Remapping through `AuthorSourceHistory` recovers **57/153 as verifiably active in AIRAK**.

```sql
-- Remap candidate ids through merge history, then re-test the 36-month window
WITH remap AS (
  SELECT DISTINCT id AS old_id, COALESCE(h.AuthorId, id) AS cur_id
  FROM UNNEST(@ids) id
  LEFT JOIN `ocean-breeze-tier-1.airak.AuthorSourceHistory` h ON h.FormerAuthorId = id
)
SELECT r.old_id, COUNT(DISTINCT p.PublicationId) pubs_36m
FROM remap r
JOIN `ocean-breeze-tier-1.airak.PublicationAuthor` pa ON pa.AuthorId = r.cur_id
JOIN `ocean-breeze-tier-1.airak.Publication` p ON p.PublicationId = pa.PublicationId
WHERE p.PublishedDate >= DATE_SUB(CURRENT_DATE(), INTERVAL 36 MONTH)
GROUP BY 1;
```

**Fix:** pass every candidate id through `AuthorSourceHistory (FormerAuthorId → AuthorId)` before any join. Cheap, and it also corrects stale identity/contact attributes for those rows.

### 5b · Post-2023 linkage gap — upstream
The remaining 96/153 show **no in-window publications even on their current id**. RPS (the curated serving layer) inherits the same links: of 77/153 it can resolve, 68 show `lastYearAsAuthor = 2023`, and direct publication queries return zero in-window papers. Externally, OpenAlex confirms in-window publications exist (spot-checked). Some authors do carry 2024–2026 links, so ingestion is not globally dead — author→publication linking degraded from ~2023 onward for a large cohort.

RPS validation (GraphQL, `{FPP_API_GATEWAY_URL}/researcher-profile-service/graphql`):

```graphql
query($ids:[Long!]){ authors(where:{authorId:{in:$ids}}, take:200){
  totalCount items{ authorId metrics{ hindex publicationCount lastYearAsAuthor } } } }

query($d:DateTime!){ publications(
  where:{publishedDate:{gte:$d}, authors:{some:{authorId:{eq:<ID>}}}}, take:1){ totalCount } }
```

External cross-check (OpenAlex): `GET https://api.openalex.org/works?filter=author.id:<OA_ID>,from_publication_date:2023-08-19`

**Fix:** upstream repair of the AIRA author→publication linking pipeline. Until then, the Active/Productive/H-index flags **over-drop genuinely active researchers**; correcting them lifts final contactable yield only ~5–6% (most wrongly-dropped candidates fail later on email/consent anyway) — a correctness fix, not the main volume lever. The main volume lever remains contact data (email coverage, de-duplication).
