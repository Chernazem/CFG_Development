# TB Workspace Bootstrap Backup

Created: 2026-06-23 20:34:29 +03:00
Source workspace: D:\Dev Projects\TB

Included:
- Root workspace instructions/config: AGENTS.md, README.md, TB.code-workspace, .editorconfig, .gitignore
- .cursor rules, skills, and MCP config
- agents/ role metadata
- docs/setup, docs/repos, docs/scheduled-jobs, docs/architecture
- docs/decisions files except DEV task artifacts
- tools/scripts shared scripts
- oscript_modules lightweight local modules
- repos/manifest*.yaml and repos/README.md only, not repository working trees
- Empty structure placeholders: src/, tests/, docs/requirements, docs/decisions, repos/

Excluded intentionally:
- repos/* repository working trees, except manifest/README files
- DEV-* task artifact directories
- .local-ci, .local-ci-runlogs, .local-tools
- .tools (large external tool checkouts; restore via docs/setup)
- .env, secrets, credentials, logs, previous archives, Graylog/Jenkins task artifacts
- docs/requirements/DEV-* and DEV-specific ADR/requirement artifacts

Restore sketch:
1. Extract archive to the new workspace root.
2. Recreate/fetch repositories from repos/manifest.yaml.
3. Restore external tools using docs/setup/*.md when needed.
4. Create local .env/secrets manually on the target machine; they are not backed up.
