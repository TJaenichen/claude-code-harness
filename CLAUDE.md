# Working in this repo

This is a public collection of Claude Code skills, agents, hooks and CLAUDE.md templates. Everything is generalized; see `docs/placeholders.md` for the legend.

Rules when editing:

- Never introduce real company, product, host, person or credential values. Use the placeholders from `docs/placeholders.md` (`Contoso`, `Payments`, `devops.example.com`, `MainDb`, `12345`, `Jane Doe`).
- Run `pwsh scripts/lint-placeholders.ps1` before committing. It must print "No findings."
- Skills stay in Claude Code's native layout: `skills/<scope>/<name>/SKILL.md` with frontmatter (`name`, `description`, `argument-hint`, `allowed-tools`). Helper scripts sit next to the SKILL.md that uses them.
- Prefer editing an existing skill over adding a near-duplicate. If a skill is only meaningful with a tool that is not in this repo, leave it out and note it in `docs/placeholders.md`.
- README prose: plain, direct, no em dashes.
