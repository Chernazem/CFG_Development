# TB — workspace 1С (мультирепозиторий + мультиагент)

Рабочая область для разработки **нескольких конфигураций 1С**. Корень — git-репозиторий [Chernazem/CFG_Development](https://github.com/Chernazem/CFG_Development). Это основной репозиторий **флоу, skills, скриптов и правил**. Исходники конфигураций лежат в `repos/<id>/` и в этот репозиторий не коммитятся.

## Структура

```
TB/                              # оболочка workspace, git@github.com:Chernazem/CFG_Development.git
├── TB.code-workspace            # multi-root: добавляйте repos/<id>
├── AGENTS.md                    # карта оболочки и ролей
├── agents/roles.yaml            # указатель на AGENTS.md
├── .cursor/
│   ├── rules/                   # только workspace (не BSL конкретной базы)
│   └── skills/                  # общие роли: аналитик, разработчик, …
├── docs/                        # кросс-репозиторные ТЗ, ADR, индекс
├── repos/
│   ├── manifest.yaml            # реестр репозиториев
│   └── <id>/                    # каждый — отдельный git
│       ├── AGENTS.md            # правила ЭТОЙ конфигурации
│       ├── src/
│       └── docs/
└── tools/scripts/               # общие скрипты (clone all, CI matrix)
```

## Репозитории (3)

| id | Назначение |
|----|------------|
| `conf-main` (**TB**, **ТБ**) | [GitLab 1c/TB](https://gitlab.centrofinans.ru/1c/TB) — конфигурация + тесты (клон в `repos/conf-main/`) |
| `extensions` (**TB_ext**) | [1c/TB_ext](https://gitlab.centrofinans.ru/1c/TB_ext) → `repos/extensions/` |
| `api-swagger` (**tb_api**) | [1c/tb_api](https://gitlab.centrofinans.ru/1c/tb_api) → `repos/api-swagger/` |

## Оболочка на другой машине

Канон флоу, skills, скриптов и правил — private-репозиторий [Chernazem/CFG_Development](https://github.com/Chernazem/CFG_Development). Обновление оболочки: `git pull` в корне. Эталоны TB / TB_ext / tb_api обновляются отдельно, см. `docs/setup/gitlab.md`.

```powershell
git clone git@github.com:Chernazem/CFG_Development.git TB
```

Дальше по `repos/manifest.yaml` отдельно клонируются `conf-main`, `extensions` и `api-swagger` из GitLab. В этот репозиторий не входят клоны, каталоги `DEV-*`, `.tools`, базы, `.env` и `secrets`.

## Быстрый старт

1. Откройте `TB.code-workspace` в Cursor (корень + три репо).
2. В чате: «в `conf-main` как разработчик…» или «в `api-swagger` обнови path …».
3. DEV-задачи ведите в `repos/DEV-123 conf-main`, не в эталоне `repos/conf-main`.

## Где что лежит

| Что | Где |
|-----|-----|
| Правила конкретной базы | `repos/<id>/AGENTS.md` и при наличии `repos/<id>/.cursor/rules/` |
| Общие роли агентов | `.cursor/skills/` |
| Дополнительные проектные AI-навыки | `docs/setup/ai-rules.md`, `docs/setup/cc-1c-skills.md` и `.cursor/skills/` |
| MCP для RAG по структуре 1С | `docs/setup/mcp-1c-v1.md`, `.tools/mcp-1c-v1/`, `.cursor/mcp.json` |
| HTTP-запросы к данным 1С для LLM | `docs/setup/1c-llm-requests.md`, `.tools/1c-llm-requests/`, `tools/scripts/query-1c-llm-requests.ps1` |
| Сквозное ТЗ | `docs/requirements/` |
| Локальное ТЗ репо | `repos/<id>/docs/requirements/` |
| Исходники 1С | `repos/<id>/src/` |

## Следующие шаги

- [x] Клонировать `conf-main`, `extensions`, `api-swagger` из `repos/manifest.yaml`
- [ ] Открыть `TB.code-workspace` в Cursor (multi-root)
- [ ] Восстановить `.tools/1c-lsp`, `.tools/mcp-1c-v1`, `.tools/1c-llm-requests` по `docs/setup/`
- [ ] Завести локальный `.env` (Jira / Confluence search / Unit CI)
- [ ] Авторизовать проектные MCP Confluence и Graylog, если нужны в чате
