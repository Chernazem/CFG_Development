# 1c-llm-requests

Источник: [FSerg/1c-llm-requests](https://github.com/FSerg/1c-llm-requests), ветка `main`.

Локальный клон лежит в `.tools/1c-llm-requests`, commit `8f8bada`. Это расширение 1С `АПРО_ВнешниеЗапросы`, которое публикует HTTP-сервис для выполнения запросов 1С и возвращает результат в TSV.

## Что внутри

| Путь | Назначение |
|------|------------|
| `.tools/1c-llm-requests/build/АПРО_ВнешниеЗапросы - 1.03.cfe` | Готовое расширение для подключения к ИБ. |
| `.tools/1c-llm-requests/src/` | Исходники расширения в файловой выгрузке. |
| `.tools/1c-llm-requests/src/HTTPServices/АПРО_ВЗ_HTTPЗапросы/Ext/Module.bsl` | HTTP API: `health`, `query`, выполнение запроса и TSV. |
| `.tools/1c-llm-requests/docs/default.vrd` | Пример публикации для клиент-серверной базы. |
| `.tools/1c-llm-requests/docs/publication.yaml` | Пример публикации для автономного сервера `ibsrv`. |
| `.tools/1c-llm-requests/.claude/skills/1c-queries/` | Авторский Claude-skill и скрипты; в TB не импортирован, чтобы не конфликтовать с текущим `.cursor/skills/1c-queries`. |

## HTTP API

При публикации сервис доступен по `/hs/queries`.

- `GET /hs/queries/health` возвращает `{"result":"ok"}`.
- `POST /hs/queries/query` принимает JSON `{ "query": "..." }` и возвращает TSV.

Пример вызова через проектный скрипт:

```powershell
$env:ONEC_QUERY_URL = "http://localhost:8314/hs/queries/query"
$env:ONEC_QUERY_LOGIN = "tech_llm"
$env:ONEC_QUERY_PASSWORD = "<password>"

.\tools\scripts\query-1c-llm-requests.ps1 -Health
.\tools\scripts\query-1c-llm-requests.ps1 -Query "ВЫБРАТЬ ПЕРВЫЕ 10 Код, Наименование ИЗ Справочник.Номенклатура"
```

Можно передать параметры явно:

```powershell
.\tools\scripts\query-1c-llm-requests.ps1 `
  -Url "http://localhost:8314/hs/queries/query" `
  -Login "tech_llm" `
  -Password "<password>" `
  -QueryFile ".\temp\query.sql"
```

## Когда применять

- Нужно быстро исследовать данные ИБ для расследования ошибки проведения, расчета, обмена или интеграции.
- Нужно проверить гипотезу запросом 1С, когда обычного LSP/поиска по исходникам недостаточно.
- Полезно вместе с `mcp-1c-v1`: сначала уточнить метаданные через RAG/MCP, затем выполнить ограниченный запрос к данным.

## Ограничения безопасности

- Сервис читает данные ИБ от имени пользователя Basic Auth. Не подключать под пользователем с лишними правами.
- Не публиковать наружу без сетевых ограничений, TLS/прокси и отдельного технического пользователя.
- В запросах всегда использовать `ПЕРВЫЕ N` и узкие условия отбора.
- Не сохранять пароли в репозитории. Использовать переменные окружения или локальные `.env`, которые игнорируются git.
- Считать данные персональными/конфиденциальными и не отправлять результаты во внешние модели без разрешения.

## Связь с текущим skill `1c-queries`

В workspace есть `.cursor/skills/1c-queries` из `1c/ai_rules`. Предпочтительный транспорт — MCP `execute_1c_query`. Если этого инструмента нет в сессии, используй этот HTTP-скрипт. Авторский Claude-skill из `1c-llm-requests` оставлен как справка в `.tools/1c-llm-requests/.claude/skills/1c-queries/` после restore клона.
