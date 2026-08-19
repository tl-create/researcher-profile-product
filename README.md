# Agent Briefing: Tzu-i Liao — PM, Researcher Profile

> Purpose: give any agent working with Tzu-i the context to act correctly on her behalf.
> Last verified: 2026-08-19, against Confluence, Jira, and GitHub (frontiersin org).

## 1. Identity & role

| | |
|---|---|
| Name | Tzu-i Liao |
| Email | tzui.liao@frontiersin.org |
| Role | Product Manager, Researcher Profile |
| Jira | Lead of project **NESS** (Researcher Profile) — confirmed via `/rest/api/2/project/NESS` |
| Timezone | Europe/Zurich |

**Mission in one sentence:** own researcher intelligence end to end — identity resolution (Golden Record), the system of record (RPS), AI enrichment, the Explorer discovery UX, and trust/governance — delivered through Teams Alexandria and Akira, consumed by Growth, CRM/Perfect Email, editorial assignment, and Frontiers' AI agents.

## 2. Teams

| Team | Role in her scope | Key people | Evidence |
|---|---|---|---|
| **Alexandria (ALX)** | Delivery team: profile generation, AIRAK data slices, dashboards | Marcelo Milan (Jira ALX lead; active committer) | [researchers-profile-generation](https://github.com/frontiersin/researchers-profile-generation), [alexandria-dashboards](https://github.com/frontiersin/alexandria-dashboards), [alexandria-planning-workspace](https://github.com/frontiersin/alexandria-planning-workspace) |
| **Akira** | Engineering team; AIRAK data platform, APIs, tooling | see [team-akira-docs](https://github.com/frontiersin/team-akira-docs) | [akira-cli](https://github.com/frontiersin/akira-cli), [akira-experiments](https://github.com/frontiersin/akira-experiments), Confluence page *Akira Team API* (id 403544112) |
| **Data Interfaces (DIF)** | Jira project where Researcher Explorer work lives | Daniel Negrao (Jira DIF lead) | 36 of her latest 200 Jira issues are DIF |

## 3. Initiatives (Jira, all In Progress)

| Initiative | Jira | Notes |
|---|---|---|
| Centralised researcher intelligence | [NESS-6611](https://jira.frontiersin.net/browse/NESS-6611) | Absorbed the former RPS initiative ([merge noted on Confluence page 767441540](https://confluence.frontiersin.net/pages/viewpage.action?pageId=767441540)) |
| Build the Golden Record | [NESS-6378](https://jira.frontiersin.net/browse/NESS-6378) | Identity resolution; Confluence pages 677158872 / 766645604 |
| Trusted Researcher profiles | [NESS-6612](https://jira.frontiersin.net/browse/NESS-6612) | PRD on Confluence (page 767441564) |
| Researcher Explorer UI | [NESS-6610](https://jira.frontiersin.net/browse/NESS-6610) | Discovery/search UX |

## 4. Product surface & active work

### Researcher Profile Service (RPS)
GraphQL system of record: [researcher-profile-service](https://github.com/frontiersin/researcher-profile-service).
- Done: abstracts added to RPS ([DIF-1423](https://jira.frontiersin.net/browse/DIF-1423)); Publications section removed from RPS & Explorer UI ([DIF-1422](https://jira.frontiersin.net/browse/DIF-1422))
- In progress: eligibility details in RPS & Explorer ([DIF-1367](https://jira.frontiersin.net/browse/DIF-1367))

### Researcher Explorer (search & filters)
- PRD 1.6 advanced search operators POC ([DIF-1532](https://jira.frontiersin.net/browse/DIF-1532), In Progress)
- PRD 5.4 Section filters ([DIF-1529](https://jira.frontiersin.net/browse/DIF-1529), In Progress)
- PRD 5.6 Audience size preview ([DIF-1590](https://jira.frontiersin.net/browse/DIF-1590), In Progress)
- Hierarchical Journal/Section filter prototype ([DIF-1303](https://jira.frontiersin.net/browse/DIF-1303), in review)
- Backlog: Grants & Conferences side-panel filters ([DIF-1534](https://jira.frontiersin.net/browse/DIF-1534)), Frontiers engagement tab ([DIF-1530](https://jira.frontiersin.net/browse/DIF-1530)), PRD 1.5 key-term search validation ([DIF-1531](https://jira.frontiersin.net/browse/DIF-1531)), PRD 1.7 explainability ([DIF-1533](https://jira.frontiersin.net/browse/DIF-1533))
- Done: China top institutions filter ([DIF-1411](https://jira.frontiersin.net/browse/DIF-1411)), editorial-roles filter v2 ([DIF-1540](https://jira.frontiersin.net/browse/DIF-1540))
- Adoption: *Researcher Explorer Journal Teams Feedback: Adoption Blockers* (Confluence 769180628)

### AI Enhanced Profiles
- Generation for Growth audiences ([NESS-6379](https://jira.frontiersin.net/browse/NESS-6379), In Progress); validation resolved ([NESS-6542](https://jira.frontiersin.net/browse/NESS-6542))
- Planned PRDs: 1.2 on-demand/event-triggered generation ([NESS-6608](https://jira.frontiersin.net/browse/NESS-6608)), 1.3 AI profile from AIRAK publications ([NESS-6609](https://jira.frontiersin.net/browse/NESS-6609)), auto-generation for new EBMs ([NESS-6541](https://jira.frontiersin.net/browse/NESS-6541))
- ALX Azure work: *ALX - Azure AI Enhanced Researcher Profiles* (Confluence 769183835)

### Golden Record / identity
- *Problem Analysis — Researcher Identity* (Confluence 766660404)
- Smart disambiguation pipeline ([NESS-6381](https://jira.frontiersin.net/browse/NESS-6381))
- Weekly AIRAKtoMerge CSV exports to Confluence (e.g. pages 828148246, 827786371); *AIRAK Profile Issue Requests* (767428858)

### Signals & downstream consumers
- PRD 3.1 / 4.1 editorial & peer-review signals (Confluence 766653573, 769404619)
- PRD 3.7 invitation signals ([NESS-6606](https://jira.frontiersin.net/browse/NESS-6606))
- CFX v3 iterations 1 & 2 ([NESS-6607](https://jira.frontiersin.net/browse/NESS-6607), In Progress); New CFX ([NESS-6528](https://jira.frontiersin.net/browse/NESS-6528))
- Competitor Graph ([NESS-6117](https://jira.frontiersin.net/browse/NESS-6117))
- Perfect Email: *Researcher Profile Data: Coverage Analysis* (Confluence 766652816); CRM exclusion explanations ([CRM-2390](https://jira.frontiersin.net/browse/CRM-2390))

## 5. Planning & documentation hubs

- **Q3/H2 planning tree (Confluence, RTA space):** *[Q3 Planning] 1. Researcher Profile — Q3 | H2 Planning* (767441519), Q2 2026 retrospective (767441532), per-domain Analysis & Recommendations: Submission (767441527), Quality (767441526), Editor/Reviewer Experience (767441525), Editorial Assignment (767441524), Peer Review (767441523)
- **Planning workspace (GitHub):** [alexandria-planning-workspace](https://github.com/frontiersin/alexandria-planning-workspace) — Q3 investigations incl. [recommender-filters-inventory.md](https://github.com/frontiersin/alexandria-planning-workspace/blob/master/investigations/2026-Q3/q3-planning/data/recommender-filters-inventory.md), eligibility PRD review, watchlist
- **User-facing docs:** *Researcher Profiles: User Guides* (827460094), Engagement filter guide (827460092), "What does Availability mean?" (827787023)
- **Governance:** *RBAC for Researcher Profile Pages* (827461002), *Researcher Profiler Agent* (828148012) + prompt (827460868)
- Confluence page URL pattern: `https://confluence.frontiersin.net/pages/viewpage.action?pageId=<id>`

## 6. Tools & systems

| System | Use | Notes for agents |
|---|---|---|
| Jira (jira.frontiersin.net) | NESS (hers), DIF, ALX, plus JPB, CRM, RTOP | Her issue footprint: NESS 71, JPB 54, DIF 36 of latest 200 |
| Confluence (confluence.frontiersin.net) | PRDs, planning, user guides | **Always use Tzu-i's own personal access token** (stored in her profile/bio settings) — never the workspace default, which authenticates as another user. Never write the token value into documents. |
| GitHub (frontiersin org) | Planning workspace, RPS, Alexandria/Akira repos, [skills](https://github.com/frontiersin/skills) | She maintains the `core-researcher-profile` skill (commits July 2026) and routed `jd-research`/`jd-growth` lookups through it |
| RPS GraphQL | Researcher system of record | Query via core-researcher-profile skill |
| AIRAK | Author/publication knowledge base (Akira) | Feeds AI profiles, Golden Record merges |
| FrontiersOS automations | Weekly ops | RP2026 dashboard refresh (Fri 19:00), Alexandria merge-request export (Mon 08:00), RP2026 comment sync (Mon 08:10) |

## 7. Stakeholders

- **Marcelo Milan** — Team Alexandria lead (Jira ALX lead, active in alexandria-planning-workspace)
- **Daniel Negrao** — Data Interfaces (DIF) lead
- **Team Akira** — AIRAK platform engineering
- **Consumers:** Growth (AI profiles, Artemis retrieval), CRM / Perfect Email, editorial assignment & peer review workflows, journal teams (Explorer adoption), Frontiers AI agents (via skills)

## 8. Working conventions (respect these)

1. New requirements use the prefix `req-c-` and go into existing workbook tabs before creating new ones.
2. Status wording mirrors the source exactly — no aggregation or renaming (e.g. use "available at source", not "ready").
3. Presentation materials: laptop-readable, non-technical audience first.
4. Overview/coverage pages must reflect the requirements workbook exactly.
5. Confluence writes on her behalf: her PAT only (see §6).
