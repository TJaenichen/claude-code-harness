<!--
Workspace-level CLAUDE.md. Lives at the parent of all repos and worktrees
(here: C:\work\CLAUDE.md) so every session launched anywhere below it inherits
the git/worktree conventions, DB safety rules and coding standards.
Project-specific detail goes into each repo's own CLAUDE.md (see dotnet-monorepo.CLAUDE.md).
Placeholders: Payments = main repo, MainDb/AccountsDb = databases, *.example.com = hosts.
-->

You're running on native windows inside powershell.

## Environment
- This is a Windows/PowerShell environment. Use Windows path formats and avoid PowerShell here-strings for JSON; prefer escaping or file-based input for commit messages and work-item links.

## Safety
- Never run blanket process-kill or cleanup commands; scope kills to specific PIDs to avoid terminating the active session's own MCP/LSP processes.

## Working Style
- Before broad code investigation or config exploration, confirm the user's intended action; for direct requests (e.g., 'install the marketplace', 'create a .sql file'), act directly rather than exploring first.

## DevOps & PRs
- When working with PRs, always check whether they are stacked before merging or splicing; verify each PR's base branch and diff against main before assuming a simple merge.

# Git Workflow & DevOps Integration Guide

## Branch Naming Convention

Branch names must follow this format:
```
feature/<workitemid>_<15 chars max title>
```

**Example**: `feature/12345_Short_Title`

## Directory Naming Convention

**Important**: Keep directory names SHORT to avoid Windows path length issues.

Directory format:
```
<workitemid>_<shorttitle>
```

**Example**: `12345_Short_Title` (NOT `feature-12345_Short_Title`)

**Web Interface**: `https://devops.example.com/DefaultCollection/MyProject/_workitems/edit/<WORKITEM_ID>/`

## Git Worktree Workflow

Worktrees allow you to have multiple branches checked out simultaneously in different directories.

**IMPORTANT**: Only use worktrees when explicitly asked for.

**Skills available**:
- `/starttask <work-item-id>` - Create worktree and branch from DevOps work item
- `/cleanup-worktree <work-item-id>` - Remove worktree after merge

### Worktree Best Practices

1. **Always create worktrees in /c/work** - Keep them at the same level as the main repository
2. **Keep paths SHORT** - Windows has path length limitations
3. **Use descriptive but concise directory names** - `<ID>_<ShortTitle>` pattern
4. **Clean up when done** - Remove worktrees after merging to avoid clutter
5. **One worktree per feature** - Don't create multiple worktrees for the same branch

### Path Notes
- Use Unix-style paths for git commands: `/c/work/...` (Git Bash format)
- For cd commands, use quoted Windows paths: `cd "C:\work\Payments"` or Unix-style: `cd /c/work/Payments`
- Branch name includes "feature/" but directory name does NOT

### Path Too Long Issues
If you encounter "path too long" errors:
- Shorten the `<ShortTitle>` portion to 5-10 chars (instead of the normal 10-15 chars)
- Avoid deeply nested folder structures in your work
- Consider using Git config: `git config --system core.longpaths true`

## Repository Structure

```
C:\work\
├── Payments\                 # Main repository
├── DbScripts\                # Database object scripts (nightly export)
└── <ID>_<ShortTitle>\        # Worktree directories (SHORT names!)
```

## Quick Reference

| Element | Format | Example |
|---------|--------|---------|
| Branch Name | `feature/<ID>_<ShortTitle>` | `feature/12345_Short_Title` |
| Directory Name | `<ID>_<ShortTitle>` | `12345_Short_Title` |
| Full Path | `/c/work/<ID>_<ShortTitle>` | `/c/work/12345_Short_Title` |

---

# Database Reference

## SQL & Metrics
- For approval/status metrics, use the authoritative outcome flag column (here: `Processed = 1`), not string matching on 'APPROVED' or the raw status column. Verify column names against the actual schema before writing SQL scripts.

## DbScripts Sources

Nightly updates are made to `C:\work\DbScripts\sources`, which contains create scripts for all database objects.

**Skills available**:
- `/db-search <term> [table|sp|view|function] [MainDb|AccountsDb]` - Search for database objects
- `/db-query <sql> [--db MainDb|AccountsDb] [--env staging|dev]` - Execute SQL queries

## Databases

| Database | Scale |
|----------|-------|
| **MainDb** | ~1,000 tables, ~2,000 stored procedures |
| **AccountsDb** | ~600 tables, ~3,000 stored procedures |

## Connections

All connections use **Windows Integrated Security**:
- **Staging** (preferred): `sql-staging.example.com`
- **Dev** (shared, may be inconsistent): `sql-dev.example.com`

## Measuring deposit success / approval

To determine whether a card deposit **actually went through**, use **`Transactions_Card.Processed = 1`**
(denominator: rows where `Processed IS NOT NULL`, i.e. handled). This is the same definition the
payment pipeline itself uses for its own success-rate query.

- **Do NOT** key success off `ResponseErrorDetail = 'APPROVED'`. That column holds many free-text
  variants (`APPROVED`, `Transaction is approved`, `Transaction is approved.`, `SUCCESS`, …), so an
  exact string match silently undercounts (it once reported roughly half the real rate).
  `TransStatusCode` is essentially always NULL — useless.
- Know the real baseline (write it here once you have it) and treat it as steady. If a success
  rate looks implausibly low, suspect the metric before concluding there is a "drop."

---

# Development Standards

## Architecture
- Follow **Clean Architecture**: Domain → Application → Infrastructure → Presentation
- Follow **SOLID principles** and **DRY**
- Assume patterns already exist - search before creating new ones
- **NEVER introduce new features, patterns, projects** without confirming with the human first

## Testing
- Use `Assert.Fail()`, never `Assert.Ignore()` or `Assert.Inconclusive()`
- In most cases there are functions to provide proper test data (customer, CC, etc.)

## Tools
- ripgrep is installed. Use `rg` to search files

## Important Notes
- Dev DB is actively used by other devs - prefer staging for consistency
- We're looking for clean code. Part of that is not using #regions in C#

# Temporary files
If you need to create temporary files (powershell scripts, SQL, todo lists, state of work items), feel free to do so. But do it under c:\work\scratchpad, never in the worktree to keep these clean.
