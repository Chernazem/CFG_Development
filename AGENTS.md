# CFG_Development — оболочка агентской разработки

Корень workspace — git-репозиторий [Chernazem/CFG_Development](https://github.com/Chernazem/CFG_Development), ветка `main`. Здесь канон флоу, skills, скриптов и правил. Продуктовый код 1С живёт в репозиториях из [repos/manifest.yaml](repos/manifest.yaml) и в эту оболочку не коммитится.

| Что меняем | Куда | Какой флоу |
|------------|------|------------|
| `.cursor/rules/`, `.cursor/skills/`, `tools/scripts/`, `docs/setup/`, этот файл | корень, `CFG_Development` | `.cursor/rules/workspace.mdc`. Без ключа `DEV-*`, LSP, Unit, Jenkins, Sonar |
| BSL, метаданные, тесты TB | `repos/conf-main` или его worktree | `.cursor/rules/critical-flow.mdc` и `repos/conf-main/AGENTS.md` |
| Расширения | `repos/extensions` или его worktree | `critical-flow.mdc` и `AGENTS.md` этого репо |
| OpenAPI | `repos/api-swagger` | `critical-flow.mdc` и `AGENTS.md` этого репо |

«Обновись с основного репозитория» про оболочку — `tools/scripts/update-cfg-development-shell.ps1` (`docs/setup/shell-sync.md`): в старте задачи и раз в сутки, отдельно на ноутбуке и на `TB-PC`. Эталон GitLab подтягивать отдельно, когда задача в продуктовом репо.

Runbook'и LSP, Unit, Jenkins и сети — в [`docs/setup/`](docs/setup/). В ответ их не копировать. EDT сейчас не используем.

## Роли

| Роль | Skill | Когда |
|------|-------|--------|
| Проджект-менеджер | `1c-project-manager` | План и постановка; исполнителей слать на `TB-PC` |
| Аналитик | `1c-analyst`, `requirements-writer` | ТЗ, user stories; FNC/ARC — canvas |
| Архитектор | `1c-architect` | Метаданные, интеграции, ADR |
| Разработчик | `1c-developer` | BSL и формы в `repos/<id>/` |
| Ревьюер | `1c-reviewer` | Ревью по rules целевого репо |
| Тестировщик | `1c-tester` | `repos/<id>/tests/` |

Маршрутизация ролей и места артефактов — `.cursor/rules/multi-agent.mdc`. Состав навыков — [`docs/setup/ai-rules.md`](docs/setup/ai-rules.md) и [`docs/setup/cc-1c-skills.md`](docs/setup/cc-1c-skills.md). Каталог `cf-*` / `db-*` / `form-*` вызывать по имени.

Перед push продуктовой ветки заполни [`docs/setup/pre-push-gate.md`](docs/setup/pre-push-gate.md).

## Границы

- Один change set — один репозиторий, если нет явного кросс-репо плана.
- Реализация, ревью, LSP и локальный Unit по контуру 1С — на `TB-PC` (`.cursor/rules/pm-orchestration.mdc`). EDT не используем.
- Статусы Jira не менять (`.cursor/rules/jira-no-status-transitions.mdc`).
- Ключ `DEV-XXXXXX` обязателен в продуктовых ветках, коммитах и MR (`.cursor/rules/dev-task-key-required.mdc`).
- Секреты только в `.env`, `.env.*`, `secrets/`, `credentials.*` корня workspace. В правила, логи и MR их не копировать.

## Приоритет правил

1. `.cursor/rules/` репозитория, в котором лежит файл
2. `repos/<id>/AGENTS.md`
3. `.cursor/rules/` этой оболочки
4. Skills ролей
