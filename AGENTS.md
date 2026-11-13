# Мультиагентная разработка 1С (workspace TB)

Workspace объединяет **несколько git-репозиториев**. Общие роли — здесь; **правила кода — в каждом репо** (`repos/<id>/.cursor/rules/`).

Для **TB** основной документ — [`repos/conf-main/AGENTS.md`](repos/conf-main/AGENTS.md) (в GitLab, не перезаписывать краткой заглушкой). Workspace-правила в `.cursor/rules/` только дополняют его.

Канонический чеклист разработки: [`.cursor/rules/critical-flow.mdc`](.cursor/rules/critical-flow.mdc). Подробности EDT MCP, Jenkins и сети — в [`docs/setup/`](docs/setup/). Не копировать эти runbook'и в каждый ответ.

## Уровни

| Уровень | Путь | Назначение |
|---------|------|------------|
| Workspace | корень `TB/` | роли, skills, кросс-репо ТЗ/ADR, manifest |
| Репозиторий | `repos/<id>/` | исходники 1С, свои rules, локальные docs |

Перед работой: определить `id` по [repos/manifest.yaml](repos/manifest.yaml) или по пути открытого файла. Перед любыми изменениями прочитать `AGENTS.md` целевого репозитория (`repos/<id>/AGENTS.md` или `repos/DEV-123 <id>/AGENTS.md` для task-клона).

## Обязательный короткий чеклист

1. Целевой репозиторий + его `AGENTS.md`.
2. Эталон по default-ветке remote, затем изоляция worktree: `DEV-123/` и `repos/DEV-123 <id>/` (`docs/setup/task-worktrees.md`).
3. **Ключ Jira `DEV-XXXXXX` обязателен** в имени ветки, каждом коммите и заголовке/описании MR (см. [`.cursor/rules/dev-task-key-required.mdc`](.cursor/rules/dev-task-key-required.mdc)). Без ключа — не создавать ветку/не коммитить/не открывать MR.
4. EDT-проекты задачи на TB-PC: `src/cf` и `src/tests` (`docs/setup/edt-mcp.md`). Чат агента остаётся в корне TB, не `move_agent_to_root`.
5. Проверка кода task-клона: EDT MCP (`get_project_errors`) **или**, если EDT MCP не готов, **обязательный LSP** на проекте task-клона (`docs/setup/lsp-task-clones.md`) — локальная замена Sonar; все правила LSP включены.
6. Unit для `conf-main` на TB-PC: `run_yaxunit_tests` **или** `tools/scripts/invoke-conf-main-local-unit.ps1`. При запасном контуре LSP + local-unit **оба** обязательны перед push.
7. Тесты: бизнес-кейсы, **статические данные только в XML-макетах фикстур** (не конструкторы в `// Дано`; `repos/conf-main/src/AGENTS.md` → «Фикстуры»), строгое равенство эталону; свежий `genericExecution.xml` содержит все новые/изменённые testCase задачи.
8. Pre-push self-review по `AGENTS.md` целевого репо + шаблон ниже.
9. После push — актуальное описание MR, затем мониторинг Jenkins (в Cursor: Automation или `/loop 30m`, не оставлять heartbeat после terminal result). **Три `ABORTED` подряд** по одному MR — стоп рестартов, ждать команды (`docs/setup/jenkins-aborted-builds.md`).
10. В терминальной MR-сборке обязателен **зелёный SonarQube Quality Gate** ([`docs/setup/sonarqube-quality-gate.md`](docs/setup/sonarqube-quality-gate.md)); красный QG — блокер, фикс → новый push → новый мониторинг.
11. Готовность — только если локальные проверки по задаче зелёные, MR актуален, внешняя сборка не падает из-за наших изменений, **Sonar QG OK**.

Подробности: [`docs/setup/task-worktrees.md`](docs/setup/task-worktrees.md), [`docs/setup/edt-mcp.md`](docs/setup/edt-mcp.md), [`docs/setup/gitlab-mr-encoding.md`](docs/setup/gitlab-mr-encoding.md), [`docs/setup/sonarqube-quality-gate.md`](docs/setup/sonarqube-quality-gate.md).

## Pre-push статус

```text
Pre-push gate:
- Repo AGENTS read: <path>
- Task clone: <path>
- DEV key in branch/commits/MR title: DEV-XXXXXX present / BLOCKED (missing)
- EDT MCP: <get_server_status / plugin+EDT version> | skipped (not ready)
- Code check: get_project_errors ERRORS on changed objects — none / list | OR LSP diagnostics on task-clone project — none / list
- LSP: project running for task-clone; all diagnostic rules enabled in LSP service — yes/no/evidence
- Unit: run_yaxunit_tests jobId / report path | OR invoke-conf-main-local-unit.ps1 + DEV-*/local-ci report
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

## Роли (skills в `.cursor/skills/`)

| Роль | Skill | Когда привлекать |
|------|-------|------------------|
| Проджект-менеджер | `1c-project-manager` | Общий план, постановка задач; исполнителей слать на `TB-PC` (`docs/setup/cursor-my-machines-worker.md`) |
| Аналитик | `1c-analyst` + `requirements-writer` | ТЗ, user stories; FNC/ARC — canvas |
| Архитектор | `1c-architect` | Метаданные, интеграции, ADR |
| Разработчик | `1c-developer` | BSL, формы, доработки в `repos/<id>/` |
| Ревьюер | `1c-reviewer` | Ревью с учётом rules **целевого** репо |
| Тестировщик | `1c-tester` | `repos/<id>/tests/` |

## Дополнительные навыки

Источники и состав: [`docs/setup/ai-rules.md`](docs/setup/ai-rules.md), [`docs/setup/cc-1c-skills.md`](docs/setup/cc-1c-skills.md). Каталог `cf-*` / `db-*` / `form-*` / … вызывать **по имени**; роли и отдельские навыки — по задаче.

| Skill | Когда привлекать |
|-------|------------------|
| `1c-queries` | Запросы к ИБ; MCP `execute_1c_query` или fallback `tools/scripts/query-1c-llm-requests.ps1` |
| `1c-test-first-development` | Test-first с YaxUnit |
| `1c-external-epf-authoring` | Внешние обработки `epf` |
| `1c-bsp-check`, `1c-bsp-check-parameter`, `1c-public-api-param-types` | Проверки параметров публичного API БСП |
| `1c-form-secret-edit` | Секреты на форме (маска GUID) |
| `1c-sql-translate`, `1c-graylog-find-query` | SQL из ТЖ/Graylog → метаданные и исходный запрос 1С |
| `confluence-wiki-search` | Поиск в корпоративной wiki |
| `web-test-tb` | Нюансы web-test TB поверх `web-test` |

## MCP

Разрешены любые подключённые MCP, если это помогает задаче и не нарушает безопасность.

- Проектный RAG: [`docs/setup/mcp-1c-v1.md`](docs/setup/mcp-1c-v1.md), `.cursor/mcp.json` → `tb-1c-rag`.
- Запросы к данным ИБ: [`docs/setup/1c-llm-requests.md`](docs/setup/1c-llm-requests.md).
- Отделские OAuth MCP (Confluence, Graylog) — в `.cursor/mcp.json`; GitLab/Jira обычно уже в user MCP.
- Перед HTTP к ИБ — минимальные права.

## Локальные креды

Секреты только в игнорируемых git файлах: `.env`, `.env.*`, `secrets/`, `credentials.*` в **корне текущего workspace**.

Jira: `JIRA_URL`, `JIRA_LOGIN`, `JIRA_PASSWORD`. Не копировать значения в правила, логи, summary, коммиты или MR.

## Изоляция DEV-задач

Параллельные DEV-ветки живут в отдельных каталогах. Для `DEV-123`:

1. Артефакты — `DEV-123/` в корне workspace.
2. Перед task-клоном обновить эталон по default-ветке remote.
3. Рабочее дерево — **git worktree** `repos/DEV-123 <id>/` от эталона (пример: `repos/DEV-123 conf-main`). Не второй clone. В эталонах из `manifest.yaml` задачу не вести. Команды: [`docs/setup/task-worktrees.md`](docs/setup/task-worktrees.md). Чат агента **не** переносить в этот каталог (`move_agent_to_root` / `move_agent_to_cloned_root` запрещены): worktree внутри текущего workspace.
4. Скрипты CI — только `tools/scripts/`, не копировать в `DEV-*`.
5. По явному «задача завершена» — `git worktree remove` (если дерево чистое), EDT-проекты задачи (`delete_project` при необходимости) и каталог `DEV-123/`.

## Приоритет правил

1. `.cursor/rules/` **репозитория**, в котором лежит файл
2. `repos/<id>/AGENTS.md`
3. `.cursor/rules/` workspace (оркестрация, выбор репо)
4. Skills ролей (общие)

## Обмен артефактами (TB-PC ↔ основной ПК)

Точечная передача EPF/CFE/логов — каталог [rtifacts/exchange/](artifacts/exchange/README.md) в этом репозитории + GitHub-ссылка после push.
Правило: [.cursor/rules/tb-pc-artifacts-exchange.mdc](.cursor/rules/tb-pc-artifacts-exchange.mdc), runbook: [docs/setup/tb-pc-artifacts-exchange.md](docs/setup/tb-pc-artifacts-exchange.md).
Не класть тестовые обработки в GitLab-ветки «ради скачивания» и не использовать Яндекс.Диск для таких handoff.

## Ограничения

- Не смешивать в одном PR изменения разных репозиториев без явного плана.
- Бинарные `.cf`/`.cfe` не хранить в git — только исходники в `src/`.
- Один change set на задачу в рамках одного репо.
