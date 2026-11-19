# cc-1c-skills

Источник: [FSerg/cc-1c-skills](https://github.com/FSerg/cc-1c-skills), основной репозиторий `main`.

В workspace импортирован Cursor/PowerShell порт из ветки `port-cursor`, build commit `7fa279c354517fb1dced24424f11a7ef385620eb`. Навыки лежат в `.cursor/skills/`.

Codex/PowerShell порт есть в ветке `port-codex`; его можно использовать как источник для установки в `.codex/skills/` или плагинной упаковки, если workspace будет переводиться на project-local Codex skills.

## Группы навыков

| Группа | Skills | Для чего |
|--------|--------|----------|
| Конфигурация | `cf-init`, `cf-info`, `cf-edit`, `cf-validate` | Создание, анализ, точечная правка и проверка XML-выгрузки конфигурации. |
| Расширения | `cfe-init`, `cfe-diff`, `cfe-borrow`, `cfe-patch-method`, `cfe-validate` | Работа с CFE: scaffold, заимствования, перехват методов, сравнение и валидация. |
| Базы 1С | `db-list`, `db-create`, `db-run`, `db-update`, `db-dump-cf`, `db-dump-xml`, `db-load-cf`, `db-load-xml`, `db-load-git` | Операции с информационными базами, загрузка/выгрузка конфигураций и запуск 1С. |
| EPF/ERF | `epf-init`, `epf-dump`, `epf-build`, `epf-validate`, `erf-init`, `erf-dump`, `erf-build`, `erf-validate`, `epf-bsp-init`, `epf-bsp-add-command` | Внешние обработки и отчеты, включая описание команд БСП. |
| Формы и интерфейс | `form-add`, `form-info`, `form-edit`, `form-remove`, `form-compile`, `form-validate`, `interface-edit`, `interface-validate` | Управляемые формы, элементы, команды, реквизиты и командный интерфейс подсистем. |
| Метаданные | `meta-info`, `meta-compile`, `meta-edit`, `meta-remove`, `meta-validate`, `subsystem-info`, `subsystem-compile`, `subsystem-edit`, `subsystem-validate` | Объекты метаданных и подсистемы в XML-выгрузке. |
| Макеты, СКД, роли | `template-add`, `template-remove`, `mxl-info`, `mxl-decompile`, `mxl-compile`, `mxl-validate`, `skd-info`, `skd-edit`, `skd-compile`, `skd-validate`, `role-info`, `role-compile`, `role-validate` | Макеты, табличные документы, схемы компоновки данных и роли. |
| Web и тестирование | `web-info`, `web-publish`, `web-unpublish`, `web-stop`, `web-test`, `img-grid` | Публикации Apache, web-клиент 1С, браузерные проверки и разметка скриншотов. |
| Справка | `help-add`, `form-patterns` | Встроенная справка и паттерны компоновки управляемых форм. |

В Cursor у каталога `cf-*` / `cfe-*` / `db-*` / `epf-*` / `form-*` / `meta-*` / … стоит `disable-model-invocation: true`: агент не подгружает их сам, вызывать по имени (`cf-info`, `meta-compile`, …). Роли `1c-*` и отдельские навыки из `ai_rules` остаются auto-invoke.

## Как применять в TB

1. Сначала определить целевой репозиторий по `repos/manifest.yaml`.
2. Прочитать правила целевого репозитория: `repos/<id>/AGENTS.md` и `repos/<id>/.cursor/rules/`.
3. Использовать навыки `cc-1c-skills` как прикладные инструменты для конкретной операции с XML/ИБ/формой — явно назвать skill.
4. После правок BSL на TB-PC запускать проверку через LSP (`lsp-skill diagnostics`). EDT MCP не вызывать. Даже если сам skill проверяет XML-структуру.
5. Не использовать операции загрузки/обновления ИБ без явных параметров локальной базы пользователя.

При обновлении навыков переносить изменения из ветки `port-cursor`; ветки `port-*-py` содержат Python-варианты, но текущий импорт сделан из Windows-first PowerShell-сборки.
