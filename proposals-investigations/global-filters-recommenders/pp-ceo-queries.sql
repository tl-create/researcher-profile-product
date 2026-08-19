-- =====================================================================
-- Perfect Profile — CEO summary: every number on the page
-- Snapshot: AIRAK airak_version = 2026-08-05 (RPS in sync with it)
-- Owner: Tzu-i Liao
--
-- Source policy: RPS (Research Profile Service) is the source of record for
-- the population definitions. Every RPS-computable figure below was verified
-- against BigQuery and matches exactly. BigQuery is used where RPS cannot
-- serve the query: the AI-enrichment join (times out server-side at
-- population scale), the multi-bar combinatorics, and the sub-reason splits.
--
-- Reason codes (ocean-breeze-tier-2.researcher_availability):
--   AWL watchlisted · ART integrity retractions · ABC banned country
--   ALN no last name · ANA no affiliation · SDD duplicate Salesforce record
--   ANV no verified email (UNRELIABLE — see note 3) · SBE bounced
--   SGU globally unsubscribed · SOC opted out of contact · SOL opted out of lead comms
-- =====================================================================


-- =====================================================================
-- PART A — RPS (GraphQL). POST {FPP_API_GATEWAY_URL}/researcher-profile-service/graphql
--          Authorization: Bearer {FPP_API_ACCESS_TOKEN}
--          Every count uses take:1 and reads totalCount only.
-- =====================================================================
/*
-- A0. Universe — 151,500,870
query { authors(take: 1) { totalCount } }

-- A1. Single rules (Universe-wide)
--     active     42,707,994   productive 21,933,562
--     credible   87,755,054   affiliated 64,231,160
query ($w: AuthorEntityFilterInput) { authors(where: $w, take: 1) { totalCount } }
  active     { "metrics": { "lastYearAsAuthor": { "gte": 2023 } } }
  productive { "metrics": { "publicationCount":  { "gte": 3    } } }
  credible   { "metrics": { "hindex":            { "gte": 1    } } }
  affiliated { "hasAffiliation": { "eq": true } }
  -- hasAffiliation is identical to organizations:{some:{currentOrganization:{eq:true}}} (both 64,231,160)

-- A2. Stage 1 — activity & quality, all four — 9,741,993
{ "and": [
    { "metrics": { "lastYearAsAuthor": { "gte": 2023 } } },
    { "metrics": { "publicationCount":  { "gte": 3    } } },
    { "metrics": { "hindex":            { "gte": 1    } } },
    { "hasAffiliation": { "eq": true } } ] }

-- A3. Core eligibility, measured as the FAILING side — 958,811
--     ("not excluded" cannot be expressed directly: the exclusion object is
--      absent for clean authors, so eq:false matches nobody. statusReasons
--      does support none:, which is null-safe — both routes agree.)
{ "and": [ ...A2..., { "availabilityInfo": { "statusReasons": { "some": {
      "reasonCode": { "in": ["AWL","ART","ABC"] } } } } } ] }
-- cross-check via the AIRAK exclusion flags, same 958,811:
{ "and": [ ...A2..., { "exclusion": { "isAuthorExcluded": { "eq": true } } } ] }

--     Active = A2 − A3 = 9,741,993 − 958,811 = 8,783,182

-- A4. Email coverage inside Stage 1 — 5,206,991 have a usable address
{ "and": [ ...A2..., { "emails": { "some": { "validityId": { "in": [1,2] } } } } ] }
--     validityId 1 = valid, 2 = safeToSend, 3 = invalid, 4 = unknown
--     identical to { "hasVerifiedEmail": { "eq": true } }

-- A5. Taxonomy mapping inside Stage 1 (PARKED — not in the headline)
{ "and": [ ...A2..., { "closestFrontiersJournalRanks": { "any": true } } ] }  -- 3,659,137
{ "and": [ ...A2..., { "closestFrontiersSectionRanks": { "any": true } } ] }  -- 3,640,446
--     RPS exposes only mappings with Confidence >= 0.7; the AIRAK table holds
--     8,278,423 for the same cohort at any confidence. Threshold decision pending.

-- NOT AVAILABLE IN RPS: aiEnhancedProfile predicates time out at population
-- scale (HC0045, 30s server cap) on every field tried. Use PART B.
*/


-- =====================================================================
-- PART B — BigQuery. Billing project: gcp-innovation-hub
-- =====================================================================

-- ---------------------------------------------------------------------
-- B1. Reusable cohort. Every figure in sections 02–06 comes from this CTE
--     block. Each section query below is written to run standalone: paste
--     this whole block (down to the end of `cohort`) above it where marked
--     /* B1 */.
-- ---------------------------------------------------------------------
WITH reasons AS (
  SELECT author_id, ARRAY_AGG(DISTINCT reason_code) AS codes
  FROM `ocean-breeze-tier-2.researcher_availability.researcher_availability_status_reason`
  GROUP BY author_id
),
emails AS (
  SELECT AuthorId,
         COUNT(*) AS n_emails,
         LOGICAL_OR(ValidityId IN (1,2)) AS has_deliverable   -- 1 valid, 2 safeToSend
  FROM `ocean-breeze-tier-1.airak.AuthorEmail`
  GROUP BY AuthorId
),
jr AS (  -- taxonomy mapping at the confidence RPS actually serves
  SELECT DISTINCT AuthorId FROM `ocean-breeze-tier-1.airak.AuthorClosestFrontiersJournalRank`
  WHERE Confidence >= 0.7
),
sr AS (
  SELECT DISTINCT AuthorId FROM `ocean-breeze-tier-1.airak.AuthorClosestFrontiersSectionRank`
  WHERE Confidence >= 0.7
),
base AS (
  SELECT
    a.AuthorId,
    -- Stage 1: activity & quality
    IFNULL(m.LastYearAsAuthor >= 2023, FALSE)   AS is_active,
    IFNULL(m.LastYearAsAuthor >= 2024, FALSE)   AS is_active_2024,   -- June-style recency, for B5
    IFNULL(m.PublicationCount, 0)               AS pub_count,
    IFNULL(m.PublicationCount, 0) >= 3          AS is_productive,
    IFNULL(m.Hindex, 0) >= 1                    AS is_credible,
    IFNULL(a.HasAffiliation, FALSE)             AS is_affiliated,
    -- identity
    IFNULL(a.IsPotentialOvermerged, FALSE)      AS is_overmerged,
    (a.LastName IS NULL OR TRIM(a.LastName) = '') AS missing_lastname,
    -- supply
    ai.aira_id IS NOT NULL                      AS has_ai,
    IFNULL(e.n_emails, 0) > 0                   AS has_any_email,
    IFNULL(e.has_deliverable, FALSE)            AS has_deliverable,
    jr.AuthorId IS NOT NULL                     AS map_journal,
    sr.AuthorId IS NOT NULL                     AS map_section,
    IFNULL(r.codes, []) AS codes
  FROM `ocean-breeze-tier-1.airak.Author` a
  LEFT JOIN `ocean-breeze-tier-1.airak.AuthorMetric` m USING (AuthorId)
  LEFT JOIN reasons r ON r.author_id = a.AuthorId
  LEFT JOIN `ocean-breeze-tier-1.ai_enhanced_profile.enhanced_profiles_validated` ai
         ON ai.aira_id = a.AuthorId
  LEFT JOIN emails e USING (AuthorId)
  LEFT JOIN jr USING (AuthorId)
  LEFT JOIN sr USING (AuthorId)
),
cohort AS (
  SELECT *,
    (is_active AND is_productive AND is_credible AND is_affiliated) AS stage1,
    ('AWL' IN UNNEST(codes)) AS r_watchlist,
    ('ART' IN UNNEST(codes)) AS r_retraction,
    ('ABC' IN UNNEST(codes)) AS r_country,
    ('ALN' IN UNNEST(codes)) AS r_nolastname,
    ('ANA' IN UNNEST(codes)) AS r_noaffil,
    ('SDD' IN UNNEST(codes)) AS r_dupsf,
    ('SBE' IN UNNEST(codes)) AS r_bounced,
    ('SGU' IN UNNEST(codes)) AS r_gunsub,
    ('SOC' IN UNNEST(codes)) AS r_optout,
    ('SOL' IN UNNEST(codes)) AS r_optoutlead
  FROM base
)

-- ---------------------------------------------------------------------
-- B2. SECTION 02 — the top funnel (sequential cascade)
--     151,500,870 → 42,707,994 → 11,644,565 → 10,783,207 → 9,741,993
--                 → 9,728,681 → 9,636,095 → 8,783,182
-- ---------------------------------------------------------------------
SELECT
  COUNT(*)                                                                       AS s0_universe,
  COUNTIF(is_active)                                                             AS s1_active,
  COUNTIF(is_active AND is_productive)                                           AS s2_productive,
  COUNTIF(is_active AND is_productive AND is_credible)                           AS s3_credible,
  COUNTIF(stage1)                                                                AS s4_affiliated,
  COUNTIF(stage1 AND NOT r_watchlist)                                            AS s5_not_watchlisted,
  COUNTIF(stage1 AND NOT r_watchlist AND NOT r_retraction)                       AS s6_no_retractions,
  COUNTIF(stage1 AND NOT r_watchlist AND NOT r_retraction AND NOT r_country)     AS s7_target_audience,
  -- SECTION 03 — order-free view: fails exactly one Stage 1 rule
  COUNTIF(NOT is_active AND is_productive AND is_credible AND is_affiliated)     AS only_inactive,      -- 7,706,653
  COUNTIF(is_active AND NOT is_productive AND is_credible AND is_affiliated)     AS only_unproductive,  -- 6,541,129
  COUNTIF(is_active AND is_productive AND is_credible AND NOT is_affiliated)     AS only_unaffiliated,  -- 1,041,214
  COUNTIF(is_active AND is_productive AND NOT is_credible AND is_affiliated)     AS only_nocredible,    --   381,999
  COUNTIF(NOT is_active)                                                         AS fails_active_at_all,
  COUNTIF(NOT is_productive)                                                     AS fails_productive_at_all,
  COUNTIF(NOT is_affiliated)                                                     AS fails_affiliated_at_all,
  COUNTIF(NOT is_credible)                                                       AS fails_credible_at_all,
  -- SECTION 04 — eligibility rules measured independently inside Stage 1
  COUNTIF(stage1 AND r_country)                                                  AS elig_country,      -- 865,337
  COUNTIF(stage1 AND r_retraction)                                               AS elig_retraction,   --  95,546
  COUNTIF(stage1 AND r_watchlist)                                                AS elig_watchlist,    --  13,312
  COUNTIF(stage1 AND (r_watchlist OR r_retraction OR r_country))                 AS elig_any           -- 958,811
FROM cohort;


-- ---------------------------------------------------------------------
-- B3. SECTION 05 — the three measured bars against the Active
--     Mapped is computed but deliberately excluded from perfect_profile.
-- ---------------------------------------------------------------------
/* B1 */
, ta AS (
  SELECT *,
    NOT (is_overmerged OR missing_lastname OR r_nolastname OR r_noaffil OR r_dupsf) AS bar_profiled,
    has_ai AS bar_ai,
    (has_deliverable
      AND NOT r_bounced
      AND NOT (r_gunsub OR r_optout OR r_optoutlead))                                AS bar_contactable,
    (map_journal AND map_section)                                                    AS bar_mapped_parked
  FROM cohort
  WHERE stage1 AND NOT (r_watchlist OR r_retraction OR r_country)
)
SELECT
  COUNT(*)                                                       AS target_audience,   -- 8,783,182
  COUNTIF(bar_profiled)                                          AS profiled,          -- 7,872,150
  COUNTIF(bar_ai)                                                AS ai_enriched,       -- 5,761,659
  COUNTIF(bar_contactable)                                       AS contactable,       -- 4,194,036
  COUNTIF(bar_profiled AND bar_ai AND bar_contactable)           AS perfect_profile,   -- 2,849,445
  -- binding bar: clears everything except one
  COUNTIF(bar_profiled AND bar_ai AND NOT bar_contactable)       AS blocked_only_email,-- 2,699,519
  COUNTIF(bar_profiled AND NOT bar_ai AND bar_contactable)       AS blocked_only_ai,   --   915,536
  COUNTIF(NOT bar_profiled AND bar_ai AND bar_contactable)       AS blocked_only_id,   --   140,456
  -- how many bars are missing
  COUNTIF(CAST(NOT bar_profiled AS INT64)+CAST(NOT bar_ai AS INT64)+CAST(NOT bar_contactable AS INT64)=0) AS missing0,
  COUNTIF(CAST(NOT bar_profiled AS INT64)+CAST(NOT bar_ai AS INT64)+CAST(NOT bar_contactable AS INT64)=1) AS missing1,
  COUNTIF(CAST(NOT bar_profiled AS INT64)+CAST(NOT bar_ai AS INT64)+CAST(NOT bar_contactable AS INT64)=2) AS missing2,
  COUNTIF(CAST(NOT bar_profiled AS INT64)+CAST(NOT bar_ai AS INT64)+CAST(NOT bar_contactable AS INT64)=3) AS missing3,
  -- sub-reasons (the blockers table)
  COUNTIF(NOT has_any_email)                                     AS sub_no_email_on_file,      -- 3,747,233
  COUNTIF(NOT has_ai)                                            AS sub_no_ai_profile,         -- 3,021,523
  COUNTIF(is_overmerged)                                         AS sub_overmerged,            --   726,234
  COUNTIF(r_bounced)                                             AS sub_bounced,               --   332,941
  COUNTIF(has_any_email AND NOT has_deliverable)                 AS sub_email_not_deliverable, --   292,221
  COUNTIF(r_dupsf)                                               AS sub_duplicate_salesforce,  --   251,516
  COUNTIF(r_gunsub)                                              AS sub_globally_unsubscribed, --   239,633
  COUNTIF(r_optout)                                              AS sub_opted_out,             --   208,849
  COUNTIF(r_optoutlead)                                          AS sub_opted_out_lead,        --    95,757
  COUNTIF(missing_lastname OR r_nolastname)                      AS sub_no_last_name,          --     7,988
  COUNTIF(r_noaffil)                                             AS sub_no_affiliation,        --         0 by construction
  -- parked Mapped bar, for the threshold decision only
  COUNTIF(map_journal)                                           AS mapped_journal_conf07,     -- 3,272,416
  COUNTIF(map_section)                                           AS mapped_section_conf07,     -- 3,228,609
  COUNTIF(bar_mapped_parked)                                     AS mapped_both_conf07,        -- 1,925,199
  COUNTIF(bar_profiled AND bar_ai AND bar_contactable AND bar_mapped_parked) AS pp_incl_mapped  --   690,711
FROM ta;


-- ---------------------------------------------------------------------
-- B4. SECTION 03 — cost of the productivity rule
--     >=3 (current): 8,783,182 · >=2: 10,589,699 (+1,806,517) · no rule: 14,830,085 (+6,046,903)
-- ---------------------------------------------------------------------
/* B1 */
SELECT
  COUNTIF(eligible AND pub_count >= 3) AS ta_pubs_ge3,
  COUNTIF(eligible AND pub_count >= 2) AS ta_pubs_ge2,
  COUNTIF(eligible)                    AS ta_no_productivity_rule
FROM (
  SELECT pub_count,
         (is_active AND is_credible AND is_affiliated
            AND NOT (r_watchlist OR r_retraction OR r_country)) AS eligible
  FROM cohort
);


-- ---------------------------------------------------------------------
-- B5. SECTION 06 — reconciliation with the June pack
--     June-style rule set: 2024+ recency, no productivity rule.
--     Rebuilt today: Active 12,421,948 (June: 12,363,128, +0.5%)
--                    Perfect Profile  2,637,322 = 21.2% (June: 2,929,573 = 23.7%)
-- ---------------------------------------------------------------------
/* B1 */
SELECT
  COUNTIF(june_ta)                                                            AS june_style_target_audience,
  COUNTIF(june_ta AND bar_profiled AND bar_ai AND bar_contactable)            AS june_style_perfect_profile
FROM (
  SELECT
    (is_active_2024 AND is_credible AND is_affiliated
       AND NOT (r_watchlist OR r_retraction OR r_country))                    AS june_ta,
    NOT (is_overmerged OR missing_lastname OR r_nolastname OR r_noaffil OR r_dupsf) AS bar_profiled,
    has_ai AS bar_ai,
    (has_deliverable AND NOT r_bounced AND NOT (r_gunsub OR r_optout OR r_optoutlead)) AS bar_contactable
  FROM cohort
);


-- ---------------------------------------------------------------------
-- B6. Held for the next iteration — Research Topic contributor use case
--     RTC invitations, space 1, 2025-08-01 → 2026-07-31:
--       2,124,581 invitations · 1,192,356 distinct invitees with an AIRA ID
--       986,104 in the Active (82.7%) · 580,022 with a Perfect Profile
--       Coverage 58.8%. Stage 3 (profile actually used) is not tracked.
-- ---------------------------------------------------------------------
-- SELECT COUNT(DISTINCT researcher_invitation_id)      AS invitations,
--        COUNT(DISTINCT invitee_aira_researcher_id)    AS invitees
-- FROM `ocean-breeze-tier-2.researcher_invitations.invitation_enriched`
-- WHERE space_id = 1
--   AND invitation_source_key = 'RTC'
--   AND invitation_date >= TIMESTAMP '2025-08-01'
--   AND invitation_date <  TIMESTAMP '2026-08-01';




-- =====================================================================
-- B7. SECTION 3 (v2) — THE FOUR BARS, all against Active.
--     Parallel, not a chain. Mapped included; Contactable split T1/T3.
--     Requires the B1 cohort block above (it already carries map_journal /
--     map_section at Confidence >= 0.7).
-- ---------------------------------------------------------------------
/* B1 */
, ta4 AS (
  SELECT *,
    NOT (is_overmerged OR missing_lastname OR r_nolastname OR r_noaffil OR r_dupsf) AS bar_profiled,
    has_ai                                                        AS bar_ai,
    (has_deliverable AND NOT r_bounced)                           AS t3_email_ok,
    NOT (r_gunsub OR r_optout OR r_optoutlead)                    AS t1_consent_ok,
    (has_deliverable AND NOT r_bounced
       AND NOT (r_gunsub OR r_optout OR r_optoutlead))            AS bar_contactable,
    (map_journal AND map_section)                                 AS bar_mapped
  FROM cohort
  WHERE stage1 AND NOT (r_watchlist OR r_retraction OR r_country)
)
SELECT
  COUNT(*)                                                        AS target_audience,   -- 8,783,182
  -- the four bars
  COUNTIF(bar_profiled)                                           AS profiled,          -- 7,872,150  89.6%
  COUNTIF(bar_ai)                                                 AS ai_enriched,       -- 5,761,659  65.6%
  COUNTIF(bar_contactable)                                        AS contactable,       -- 4,194,036  47.7%
  COUNTIF(bar_mapped)                                             AS mapped,            -- 1,925,199  21.9%
  -- Contactable shown as TWO numbers (hard constraint 4)
  COUNTIF(t1_consent_ok)                                          AS t1_consent_ok,     -- 8,498,375  96.8%
  COUNTIF(t3_email_ok)                                            AS t3_email_ok,       -- 4,457,542  50.7%
  COUNTIF(t3_email_ok AND NOT t1_consent_ok)                      AS lost_consent_only,  --   263,506
  COUNTIF(NOT t3_email_ok AND t1_consent_ok)                      AS lost_email_only,    -- 4,304,339
  COUNTIF(NOT t3_email_ok AND NOT t1_consent_ok)                  AS lost_both,          --    21,301
  -- Perfect Profile
  COUNTIF(bar_profiled AND bar_ai AND bar_contactable AND bar_mapped) AS perfect_profile,      --  690,711  7.9%
  COUNTIF(bar_profiled AND bar_ai AND bar_contactable)                AS perfect_profile_x_map,-- 2,849,445 32.4%
  -- which bar is binding: blocked by exactly one bar
  COUNTIF(NOT bar_profiled AND bar_ai AND bar_contactable AND bar_mapped)     AS only_profiled,    --    41,686
  COUNTIF(bar_profiled AND NOT bar_ai AND bar_contactable AND bar_mapped)     AS only_ai,          --   202,994
  COUNTIF(bar_profiled AND bar_ai AND NOT bar_contactable AND bar_mapped)     AS only_contactable, --   563,166
  COUNTIF(bar_profiled AND bar_ai AND bar_contactable AND NOT bar_mapped)     AS only_mapped,      -- 2,158,734
  -- of the Contactable-only group, how much is fixable (T3) vs permanent (T1)
  COUNTIF(bar_profiled AND bar_ai AND bar_mapped AND NOT bar_contactable AND NOT t3_email_ok) AS only_cont_email,   -- 513,111
  COUNTIF(bar_profiled AND bar_ai AND bar_mapped AND NOT bar_contactable AND t3_email_ok
          AND NOT t1_consent_ok)                                                              AS only_cont_consent, --  50,055
  -- distribution of failing bars (0-4)
  COUNTIF(CAST(NOT bar_profiled AS INT64)+CAST(NOT bar_ai AS INT64)+CAST(NOT bar_contactable AS INT64)+CAST(NOT bar_mapped AS INT64)=0) AS fail0, --   690,711
  COUNTIF(CAST(NOT bar_profiled AS INT64)+CAST(NOT bar_ai AS INT64)+CAST(NOT bar_contactable AS INT64)+CAST(NOT bar_mapped AS INT64)=1) AS fail1, -- 2,966,580
  COUNTIF(CAST(NOT bar_profiled AS INT64)+CAST(NOT bar_ai AS INT64)+CAST(NOT bar_contactable AS INT64)+CAST(NOT bar_mapped AS INT64)=2) AS fail2, -- 3,293,731
  COUNTIF(CAST(NOT bar_profiled AS INT64)+CAST(NOT bar_ai AS INT64)+CAST(NOT bar_contactable AS INT64)+CAST(NOT bar_mapped AS INT64)=3) AS fail3, -- 1,502,998
  COUNTIF(CAST(NOT bar_profiled AS INT64)+CAST(NOT bar_ai AS INT64)+CAST(NOT bar_contactable AS INT64)+CAST(NOT bar_mapped AS INT64)=4) AS fail4, --   329,162
  -- Tier 4 sub-reasons (Profiled drawer)
  COUNTIF(is_overmerged)                                          AS t4_overmerged,     -- 726,234
  COUNTIF(r_dupsf)                                                AS t4_duplicate_sfid, -- 251,516
  COUNTIF(missing_lastname OR r_nolastname)                       AS t4_no_lastname,    --   7,988
  COUNTIF(r_noaffil)                                              AS t4_no_affiliation, --       0 (scope criterion)
  COUNTIF(NOT bar_profiled)                                       AS t4_total_in_ta,    -- 911,032
  -- Tier 3 sub-reasons (fixable)
  COUNTIF(NOT has_any_email)                                      AS t3_no_email,       -- 3,747,233
  COUNTIF(r_bounced)                                              AS t3_bounced,        --   332,941
  COUNTIF(has_any_email AND NOT has_deliverable)                  AS t3_not_deliverable,--   292,221
  -- Tier 1 sub-reasons (irreversible)
  COUNTIF(r_gunsub)                                               AS t1_globally_unsub, --   239,633
  COUNTIF(r_optout)                                               AS t1_optout_contact, --   208,849
  COUNTIF(r_optoutlead)                                           AS t1_optout_lead,    --    95,757
  -- Mapped detail (threshold decision)
  COUNTIF(map_journal)                                            AS mapped_journal,    -- 3,272,416
  COUNTIF(map_section)                                            AS mapped_section,    -- 3,228,609
  COUNTIF(NOT bar_ai)                                             AS ai_missing         -- 3,021,523
FROM ta4;


-- ---------------------------------------------------------------------
-- B8. SECTION 4 (v2) — RT contributor invitation funnel, end to end.
--     Space 1, RTC journey, 2025-08-01 → 2026-07-31.
--       1 invite list           1,192,356 distinct researchers (+67,247 unresolved)
--       2 in Active      986,104   82.7% of (1)
--       3 has Perfect Profile     158,503   Coverage 16.1% of (2); 580,022 / 58.8% excluding Mapped
--       4 profile actually used   NOT TRACKED — no instrumentation exists
--     Usage (4÷3) and Adoption (4÷1) are therefore not reportable.
-- ---------------------------------------------------------------------
/* B1 + the ta4 bar definitions above */
WITH inv AS (
  SELECT DISTINCT invitee_aira_researcher_id AS aira_id
  FROM `ocean-breeze-tier-2.researcher_invitations.invitation_enriched`
  WHERE space_id = 1
    AND invitation_source_key = 'RTC'
    AND invitation_date >= TIMESTAMP '2025-08-01'
    AND invitation_date <  TIMESTAMP '2026-08-01'
    AND invitee_aira_researcher_id IS NOT NULL
)
SELECT
  (SELECT COUNT(DISTINCT researcher_invitation_id)
     FROM `ocean-breeze-tier-2.researcher_invitations.invitation_enriched`
    WHERE space_id = 1 AND invitation_source_key = 'RTC'
      AND invitation_date >= TIMESTAMP '2025-08-01'
      AND invitation_date <  TIMESTAMP '2026-08-01')                     AS invitations,      -- 2,124,581
  COUNT(*)                                                               AS stage1_invitees,  -- 1,192,356
  COUNTIF(t.AuthorId IS NOT NULL)                                        AS stage2_in_ta,     --   986,104
  COUNTIF(t.bar_profiled AND t.bar_ai AND t.bar_contactable AND t.bar_mapped) AS stage3_pp,   --   158,503
  COUNTIF(t.bar_profiled AND t.bar_ai AND t.bar_contactable)             AS stage3_pp_x_map   --   580,022
FROM inv LEFT JOIN ta4 t ON t.AuthorId = inv.aira_id;


-- ---------------------------------------------------------------------
-- B9. SECTION 5 — reconciliation against previously presented figures.
--     Base "active + h-index >= 1": 2023+ = 22,759,036 · 2022+ = 26,914,715
--     (the 26.0M quoted earlier corresponds to the 2022+ window).
--     Against the 2023+ base: T1 330,942 (1.45%) · T2 core 1,457,499 (6.40%)
--                             T3 16,748,581 (73.59%) · T4 7,683,178 (33.76%)
-- ---------------------------------------------------------------------
/* B1 */
SELECT
  COUNTIF(is_active AND is_credible)                                                       AS base_2023,
  COUNTIF(is_active AND is_credible AND (r_gunsub OR r_optout OR r_optoutlead))            AS tier1_legal,
  COUNTIF(is_active AND is_credible AND (r_watchlist OR r_retraction OR r_country))        AS tier2_core,
  COUNTIF(is_active AND is_credible AND (NOT has_deliverable OR r_bounced))                AS tier3_email,
  COUNTIF(is_active AND is_credible AND (is_overmerged OR missing_lastname OR r_nolastname
                                         OR r_dupsf OR NOT is_affiliated))                 AS tier4_identity
FROM cohort;


-- =====================================================================
-- CONSISTENCY CHECKS RUN BEFORE PUBLISHING (hard constraint 6)
--   fail0..fail4 sum to Active:
--     690,711 + 2,966,580 + 3,293,731 + 1,502,998 + 329,162 = 8,783,182   OK
--   the four blocked-by-one-bar counts sum to fail1:
--     41,686 + 202,994 + 563,166 + 2,158,734 = 2,966,580                  OK
--   Contactable reconciles to TA less the three loss buckets:
--     8,783,182 − 263,506 − 4,304,339 − 21,301 = 4,194,036                OK
--   scope funnel closes:
--     151,500,870 − 141,758,877 = 9,741,993 ; 9,741,993 − 958,811 = 8,783,182  OK
--   RT funnel closes: 986,104 in TA + 206,252 out of scope = 1,192,356    OK
-- =====================================================================



-- =====================================================================
-- V2 (current deck) — ORDER SWAPPED and AFFILIATION REMOVED FROM SCOPE
--   Funnel is now: Universe -> Eligible -> Activity & quality -> TA
--   Activity & quality = active (2023+) AND productive (>=3) AND credible (h>=1).
--   Affiliation is NOT a scope criterion; it is a Tier 4 rule inside the
--   Profiled bar (measured as airak.Author.HasAffiliation = false).
--
--   Universe                                    151,500,870
--    - watchlist / retractions / country          4,483,142   (2.96% of Universe)
--   = Eligible                                  147,017,728
--    - fails active / productive / credible     137,195,631   (93.32% of Eligible)
--   = Active                             9,822,097   (6.48% of Universe)
--
--   Individual cuts: country 4,295,408 · retractions 180,445 · watchlist 27,529
--                    not productive 126,511,822 · not active 106,476,561 · h-index 0 62,473,892
--   Fails exactly one A&Q rule (within Eligible): productivity 11,479,440 ·
--                    recency 9,039,945 · h-index 801,972
--   Productivity lever: >=3 -> 9,822,097 · >=2 -> 12,361,917 (+2,539,820) ·
--                    no rule -> 21,301,537 (+11,479,440)
--
--   Bars against TA 9,822,097:
--     Profiled 7,872,150 (80.2%) · AI-enriched 5,912,430 (60.2%)
--     Contactable 4,380,600 (44.6%) = T1 consent 9,535,894 (97.1%) x T3 email 4,645,407 (47.3%)
--     Mapped 2,168,123 (22.1%) · Perfect Profile 690,711 (7.0%); excl Mapped 2,849,445 (29.0%)
--   Binding: Mapped only 2,158,734 · Contactable only 563,166 (91% email-driven)
--            AI only 202,994 · Profiled only 51,615
--   Failing bars 0-4: 690,711 / 2,976,509 / 3,385,149 / 1,870,634 / 899,094 = 9,822,097  OK
--   Tier 4 inside TA 1,949,947 (19.9%): no affiliation 1,038,915 · over-merged 742,491 ·
--            duplicate SF id 252,381 · no last name 53,467
--
--   NOTE ON ORDER: eligibility removes 4,483,142 applied to the Universe and
--   958,811 applied after activity & quality. The 3,524,331 difference is people
--   who fail both. Percentages from the earlier activity-first ordering are NOT
--   comparable to the ones above.
--
--   To reproduce: take the B1 cohort block and change two things --
--     1) drop is_affiliated from the stage1 predicate;
--     2) add NOT is_affiliated to the bar_profiled failure list.
-- =====================================================================


-- =====================================================================
-- V3 (current deck) — SINGLE TIER-ORDERED FUNNEL. Supersedes V2.
--   Universe -> Identifiable (Tier 4) -> Eligible (Tier 2) -> Contactable (Tier 1 + 3)
--   Research activity (recency / productivity / h-index) is NOT applied:
--   it is not a tier rule. Reported as context only on the final stage.
--
--   Universe                                    151,500,870
--    - Tier 4 identity                           88,702,007  (58.53% of Universe)
--   = Identifiable                               62,798,863
--    - Tier 2 business & ethical                  4,367,812  ( 6.96% of Identifiable)
--   = Eligible                                   58,431,051
--    - Tier 1 consent + Tier 3 email             51,050,931  (87.37% of Eligible)
--   = Contactable                                 7,380,120  ( 4.87% of Universe)
--        of which active+productive+credible      3,764,450
--
--   Cut 1 (base Universe):     no affiliation 87,269,710 · no last name 1,687,698 ·
--                              over-merged 1,124,075 · duplicate SF id 295,959
--   Cut 2 (base Identifiable):      country 4,229,245 · retractions 133,193 · watchlist 20,642 ·
--                              SPP restricted 1,516 · competitor 175 · SPP exclusive 146
--   Cut 3 (base Eligible):     T3 no email 49,432,073 · none deliverable 959,361 ·
--                              bounced 438,696 -> T3 subtotal 50,711,850
--                              T1 globally unsub 319,403 · opt-out contact 278,457 ·
--                              opt-out lead 110,550 -> T1 subtotal 368,429
--                              T1/T3 overlap 29,348
--
--   NOT APPLIED — no data exists:
--     Tier 1 "unsubscribed for RT communication"  no suppression code
--     Tier 2 "deceased" / Tier 6 "retired"        airak.Author.IsDeceased and
--                                                 IsRetired are empty on all
--                                                 151,500,870 rows
--     Tier 2 "marked OOO in DEO/MyFrontiers"      not in BigQuery at all: no code in
--                                                 dim_researcher_availability_reason (22 codes) and
--                                                 person.user_status has no OOO state. Deck shows the
--                                                 DEO screen count instead: 938 CURRENT EDITORIAL ROLES
--                                                 (roles, not people), read from DEO 2026-08-13. Not
--                                                 deducted from any cut — different system, different base.
-- ---------------------------------------------------------------------
WITH r AS (
  SELECT author_id, ARRAY_AGG(DISTINCT reason_code) c
  FROM `ocean-breeze-tier-2.researcher_availability.researcher_availability_status_reason`
  GROUP BY 1),
em AS (
  SELECT AuthorId, LOGICAL_OR(ValidityId IN (1,2)) hd, COUNT(*) n
  FROM `ocean-breeze-tier-1.airak.AuthorEmail` GROUP BY 1),
z AS (
  SELECT a.AuthorId,
    IFNULL(a.IsPotentialOvermerged,FALSE) om,
    (a.LastName IS NULL OR TRIM(a.LastName)='') mln,
    IFNULL(a.HasAffiliation,FALSE) aff,
    IFNULL(r.c,[]) c,
    IFNULL(em.n,0)>0 any_email, IFNULL(em.hd,FALSE) hd,
    IFNULL(m.LastYearAsAuthor>=2023,FALSE) act,
    IFNULL(m.PublicationCount,0)>=3 prod,
    IFNULL(m.Hindex,0)>=1 cred
  FROM `ocean-breeze-tier-1.airak.Author` a
  LEFT JOIN `ocean-breeze-tier-1.airak.AuthorMetric` m USING (AuthorId)
  LEFT JOIN r ON r.author_id=a.AuthorId
  LEFT JOIN em USING (AuthorId)),
y AS (
  SELECT *,
    (om OR mln OR 'ALN' IN UNNEST(c) OR 'SDD' IN UNNEST(c) OR NOT aff)              AS t4,
    ('AWL' IN UNNEST(c) OR 'ART' IN UNNEST(c) OR 'ABC' IN UNNEST(c)
       OR 'SSX' IN UNNEST(c) OR 'SSR' IN UNNEST(c) OR 'SCP' IN UNNEST(c))           AS t2,
    ('SGU' IN UNNEST(c) OR 'SOC' IN UNNEST(c) OR 'SOL' IN UNNEST(c))                AS t1,
    (NOT hd OR 'SBE' IN UNNEST(c))                                                  AS t3
  FROM z)
SELECT
  COUNT(*)                                                        AS universe,
  COUNTIF(NOT t4)                                                 AS identifiable,
  COUNTIF(NOT t4 AND NOT t2)                                      AS eligible,
  COUNTIF(NOT t4 AND NOT t2 AND NOT t1 AND NOT t3)                AS contactable,
  COUNTIF(NOT t4 AND NOT t2 AND NOT t1 AND NOT t3
          AND act AND prod AND cred)                              AS contactable_and_active
FROM y;


-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
-- V3 — OVERVIEW TAB (main funnel).
--   Universe -> Active -> Eligible -> Identifiable -> Contactable
--   "Active + Eligible" together = the TARGET AUDIENCE; Identifiable and Contactable
--   are data-quality gates. Run on the 2026-08-14 AIRAK load.
--
--   ACTIVE is a TRUE ROLLING 36-MONTH WINDOW, not the LastYearAsAuthor year field.
--   A researcher is active if they have a publication whose PublishedDate falls in
--   the last 36 months (from CURRENT_DATE). This matches the definition used by the
--   Perfect Profile coverage dashboard (its "Active" alone = ~37.5M; our rolling
--   active set on this load = 37,975,102). The old year-based test (>=2023) kept
--   10,809,345 at the Active stage; the rolling window keeps 10,147,946.
--
--     CREATE TEMP TABLE recent_active AS
--     SELECT DISTINCT pa.AuthorId
--     FROM airak.PublicationAuthor pa
--     JOIN airak.Publication p ON p.PublicationId = pa.PublicationId
--     WHERE p.PublishedDate >= DATE_SUB(CURRENT_DATE(), INTERVAL 36 MONTH)
--       AND p.PublishedDate <= CURRENT_DATE();
--   then act = (AuthorId IN recent_active); Productive (>=3 pubs) and H-index (>=1)
--   still come from AuthorMetric.
--
--   Universe                                      152,027,513
--    - not currently publishing                   141,879,567   (<3 pubs 130,073,278 · h-index 0 64,118,731 · not active in 36m 114,052,411)
--   = Active                                       10,147,946   (6.68% of Universe)
--    - business & ethical exclusions                  910,013   (country 817,033 · retractions 93,781 · watchlisted 13,128 · SPP restricted 1,370)
--   = Eligible                                      9,237,933   (91.03% of Active)
--    - identity we don't trust                      1,832,604   (no affiliation 948,709 · over-merged 713,908 · duplicate SF 252,216 · no last name 50,533)
--   = Identifiable                                  7,405,329   (80.16% of Eligible)
--    - consent blocks + no usable email             3,804,577   (no email 3,140,811 · bounced 254,730 · none deliverable 241,313;
--                                                            unsub 185,880 · opt-out contact 158,679 · opt-out lead 76,338)
--   = Contactable                                   3,600,752   (48.62% of Identifiable, 2.37% of Universe)
--
--   WHY THIS DIFFERS FROM THE PERFECT PROFILE DASHBOARD (same source tables):
--     1. Different AIRAK load — that dashboard's Universe was 151,266,103, ours
--        152,027,513 (AIRAK is rebuilt in place, not versioned).
--     2. It stops at "Target Audience" (Active+Productive+H-index+Affiliated+
--        not-watchlisted+no-retractions+eligible-country = 8,267,426) and never
--        applies the remaining identity rules (over-merge, duplicate, last name),
--        the SPP/competitor rules, or contactability. Our funnel continues to
--        Contactable. Its endpoint sits between our Eligible and Identifiable.
--     3. It groups affiliation inside the activity/quality tier; we place it in
--        Identifiable. Order changes attribution, not the final population.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- V4 — SAMPLE TABS. The same funnel run on the two recommender samples
-- instead of the whole researcher population.
--   Order: sample base -> Active -> Eligible -> Identifiable -> Contactable
--   Inputs (already in the workspace, joined in pandas on aira_id):
--     Sample A  bquxjob_757bfd36_19ffbc11041.csv        12,859 rows / 12,809 ids
--     Sample B  review-recommender-retrieval-results.xlsx 4,977 rows /  4,975 ids
--               (5 sheets, de-duplicated within each manuscript)
--   Flags come from ONE parameterised BigQuery query over the 17,750 distinct ids
--   (pass the id list as an ARRAY<INT64> query parameter — inlining it as an array
--   literal makes the query unusably slow), then the cuts are applied in pandas.
--
--   WITH ids AS (SELECT id FROM UNNEST(@ids) id), r AS (...status_reason...),
--        em AS (...AuthorEmail: LOGICAL_OR(ValidityId IN (1,2))...)
--   SELECT i.id, a.IsPotentialOvermerged, a.LastName, a.HasAffiliation, r.c AS codes,
--          em.n>0 AS any_email, em.hd, m.LastYearAsAuthor, m.PublicationCount, m.Hindex
--   FROM ids i LEFT JOIN airak.Author a ... LEFT JOIN airak.AuthorMetric m ...
--
--   Active = publication with PublishedDate in the last 36 months (rolling, via
--   PublicationAuthor+Publication) AND PublicationCount >= 3 AND Hindex >= 1.
--   The rolling window is computed from a temp table of recent author ids; the two
--   sample tabs check membership of the 17,750 candidate ids in that set.
--   Identifiable    = NOT (over-merged OR no last name OR ALN OR SDD OR no affiliation)
--   Eligible        = NOT (AWL, ART, ABC, SSX, SSR, SCP)
--   Contactable     = NOT (SGU, SOC, SOL) AND NOT (no deliverable address OR SBE)
--
-- SAMPLE A - Research Topic contributor candidates
--   base (candidate rows)                12,859
--    - not currently publishing           2,372   (<3 pubs 1,917 · h-index 0 1,295 · not active in 36m 669)
--   = Active                             10,487   (81.6% of base)
--    - business & ethical                   884   (country 495 · retractions 331 · watchlisted 129 · SPP restricted 15)
--   = Eligible                            9,603   (91.6% of Active)
--    - identity we don't trust            2,043   (no affiliation 361 · over-merged 813 · duplicate SF 1,188 · no last name 35)
--   = Identifiable                        7,560   (78.7% of Eligible)
--    - consent + email                    3,552   (no email 2,164 · bounced 599 · none deliverable 307;
--                                                 unsub 525 · opt-out contact 500 · opt-out lead 139)
--   = Contactable                         4,008   (53.0% of Identifiable, 31.2% of base)
--   by source: Publication DB 7,859->2,078 · Researcher Profile DB 4,835->1,848 · Both 165->82
--
-- SAMPLE B - Manuscript reviewer candidates
--   base (candidate rows)                 4,977
--    - not currently publishing             720   (<3 pubs 491 · h-index 0 306 · not active in 36m 303)
--   = Active                              4,257   (85.5% of base)
--    - business & ethical                   347   (country 225 · retractions 103 · watchlisted 45 · SPP restricted 2)
--   = Eligible                            3,910   (91.8% of Active)
--    - identity we don't trust              565   (no affiliation 84 · over-merged 260 · duplicate SF 310 · no last name 12)
--   = Identifiable                        3,345   (85.5% of Eligible)
--    - consent + email                    1,618   (no email 1,072 · bounced 225 · none deliverable 115;
--                                                 unsub 187 · opt-out contact 179 · opt-out lead 72)
--   = Contactable                         1,727   (51.6% of Identifiable, 34.7% of base)
--   by source: Publication DB 2,477->799 · Researcher Profile DB 2,477->921 · Both 23->7
--
--   Both samples run on the same 2026-08-14 AIRAK load as the Overview funnel.
-- ---------------------------------------------------------------------

-- =====================================================================
-- NOTES
-- 1. RPS and BigQuery agree exactly on the whole top funnel (universe,
--    each Stage 1 rule, Stage 1 combined, and the 958,811 eligibility drop).
-- 2. The individual eligibility rules differ slightly by route — RPS reads
--    airak.AuthorExclusion (12,859 / 95,476 / 864,894), the suppression list
--    re-derives them (13,312 / 95,546 / 865,337). The union is identical, so
--    the Active is unaffected. Prefer the suppression list: it is the
--    authoritative exposure layer and carries the reason codes.
-- 3. DO NOT use reason code ANV ("no verified email") as the email test.
--    Inside Stage 1 it only ever co-occurs with another exclusion (512,242 of
--    512,242), so after eligibility it reports zero email problems. Email
--    coverage must come from airak.AuthorEmail.ValidityId IN (1,2).
-- 4. airak.Author currently holds a single airak_version (2026-08-05); add a
--    version filter if that stops being true.
-- =====================================================================
