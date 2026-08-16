---
name: db-query
description: Execute SQL queries against the staging or dev database using sqlcmd with Windows integrated authentication.
argument-hint: <sql-query> [--db MainDb|AccountsDb] [--env staging|dev]
---

# Execute SQL Query

Query: $ARGUMENTS

## Your task

Parse the arguments:
- **sql-query**: The SQL to execute (required)
- **--db**: Database name, `MainDb` or `AccountsDb` (default: `MainDb`)
- **--env**: Environment, `staging` or `dev` (default: `staging`)

## Execute query

Connection details (servers, databases, auth) are in CLAUDE.md.

```bash
sqlcmd -S "{server}" -d "{database}" -E -C -Q "{sql-query}"
```

- `-E`: Windows integrated authentication
- `-C`: Trust server certificate

## Example

```bash
sqlcmd -S "sql-staging.example.com" -d "MainDb" -E -C -Q "SELECT TOP 10 * FROM Processors"
```

## Important

- For large result sets, add `TOP N` or `WHERE` clauses to limit output
- Never point this at production; the allowed servers are the ones listed in CLAUDE.md
