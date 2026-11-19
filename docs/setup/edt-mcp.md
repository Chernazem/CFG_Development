# EDT MCP на TB-PC (архив)

Этот runbook не канон и не выполняется. Проверка кода — [`lsp-task-clones.md`](lsp-task-clones.md). Локальный Unit — [`local-unit-ci.md`](local-unit-ci.md).

Ниже сохранены прошлые заметки по плагину [DitriXNew/EDT-MCP](https://github.com/DitriXNew/EDT-MCP). По ним задачи не вести.

Источник правды в git по-прежнему XML-выгрузка (`src/cf`, `src/tests`). EDT на контуре индексирует эти каталоги и гоняет проверки/тесты; в git не коммитить `.project` / `.settings` / `.metadata` / `.edt-workspace`.

MCP слушает **localhost TB-PC** (`http://127.0.0.1:8765/mcp`). С ноутбука PM этот URL недоступен — проверка только у агентов на My Machines.

## Архивная таблица перехода

Не применять. Колонка «Стало» описывает отказ от LSP в пользу EDT и текущему канону не соответствует.

| Было | Стало (архив) |
|------|----------------|
| LSP-проект на `repos/DEV-* <id>/src` | EDT-проекты в workspace `.edt-workspace`, location = XML-корни task-клона |
| `lsp-skill diagnostics` | `get_problem_summary` + `get_project_errors` (фильтр по изменённым объектам) |
| `invoke-conf-main-local-unit.ps1` | `update_database` (если нужно) → `run_yaxunit_tests` → `get_job_status` |
| `genericExecution.xml` Vanessa-ADD | JUnit/`report.md` YAXUnit рядом с запуском; копия в `DEV-123/` |

Внешний Jenkins не меняется.

## Требования

- 1C:EDT **2026.1+** для текущего плагина; для EDT 2025.x — плагин **v1.26.1**.
- Платформа 1С как в `repos/manifest.yaml` (TB: 8.3.27).
- Плагин `com.ditrix.edt.mcp.server.feature.feature.group` с update site `https://ditrixnew.github.io/EDT-MCP/`.
- В **Window → Preferences → MCP Server**: Auto-start, порт **8765**, **Plain text mode (Cursor compatibility)**.
- В `1cedt.ini` после `-vmargs`: `-DnativeFormBufferedLayoutRender=true` (скриншоты форм).
- Для автоагентов: `EDT_MCP_DESTRUCTIVE_CONSENT=allow` в окружении процесса EDT.
- В тестовой ИБ установлено расширение **YAXUnit** (без него `run_yaxunit_tests` не даст JUnit).

## Каталоги на TB-PC

Корень workspace: `D:\Dev Projects\TB`.

| Что | Путь |
|-----|------|
| EDT workspace | `D:\Dev Projects\TB\.edt-workspace` |
| XML основной конфигурации (эталон — не для правок задачи) | `repos\conf-main\src\cf` |
| XML тестов (эталон) | `repos\conf-main\src\tests` |
| Task-клон | `repos\DEV-<key> conf-main\src\cf` и `...\src\tests` |

Имена EDT-проектов для задачи `DEV-123`: `DEV-123-TB` (конфигурация) и `DEV-123-tests` (расширение тестов). Не индексировать эталон `repos/conf-main`, если параллельно открыт task-клон той же конфигурации.

Если EDT не умеет держать проект *на* XML-каталоге (linked location), импортировать через `import_configuration_from_xml` во внутренний проект EDT и после правок в git делать повторную синхронизацию. Предпочтительный режим — linked project на каталог worktree, чтобы диагностика видела те же файлы, что уйдут в commit.

Несколько экземпляров EDT: [edt-mcp-proxy](https://github.com/DitriXNew/EDT-MCP/tree/master/proxy) на порту 8764.

## Установка плагина (закрыть EDT)

```bat
set VER_EDT=<фактическая версия, каталог рядом с 1cedt.exe>
"<path>\1cedt.exe" -nosplash ^
    -application org.eclipse.equinox.p2.director ^
    -repository https://ditrixnew.github.io/EDT-MCP/ ^
    -installIU com.ditrix.edt.mcp.server.feature.feature.group ^
    -profileProperties org.eclipse.update.reconcile=true
```

Запуск EDT:

```bat
"<path>\1cedt.exe" -data "D:\Dev Projects\TB\.edt-workspace" -nl ru
```

Проверка: `http://127.0.0.1:8765/mcp` отвечает, в Cursor на TB-PC сервер `edt` в статусе connected. Инструмент `get_edt_version` / `get_server_status` возвращает версии EDT и плагина.

Подключение в `.cursor/mcp.json` (формат этого workspace — ключ `servers`):

```json
"edt": {
  "url": "http://localhost:8765/mcp"
}
```

На ноутбуке PM этот сервер будет disconnected — это ожидаемо.

## Проверка кода (вместо LSP)

Перед правками, перед сборкой/накатом и перед push. Диагностика эталона не засчитывается.

1. Убедиться, что EDT-проекты задачи в `list_projects` и не в состоянии «ещё индексируется».
2. После правок BSL/метаданных: `revalidate_objects` по затронутым объектам (если маркеры зависли — `clean_project`).
3. `get_problem_summary` с `projectName` задачи.
4. `get_project_errors` с `severity: "ERRORS"` и фильтром `objects` / `objectFqns` по изменённым объектам (лимит 1000). Для BSL в ответе есть Module path + Line.
5. Новые ERRORS, внесённые задачей, исправить. Фоновые ошибки эталона — с evidence, как для Jenkins `UNSTABLE`.

Канон проверки кода — `lsp-skill diagnostics`. Этот архив его не отменяет.

## Unit (архив, не канон)

Нужны: EDT-приложение на тестовую ИБ, launch configuration, YAXUnit в ИБ, в workspace проекты конфигурации и `src/tests`.

Первый прогон / после правок вне EDT:

```
get_applications
→ update_database(projectName, applicationId, confirm: true)  # если updateState требует
→ run_yaxunit_tests
```

Типичный вызов по задаче:

- `projectName` + `applicationId` **или** `launchConfigurationName`
- `extensions`: имя тестового расширения
- `modules` / `tests`: только кейсы задачи (`Модуль.Метод`)
- `updateBeforeLaunch`: true (по умолчанию)
- `externalInfobaseChanges`: `override` (не затирать XML в git импортом из ИБ)

Старт `run_yaxunit_tests` ждёт не больше 45 с. Если Pending — опрашивать `get_job_status` с `jobId` (не повторять старт с теми же аргументами). Фаза, которая не двигается десятки минут, часто модальный диалог EDT — смотреть UI, не крутить poll бесконечно.

Отчёт: JUnit + `report.md`. Свежий отчёт должен содержать все новые/изменённые testCase задачи. Копию положить в `DEV-123/`.

Канон локального Unit — `invoke-conf-main-local-unit.ps1`. Блок выше не запускать.

## Pre-push (фрагмент)

```text
- EDT MCP: <plugin/EDT version, get_server_status>
- EDT projects: <DEV-123-TB, DEV-123-tests, not indexing>
- Code check: get_project_errors ERRORS on changed objects — none / list
- Unit: run_yaxunit_tests jobId=… report=<path> — all new/changed tests present
```

## Волны внедрения

1. Инвентаризация EDT/Java/платформы, установка плагина, auto-start + plain text, MCP на 8765, smoke `get_edt_version`.
2. Workspace `.edt-workspace`, проекты на XML task-клона или эталона для smoke, `list_projects` / `get_problem_summary`.
3. Тестовая ИБ + YAXUnit + launch config, один узкий `run_yaxunit_tests`.
4. Агенты разработки ходят только через этот runbook; LSP/vrunner — fallback.
