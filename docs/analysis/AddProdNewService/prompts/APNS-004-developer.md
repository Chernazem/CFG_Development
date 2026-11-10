# Поток A — APNS-004 (developer, conf-main)

Jira: DEV-78068. Промпт задачи: `DEV-78068/prompts/developer.md`.
Роль: 1c-developer + 1c-test-first-development. Worker: TB-PC.
Репозиторий: repos/DEV-78068 conf-main (worktree). Не move_agent_to_root.

## Цель
Журнал интеграции доппродуктов + отправка `POST /api/v1/parity/observations`.
Канон: docs/analysis/AddProdNewService/implementation-plan.md (APNS-004), answers-round-5/6.
Инвариант fail-open: сбой сервиса/журнала не стопает выдачу (предупреждение).

## Опора
Использовать HTTP-клиент и настройки из DEV-77738 (уже в main/релизе). Имена объектов взять из эталона conf-main.

## Сделать
1. Worktree от обновлённого main, ветка DEV-<KEY>.
2. Регистр/очередь фактов: attempt_ref, external_ref, client_ref, decision_id, HTTP, outcome, тела без ПДн.
3. Сборка и POST observations (батч до 200): available/shown ключи обязательны; decision_id одна строка-UUID или null; shown_to_client из режима настроек.
4. Unit: ok / timeout / http_error / not_called; идемпотентность attempt_ref; fail-open (исключение не всплывает). **Статические данные только в XML-фикстурах** (не конструкторы в `// Дано`).
5. Очистка устаревших записей журнала: срок в днях в настройках интеграции; автоочистка, чтобы JSON не раздувал ИБ (см. implementation-plan APNS-004 «Хранение журнала»).
5a. Unit на TB-PC через **старый флоу** `tools/scripts/invoke-conf-main-local-unit.ps1` (`docs/setup/local-unit-ci.md`), **без EDT MCP**.
5b. **Обязательно LSP** (локальная замена Sonar): проект task-клона по `docs/setup/lsp-task-clones.md`, все правила диагностики включены; перед push — diagnostics по изменённым модулям. Self-review по AGENTS.md. Push + MR + Jenkins heartbeat 30m.
6. **Обязательно:** SonarQube Quality Gate по MR = **OK** (`docs/setup/sonarqube-quality-gate.md`). Красный QG — блокер: фикс → push → новый мониторинг. Готовность только при зелёном QG.

## Не делать
list/select/confirm/payment; APNS-003 карту (другая ветка); APNS-005; ПДн в observations.
