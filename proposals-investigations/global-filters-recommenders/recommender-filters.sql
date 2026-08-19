-- =====================================================================
-- recommender-filters.sql
-- Every query behind "A global permissibility filter in the recommender pipeline".
-- Read 17 Aug 2026. Billing project gcp-innovation-hub; data read cross-project.
--
-- Structure:
--   Q1  candidate -> rule flags (the one BigQuery query everything else derives from)
--   Q2  rule dictionary check
--   Q3..Q7  the aggregations, expressed as SQL over Q1's output
--   Notes on what was computed in pandas over the two delivered files, and why.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q1 — CANDIDATE RULE FLAGS.  Produces every number in the deck.
-- Input: the union of AIRA ids from both samples (17,750 distinct:
--        12,809 from the Research Topic CSV, 4,977 from the reviewer workbook,
--        36 present in both).
-- The id list is inlined as an array literal; substitute your own.
-- ---------------------------------------------------------------------
WITH ids AS (SELECT id FROM UNNEST([<AIRA_ID_LIST>]) id),
r AS (  -- ALL exclusion codes per researcher, not just the highest-priority one
  SELECT author_id, ARRAY_AGG(DISTINCT reason_code) c
  FROM `ocean-breeze-tier-2.researcher_availability.researcher_availability_status_reason`
  WHERE author_id IN (SELECT id FROM ids) GROUP BY 1),
em AS (  -- deliverable = at least one address with ValidityId IN (1,2). One definition, used everywhere.
  SELECT AuthorId, LOGICAL_OR(ValidityId IN (1,2)) hd, COUNT(*) n
  FROM `ocean-breeze-tier-1.airak.AuthorEmail`
  WHERE AuthorId IN (SELECT id FROM ids) GROUP BY 1)
SELECT i.id AS aira_id,
  a.AuthorId IS NOT NULL                                   AS in_airak,
  IFNULL(a.IsPotentialOvermerged,FALSE)                    AS om,
  (a.LastName IS NULL OR TRIM(a.LastName)='')              AS mln,
  IFNULL(a.HasAffiliation,FALSE)                           AS aff,
  IFNULL(r.c,[])                                           AS codes,
  IFNULL(em.n,0)>0                                         AS any_email,
  IFNULL(em.hd,FALSE)                                      AS has_deliverable,
  m.LastYearAsAuthor, IFNULL(m.PublicationCount,0) AS pubs, IFNULL(m.Hindex,0) AS hindex
FROM ids i
LEFT JOIN `ocean-breeze-tier-1.airak.Author`       a ON a.AuthorId = i.id
LEFT JOIN `ocean-breeze-tier-1.airak.AuthorMetric` m ON m.AuthorId = i.id
LEFT JOIN r  ON r.author_id = i.id
LEFT JOIN em ON em.AuthorId = i.id;
-- 17,750 rows. 382 (2.2%) have no row in airak.Author at all:
--   293 of Sample A's rows, 91 of Sample B's -> appendix D.

-- Rule groups derived from Q1 (same definitions in every figure):
--   cannot_reach   = NOT has_deliverable OR 'SBE' IN codes
--   identity       = om OR mln OR 'ALN' IN codes OR 'SDD' IN codes OR NOT aff
--   should_not     = 'AWL','ART','ABC','SSX','SSR','SCP' IN codes
--   not_permitted  = 'SGU','SOC','SOL' IN codes
--   should_wait    = 'SAC','SCI','SOP','SCO','SRT' IN codes        -- signal, not block
--   blocked        = cannot_reach OR identity OR should_not OR not_permitted
--   fails_any      = blocked OR should_wait

-- ---------------------------------------------------------------------
-- Q2 — the code dictionary. Confirms which framework rules have a code at all.
-- 22 codes. No code exists for out-of-office or RT-communication unsubscribe.
-- ---------------------------------------------------------------------
SELECT reason_code, reason, exclusion_grade, source_system
FROM `ocean-breeze-tier-2.researcher_availability.dim_researcher_availability_reason`
ORDER BY exclusion_priority;

-- ---------------------------------------------------------------------
-- Q3 — SECTION 5, headline per sample.  (join Q1 to the candidate list first)
-- Sample A: 12,859 rows -> blocked 8,640 (67.2%), permissible 4,219 (32.8%),
--           also clear of timing 2,000 (15.6%)
-- Sample B: 4,977 distinct -> blocked 3,154 (63.4%), permissible 1,823 (36.6%),
--           also clear of timing 1,090 (21.9%)
-- ---------------------------------------------------------------------
SELECT COUNT(*) candidates, COUNTIF(blocked) blocked, COUNTIF(NOT blocked) permissible,
       COUNTIF(NOT blocked AND NOT should_wait) clean
FROM candidates_with_flags;

-- ---------------------------------------------------------------------
-- Q4 — SECTION 5, per request. Five Research Topics / five manuscripts, named.
-- Sample A per topic (candidates -> permissible):
--   Nutrition 84467       2,751 -> 879 (32.0%)
--   Immunology 84888      2,726 -> 840 (30.8%)
--   Hematology 83880      2,652 -> 781 (29.4%)
--   Cognition 84104       2,562 -> 862 (33.6%)
--   Marine Science 84719  2,168 -> 857 (39.5%)
-- Sample B per manuscript:
--   Cognition 1928401       997 -> 488 (48.9%)   Hematology 1860699  999 -> 340 (34.0%)
--   Immunology 1888359      993 -> 288 (29.0%)   Marine 1923956      989 -> 355 (35.9%)
--   Nutrition 1908597       999 -> 352 (35.2%)
-- ---------------------------------------------------------------------
SELECT request_id, COUNT(*) candidates, COUNTIF(NOT blocked) permissible
FROM candidates_with_flags GROUP BY 1 ORDER BY 2 DESC;

-- ---------------------------------------------------------------------
-- Q5 — SECTION 4, the delivered-list analysis (Sample B only).
-- RRF Pool Rank (Pre-Ranking) comes from the workbook, not from BigQuery.
-- Pooled across the five manuscripts:
--   top 10  -> 34 / 50  (68.0%) blocked, 41 / 50 also failing a timing rule
--   top 20  -> 60 / 100 (60.0%)
--   top 50  -> 156 / 250 (62.4%)
--   top 100 -> 326 / 500 (65.2%)
--   full    -> 3,154 / 4,977 (63.4%)
-- Per manuscript, top 10: Cognition 8, Hematology 8, Immunology 7,
--   Marine Science 4, Nutrition 7.
-- ---------------------------------------------------------------------
SELECT depth, COUNT(*) candidates, COUNTIF(blocked) blocked
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY article_id ORDER BY rrf_rank) rn
      FROM candidates_with_flags), UNNEST([10,20,50,100]) depth
WHERE rn <= depth GROUP BY 1 ORDER BY 1;

-- ---------------------------------------------------------------------
-- Q6 — SECTION 6, failure composition, ordered by size. A / B:
--   cannot reach          6,120 (47.6%)  /  2,334 (46.9%)
--   should wait           3,908 (30.4%)  /  1,226 (24.6%)
--   identity not resolved 3,644 (28.3%)  /    919 (18.5%)
--   not permitted         1,168 ( 9.1%)  /    408 ( 8.2%)
--   should not contact      955 ( 7.4%)  /    375 ( 7.5%)
-- Blocked on email alone: 3,379 (26.3%) / 1,584 (31.8%)
-- Fail exactly one group:  6,676 (51.9%) / 2,717 (54.6%)
-- Blocked only by irreversible rules: 967 (7.5%) / 384 (7.7%)
-- ---------------------------------------------------------------------
SELECT COUNTIF(cannot_reach) cannot_reach, COUNTIF(identity) identity,
       COUNTIF(should_not) should_not, COUNTIF(not_permitted) not_permitted,
       COUNTIF(should_wait) should_wait,
       COUNTIF(cannot_reach AND NOT identity AND NOT should_not
               AND NOT not_permitted AND NOT should_wait) email_only
FROM candidates_with_flags;

-- ---------------------------------------------------------------------
-- Q7 — SECTION 7, channel attribution. Channel comes from the sample files
-- (in_profiles / in_publications in Sample A; "Channels Found In" in Sample B).
-- Over-merge rate, profiles vs publications channel:
--   Sample A 1.6% vs 11.8% · Sample B 0.8% vs 12.6%
-- No affiliation:      A 6.5% vs 16.6% · B 4.6% vs 8.9%
-- No email on file:    A 36.5% vs 38.0% · B 40.9% vs 32.5%
-- Consent block:       A 6.6% vs 10.5% · B 4.8% vs 11.5%
-- ---------------------------------------------------------------------
SELECT channel, COUNT(*) n, COUNTIF(om) overmerged, COUNTIF(NOT aff) no_affiliation,
       COUNTIF(NOT any_email) no_email, COUNTIF(not_permitted) consent_block, COUNTIF(blocked) blocked
FROM candidates_with_flags GROUP BY 1;

-- ---------------------------------------------------------------------
-- NOT SQL, and why
-- ---------------------------------------------------------------------
-- The two samples arrived as a CSV and an XLSX, so the candidate side of every
-- join was done in pandas: read the files, dedupe (Sample A keeps candidate x topic
-- rows, Sample B dedupes within each manuscript), left-join Q1's output on aira_id,
-- then aggregate. No candidate was dropped by the join: every id appears in Q1's
-- output, and ids with no airak.Author row are carried through as in_airak = FALSE.
--
-- The AI expertise profile funnel (segment loader -> augmentation exclusion ->
-- expertise LLM -> merge -> facts -> embeddings) is NOT in BigQuery. It runs on
-- Databricks and writes Spark tables in that catalog. The exclusion logic was read
-- from frontiersin/researchers-profile-generation at HEAD:
--   02.01_augment_data.py           -- exclusion flags, h-index rules disabled
--   segments/01.00_get_segment_data.py -- am.PublicationCount >= 3 in 10 of 12 segments
--   researcher-profile-embeddings/01_extract_facts_for_embeddings.py, 02_embed_facts.py
-- Volumes for those stages need a Databricks connection.
