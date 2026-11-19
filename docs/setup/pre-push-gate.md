# Pre-push gate

Заполнять перед push продуктовой ветки (`conf-main`, `extensions`, `api-swagger` и их task-клоны). Для правок оболочки `CFG_Development` шаблон не нужен.

```text
Pre-push gate:
- Repo AGENTS read: <path>
- Task clone: <path>
- DEV key in branch/commits/MR title: DEV-XXXXXX present / BLOCKED (missing)
- Shell sync: this machine not behind origin/main; stamp within 24h — yes/no
- EDT: not used
- Code check: LSP diagnostics on task-clone project — none / list
- LSP: project running for task-clone; all diagnostic rules enabled in LSP service — yes/no/evidence
- Unit: invoke-conf-main-local-unit.ps1 + DEV-*/local-ci report
- Unit report freshness/completeness: fresh report, normal runner finish, all new/changed task testCase names present
- Unit/external failures caused by task: none / list with reasoning
- Unit-test quality self-review: business cases + XML fixtures for static data (no BSL constructors in Given) + strict expected equality checked
- External unstable analysis: not needed / checked failed tests for fixture/test/data impact
- Main baseline comparison for MR unstable: not needed / compared with last 5 completed main builds, running main ignored, MR-only failures analyzed and recorded in MR
- MR description sync after push: planned/done, matches actual branch diff/checks/failure analysis
- Jenkins heartbeat plan: recurring every 30 minutes while build is running or not started; terminal build analyzed once, result reported, heartbeat stopped
- Jenkins 3× ABORTED stop: not triggered / armed (no auto-retrigger; wait for explicit command)
- SonarQube Quality Gate: planned after MR build / OK / ERROR (blocking findings…)
- Repo rules self-review: passed / issues fixed
- MR encoding check planned/done: yes/no
```
