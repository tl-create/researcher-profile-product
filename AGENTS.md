# Agent conventions — Researcher Profile product docs

Rules for any AI agent (or human) working in this repo or on Tzu-i Liao's behalf.

## Documentation rules
1. New requirements use the prefix `req-c-` and go into existing tabs/files before creating new ones.
2. Status wording mirrors the source exactly — no aggregation, no renaming (e.g. "available at source", never "ready").
3. Overview/coverage pages must reflect the requirements workbook exactly.
4. Presentation materials: laptop-readable, non-technical audience first.
5. Every document that mirrors a Confluence page must link that page (URL pattern: `https://confluence.frontiersin.net/pages/viewpage.action?pageId=<id>`) and note the last sync date.

## PR rules
- One PR = one decision or one document change.
- Title: `[<JIRA-KEY>] <imperative summary>` — e.g. `[NESS-6611] Add PRD 5.6 audience size preview`.
- Branch: `<jira-key-lowercase>/<slug>` — e.g. `ness-6611/prd-5.6-audience-preview`.
- Fill in every field of the PR template; "Confluence page affected" may be "none".

## Credentials
- Confluence access on Tzu-i's behalf: her personal access token ONLY (from her profile settings). Never the shared workspace connector. Never write token values into any file in this repo.
