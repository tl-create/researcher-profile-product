# Researcher Profile requirements (consolidated)

Consolidated data requirements for Researcher Profile (RPS, Explorer and consuming products), as shown on the requirements dashboard.

- **Last sync:** 29 Oct 2026, from the FrontiersOS requirements workspace
- **Dashboard:** [Requirements dashboard](https://os.frontiersin.io/organisations/org-frontiers/artifacts/dfb3340284/requirements-dashboard.html)
- **Rows:** 273 requirements across 13 categories (AI Profile rows are excluded, as on the dashboard)

## Files

| File | What it holds |
|---|---|
| `requirements.csv` | One row per requirement, all columns |
| `requirements.json` | Same content as JSON |

## IDs

IDs follow `REQ-<CATEGORY>-NNN` and run from 001 with no gaps in each category. They were renumbered on 29 Oct 2026; `Former ID (workbook)` keeps the original workbook ID where one existed. The `req-c-` prefix is no longer used.

| Prefix | Category |
|---|---|
| REQ-ID | Identity |
| REQ-CON | Contact |
| REQ-INS | Institution |
| REQ-ELI | Eligibility |
| REQ-SUB | Submission |
| REQ-ER | Editorial Roles |
| REQ-REV | Review Activities |
| REQ-EDT | Editing Activities |
| REQ-RT | RT Activities |
| REQ-INV | Invitations |
| REQ-SF | Survey & Feedback |
| REQ-IMP | Impact |
| REQ-SEA | Search |

## Rows by category

| Category | Rows |
|---|---|
| Identity | 14 |
| Contact | 13 |
| Insititution | 11 |
| Eligibility | 21 |
| Submission | 20 |
| Editorial Roles | 14 |
| Review Activities | 34 |
| Editing Activities | 35 |
| RT Activities | 15 |
| Invitations | 24 |
| Survey & Feedback | 6 |
| Impact | 45 |
| Search | 21 |

## Availability (wording as in the source)

| Availability | Rows |
|---|---|
| 🔵 Available at source | 103 |
| 🟡 Available with caveat | 54 |
| ✅ Available | 48 |
| ⬜ To be evaluated | 41 |
| to be evaluated | 16 |
| 🔴 Not available | 10 |
| Not available | 1 |

## Sources

Requirement sources include the PRD v10 workbook, Confluence PRDs, Figma files, the RTM-UX and Manuscript.Submission code, the [Researcher Explorer prototype](https://github.com/frontiersin/researcher-explorer-prototype) and the MarketExplorerClientTest repo. The `Sources` column names the source of each row.

`Data source (long term)` shows AIRAK where a row has a status at source but no data source was listed.
