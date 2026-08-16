---
name: merged-prs
description: Summarize PRs merged across all Azure DevOps projects within a time window. Default 24 hours; accepts overrides like `48h` or `7d`. Use when the user asks "what got merged" / "PRs from the last X hours/days" / "what shipped recently".
argument-hint: [time window, e.g. 24h, 48h, 7d — defaults to 24h]
user-invocable: true
---

# Merged PRs Summary

Summarize completed (merged) pull requests across the user's Azure DevOps server within a time window.

## Arguments

`$ARGUMENTS` — optional time window. Examples: `24h`, `48h`, `7d`, `3d`. Defaults to `24h` when empty.

Parse it as `<number><unit>` where unit is `h` (hours) or `d` (days). Convert days to hours (1d = 24h).

## Azure DevOps server

- **Base URL**: `https://devops.example.com`
- **Auth**: Windows Integrated (curl `--negotiate -u :`)
- **Projects**: discover at runtime via `/DefaultCollection/_apis/projects?api-version=7.0`. e.g. `MyProject` (primary) and `Sandbox`.

## Steps

1. **Parse the window.** Determine the cutoff datetime as `now - <window>`. If `$ARGUMENTS` is empty or unparseable, fall back to 24 hours.

2. **List projects.**
   ```bash
   curl -s -L --negotiate -u : "https://devops.example.com/DefaultCollection/_apis/projects?api-version=7.0"
   ```
   Extract project `name` values from the JSON `value` array.

3. **Fetch completed PRs per project.** For each project name:
   ```bash
   curl -s -L --negotiate -u : "https://devops.example.com/DefaultCollection/<ProjectName>/_apis/git/pullrequests?searchCriteria.status=completed&api-version=7.0&\$top=200"
   ```
   The API returns most-recent-first. If the oldest PR returned is still newer than the cutoff, increase `$top` and re-fetch (some windows like `7d` will need 500+).

4. **Filter by `closedDate`** — keep PRs where `closedDate >= cutoff`. Note: `closedDate` is ISO-8601 with fractional seconds and a `Z` suffix; parse robustly.

5. **Group by repository** (`p['repository']['name']`). Within each repo, list PRs as `PR <id> | <author display name> | <title>`.

6. **Render the summary** in this shape:
   - Lead line: total PR count across all projects + the window.
   - Sections by repo, sorted by PR count descending. Use tiered headers (Heavy / Moderate / Light / Singletons) when the spread justifies it; otherwise just one flat list.
   - Within each repo entry, group multiple PRs by the same author when natural ("Jane Doe refactoring (X, Y, Z)") rather than listing each as a bare bullet.
   - Skip projects with zero PRs in window, but mention them briefly ("Sandbox had none") so the user knows they were checked.
   - End with a short **Themes** paragraph: cross-cutting patterns (e.g. "solution-structure cleanup dominates", "the BI team is mid-migration to a new scheduler"), or "No obvious cross-repo incident" if nothing stands out.

## Python one-liner for filtering/grouping

The data is easier to handle in Python than jq on Windows. Pattern that works:

```bash
curl -s ... | python -c "
import sys, json
from datetime import datetime, timedelta, timezone
from collections import defaultdict
d = json.load(sys.stdin)
cutoff = datetime.now(timezone.utc) - timedelta(hours=<N>)
prs = [p for p in d['value']
       if datetime.fromisoformat(p['closedDate'].replace('Z','+00:00').split('.')[0]+'+00:00') >= cutoff]
by_repo = defaultdict(list)
for p in prs: by_repo[p['repository']['name']].append(p)
for repo, items in sorted(by_repo.items(), key=lambda x: -len(x[1])):
    print(f'=== {repo} ({len(items)}) ===')
    for p in items:
        print(f\"  PR {p['pullRequestId']} | {p['createdBy']['displayName']} | {p['title']}\")
"
```

## Notes

- Don't fetch PR descriptions/diffs by default — title + author is enough for the overview. Only drill into a specific PR if the user asks "tell me more about PR X".
- The PR `title` is usually the merge commit subject (DevOps strips the `Merged PR <id>:` prefix on the web UI but the API title is clean).
- Windows curl handles the URL escaping fine, but the `$top` query param must be escaped as `\$top` in bash to avoid shell expansion.
- If the user is on a feature branch and only cares about one repo, this skill is overkill — point them at `git log --since=...` instead.
