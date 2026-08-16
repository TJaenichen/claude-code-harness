# Placeholders and omissions

Everything in this repo was generalized from a real setup before publishing. This page is the legend, plus the list of what was left out on purpose.

## Legend

| Placeholder | Stands for |
|---|---|
| `Contoso` | The company namespace prefix (`Contoso.Payments.API`, `Contoso.Web.Presentation`, ...). Contoso is Microsoft's stock fictional company; nothing here is about them. |
| `Payments` | The main repository / product, a payment processing platform. `C:\work\Payments` is its checkout. |
| `https://devops.example.com/DefaultCollection/MyProject` | Azure DevOps Server, collection and project. |
| `<REPO_ID>`, `<PROJECT_ID>` | The repository and project GUIDs from `_apis/git/repositories` and `_apis/projects`. |
| `MyProject\MyArea` | An area path. |
| `Team Wiki` / `Team%20Wiki` | The team's DevOps wiki name. |
| `MainDb`, `AccountsDb` | The two SQL Server databases. |
| `sql-staging.example.com`, `sql-dev.example.com` | Non-prod SQL hosts the skills are allowed to touch. |
| `sql-prod.example.com`, `sql-prod-mirror.example.com` | The prod primary (never queried) and its read replica. |
| `https://mattermost.example.com`, `$MM_TOKEN`, `$MM_CHANNEL_ID` | Mattermost server, personal access token, self-DM channel. |
| `12345`, `12346`, `4321` | Work item and PR IDs in examples. |
| `12345_ShortTitle` | A worktree directory / branch suffix. |
| `Jane Doe` | Any colleague in an example. |
| `C:\work\DbScripts\sources` | A folder of nightly scripted-out DB objects (one file per table / SP / view / function). |
| `C:\work\other-repo` | Any second repository. |
| `Sandbox` | Any second DevOps project. |

Datadog (`api.datadoghq.eu`), Hangfire, Dapper, MediatR, NUnit and `sqlcmd` are real products and are named as such.

## Custom DevOps fields

`Custom.Environment`, `Custom.StorySize` and `Custom.Days` in the work-item skills are organization-specific process fields. They are kept as examples of how to document custom fields; replace them with yours or drop them.

## Left out on purpose

| Item | Why |
|---|---|
| `settings.local.json` (permission allowlist) | Session-accumulated permission grants full of personal paths and one-off commands. No transferable content. |
| Hook debug log | A log file. |
| A personal project inventory | Company-internal project list; not harness material. |
| `semantic-search` / `reindex` skills | Thin wrappers around a local Python vector-index tool that is not part of this repo. Without the tool the skills are two lines of `python search.py $ARGUMENTS`. |
| The status line script `track-tooluse.ps1` feeds | Not in the source set. The hook is kept because the pattern (per-session temp file the status line polls) is the useful part. |
| The local context service `load-context.ps1` calls | An internal MCP/REST prototype. The hook shows the shape; point it at your own endpoint. |
| Older duplicate versions of the DevOps / worktree skills | Superseded by the versions here. |
| Test credentials, staging URLs, a live API token | Removed. The Mattermost skill now reads everything from environment variables. |

## Keeping it clean

`scripts/lint-placeholders.ps1` flags GUID-looking strings, `Bearer` tokens that are not `$VARS`, `https://` hosts outside a small allowlist and `C:\Users\<name>` paths. Run it before committing.
