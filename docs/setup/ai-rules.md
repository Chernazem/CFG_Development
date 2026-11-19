# AI rules и дополнительные навыки

Источник отдела: [1c/ai_rules](https://gitlab.centrofinans.ru/1c/ai_rules), ветка `main`.
Локальный клон для сверки: `.tools/ai_rules` (не править как рабочую копию задачи).

Дополнительный каталог XML/ИБ-операций: [`cc-1c-skills`](cc-1c-skills.md).

## Cursor-навыки из `.cursor/skills/` отдела

| Skill | Когда использовать |
|-------|--------------------|
| `1c-project-manager` | План и постановка задач; исполнители на My Machines worker, не локальные субагенты этого ПК. |
| `1c-queries` | Запросы к ИБ: MCP `execute_1c_query` или fallback `tools/scripts/query-1c-llm-requests.ps1`. |
| `1c-external-epf-authoring` | Внешние обработки `epf`, структура выгрузки, `vrunner compileepf`. |
| `1c-test-first-development` | Test-first доработки с YaxUnit; на TB-PC проверка кода — LSP, Unit — `invoke-conf-main-local-unit.ps1`. |
| `requirements-writer` | Постановка FNC/ARC в стиле Confluence, результат — Cursor Canvas. |
| `confluence-wiki-search` | Семантический поиск по wiki через n8n webhook. |
| `1c-bsp-check` | Проверка значения параметра только `ОбщегоНазначенияКлиентСервер.Проверить`. |
| `1c-bsp-check-parameter` | Проверка типа только `ОбщегоНазначенияКлиентСервер.ПроверитьПараметр`. |
| `1c-public-api-param-types` | Где в публичном API тип обязателен, значение желательно. |
| `1c-form-secret-edit` | Секрет на форме не уходит на клиент (GUID-маска + флаг `…Изменен`). |
| `1c-sql-translate` | SQL из ТЖ DBMSSQL → имена метаданных по снимку `*_dbschema`. |
| `1c-graylog-find-query` | Найти исходный запрос 1С по сообщению Graylog (Sql + Context). |
| `web-test-tb` | Нюансы web-test TB: одна browser-сессия, файловые `.mjs`, логин и открытие EPF. |

Отдельский plugin также описывает OAuth MCP: GitLab, Jira, Confluence, Graylog (`plugin/mcp.json`). В этот workspace в `.cursor/mcp.json` добавлены Confluence и Graylog; GitLab/Jira обычно уже подключены как user MCP.

## Как обновлять

1. `git -C .tools/ai_rules pull` (VPN, `http.sslbackend=openssl`).
2. Сравнить `.tools/ai_rules/.cursor/skills/` и `.tools/ai_rules/plugin/skills/` с `.cursor/skills/`.
3. Переносить осознанно, не затирая локальные адаптации TB (пути workspace, fallback 1c-queries, canvas FNC/ARC).
4. После обновления сверить этот файл, `AGENTS.md` и `.cursor/rules/workspace.mdc`.
