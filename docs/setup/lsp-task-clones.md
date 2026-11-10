# LSP для task-клонов

На TB-PC при недоступном EDT MCP LSP (`lsp-skill` / `bsl-language-server`) — **обязательный** локальный контроль качества кода (замена Sonar до внешней Jenkins-сборки), **наравне** с `invoke-conf-main-local-unit.ps1`. Внешний SonarQube Quality Gate по MR остаётся обязательным после push (`docs/setup/sonarqube-quality-gate.md`).

Когда EDT MCP готов — канон проверки кода снова EDT MCP (`docs/setup/edt-mcp.md`); LSP остаётся допустимым доп. контуром.

Эта инструкция описывает настройку `lsp-skill` / `bsl-language-server` для task-клонов workspace TB.

`<workspace-root>` — корень текущего workspace на ноутбуке или `D:\Dev Projects\TB` на TB-PC. Бинарь LSP кладётся в `.tools/1c-lsp/`.

## Правила диагностики сервиса

В настройках LSP / bsl-language-server на агентской машине должны быть **включены все правила проверки** (полный набор diagnostics, без урезанного «тихого» профиля). Перед задачей разработчик/агент подтверждает evidence: UI/конфиг сервиса или API настроек — все rules enabled. Отключение правил без явного решения команды запрещено.

## Когда создавать проект

Для каждого task-клона (git worktree `repos/DEV-* <id>/`) с исходниками 1С нужно создать отдельный LSP-проект, указывающий именно на этот каталог, а не на эталон.

Правило обязательно для всех каталогов вида `repos/DEV-* <repo-id>`, где есть BSL/XML-выгрузка 1С.

Для task-клона основной конфигурации TB:

- `project_root_path = <workspace-root>`;
- `root_path = repos\DEV-123 conf-main\src`.

Такой проект одновременно индексирует `src/cf` и `src/tests`. Не разделяй их на разные LSP-проекты: раздельная индексация дает ложные `MissingCommonModuleMethod` на вызовы модулей основной конфигурации из тестов.

Для других репозиториев выбирай минимальный общий каталог, внутри которого находятся взаимозависимые BSL-корни. Независимые выгрузки можно разделять.

## Запуск сервера

Проверь, что CLI установлен в PATH:

```powershell
lsp-skill --help
```

Если команда недоступна, добавь CLI из поставки workspace:

```powershell
.tools\1c-lsp\x86_64-pc-windows-msvc\lsp-skill.exe install-path
```

Проверь сервер и Web UI:

```powershell
Get-Process lsp-skill-server -ErrorAction SilentlyContinue
Invoke-WebRequest -UseBasicParsing -Uri http://127.0.0.1:4000 -TimeoutSec 3
```

Если процесса нет или порт `4000` не отвечает, запусти сервер:

```powershell
Start-Process `
  -FilePath ".tools\1c-lsp\x86_64-pc-windows-msvc\lsp-skill-server.exe" `
  -WorkingDirectory "<workspace-root>" `
  -WindowStyle Hidden
```

Web UI доступен по адресу `http://127.0.0.1:4000`.

## Создание проекта

1. В Web UI добавь отдельный проект для task-клона.
2. Укажи `project_root_path` как корень workspace `<workspace-root>` или каталог задачи, если агент будет запускать CLI оттуда.
3. Укажи `root_path` как BSL/XML-корень task-клона.
4. Запусти проект и дождись состояния `running` или `warming_up`. Для финальной проверки дождись завершения индексации.
5. Скопируй `PROJECT_ID` созданного проекта.
6. Сохрани `PROJECT_ID` в локальном `.env` рядом с рабочим контекстом агента, например `DEV-123\.env`.

Формат:

```dotenv
PROJECT_ID=<id LSP-проекта task-клона>
```

Проверь привязку:

```powershell
lsp-skill status
```

Статус должен относиться именно к task-клону, а не к эталонному `repos/conf-main`.

## Пути и MCP

В командах `lsp-skill diagnostics`, `symbols`, `definition`, `references` и других передавай пути относительно `project_root_path`, а не абсолютные.

Пример при `project_root_path = <workspace-root>`:

```powershell
lsp-skill diagnostics "repos/DEV-123 conf-main/src/cf/CommonModules/Пример/Ext/Module.bsl"
```

Для MCP-подключения используй тот же `PROJECT_ID` в заголовке `x-project-id`:

- диагностика: `http://127.0.0.1:9011/mcp`;
- навигация: `http://127.0.0.1:9012/mcp`.

Если LSP-проект task-клона не создан и не запущен, подготовка задачи считается незавершенной.
