# Поток B — APNS-003 (developer, conf-main)

Jira: DEV-78067. Промпт задачи: `DEV-78067/prompts/developer.md`.
Роль: 1c-developer + 1c-test-first-development. Worker: TB-PC.
Репозиторий: repos/DEV-78067 conf-main (отдельный worktree). Не move_agent_to_root.

## Цель
Карта идентификаторов ТБ ↔ сервис для пилота (без вызова offerings/list).
Канон: implementation-plan.md APNS-003, Q-05 каналы, legacy_setting_id = Code настроек 9 знаков.

## Сделать
1. Worktree от main, ветка DEV-<KEY> (не пересекать ветку APNS-004).
2. Модуль(и) маппинга: КаналыПродаж → channel/cash_delivery/platform; вид займа → loan_kind; настройка → legacy_setting_id; пилот cashback/guarantee/sberhealth.
3. «Не указан» канал — не маппить в shadow.
4. Unit на таблицу соответствий / граничные значения.
5. Unit через `invoke-conf-main-local-unit.ps1` (`docs/setup/local-unit-ci.md`); код — LSP (`docs/setup/lsp-task-clones.md`).
5a. Обязателен LSP на task-клоне (`docs/setup/lsp-task-clones.md`), все правила включены. Затем MR.
6. SonarQube Quality Gate по MR = **OK** (`docs/setup/sonarqube-quality-gate.md`); иначе фикс и новый цикл Jenkins.

## Не делать
HTTP list/observations; журнал APNS-004; правки в чужой ветке A.
