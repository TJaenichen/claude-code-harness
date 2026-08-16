---
name: db-search
description: Search for database objects (tables, stored procedures, views, functions) in the scripted-out DB sources. Use when looking for table schemas, SP definitions, or exploring database structure.
argument-hint: <search-term> [table|sp|view|function] [MainDb|AccountsDb]
---

# Database Object Search

Search term: $ARGUMENTS

## Your task

Parse the arguments to determine:
- **search-term**: The pattern to search for (required)
- **object-type**: `table`, `sp` (stored procedure), `view`, or `function` (optional, defaults to all)
- **database**: `MainDb` or `AccountsDb` (optional, defaults to both)

## Search locations

Database sources are scripted out nightly (one file per object) into `/c/work/DbScripts/sources/`:

| Database | Tables | Stored Procedures | Views | Functions |
|----------|--------|-------------------|-------|-----------|
| MainDb | `/c/work/DbScripts/sources/MainDb/tables/` | `/c/work/DbScripts/sources/MainDb/storedprocedures/` | `/c/work/DbScripts/sources/MainDb/views/` | `/c/work/DbScripts/sources/MainDb/functions/` |
| AccountsDb | `/c/work/DbScripts/sources/AccountsDb/tables/` | `/c/work/DbScripts/sources/AccountsDb/storedprocedures/` | `/c/work/DbScripts/sources/AccountsDb/views/` | `/c/work/DbScripts/sources/AccountsDb/functions/` |

## Search strategy

1. **Find by filename** (object name contains search term):
   ```bash
   ls /c/work/DbScripts/sources/{db}/{type}/ | grep -i "search-term"
   ```

2. **Find by content** (object references search term):
   ```bash
   rg -l -i "search-term" /c/work/DbScripts/sources/{db}/{type}/
   ```

## Output

Report:
- Matching object names (files)
- If searching content: which objects reference the term
- Offer to read specific files if the user wants to see definitions

## Note

The scripted files can drift behind the live database (hotfixes applied directly by DBAs). For the authoritative definition of a stored procedure, query `sys.sql_modules` on staging (see CLAUDE.md).
