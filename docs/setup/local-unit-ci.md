# Локальный CI и Unit-тесты conf-main

**Канон на TB-PC** — скрипт ниже (vrunner / Vanessa-ADD). EDT MCP не использовать.

Канонический reusable-скрипт:

```powershell
tools\scripts\invoke-conf-main-local-unit.ps1
```

Скрипт запускать из workspace или с явными параметрами `-RepoRoot` и `-ArtifactsRoot`. Все артефакты задачи хранить в корневом каталоге задачи `DEV-123/` или в общем `.local-ci`, но не в репозитории и не в task-клоне.

## Первичный чистый прогон

1. Взять готовый `dt` из внешней Jenkins-сборки `main/lastSuccessfulBuild`:
   `https://jenkins.centrofinans.ru/job/TB/job/TB/job/main/lastSuccessfulBuild/artifact/bin/1cv8.dt`.
2. Скачать `dt` только для текущего чистого прогона и использовать его только для разворачивания базы. Не хранить `dt` как локальный кэш и не переиспользовать между задачами или днями.
3. Пересоздать локальную файловую базу из `dt`.
4. Не выполнять локально первый запуск. Первый запуск, регламентные обновления пустой базы, загрузка `ТБ_БСП` и тестового расширения выполняются при сборке внешнего `dt`.
5. Локально выполнить только загрузку поставляемых данных.
6. Обновить основную конфигурацию базы из текущего `src/cf` task-клона через `UpdateConfig`: `vrunner make-dist --src src/cf`, затем `vrunner load`, затем `vrunner updatedb`.
7. Обновить тестовое расширение из текущего `src/tests`.
8. Запустить Unit через Vanessa-ADD.

Команда:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "tools\scripts\invoke-conf-main-local-unit.ps1" `
  -Phase All `
  -RepoRoot "repos\DEV-123 conf-main" `
  -ArtifactsRoot "DEV-123\local-ci"
```

`-SkipUpdateConfigFromSources` допустим только для редкой диагностики ровно внешнего `dt` + локального тестового расширения. Для проверки задачи его не использовать.

## Повторные прогоны на той же базе

Если изменялся только `src/tests`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "tools\scripts\invoke-conf-main-local-unit.ps1" `
  -Phase UpdateTests `
  -RepoRoot "repos\DEV-123 conf-main" `
  -ArtifactsRoot "DEV-123\local-ci"

powershell -NoProfile -ExecutionPolicy Bypass `
  -File "tools\scripts\invoke-conf-main-local-unit.ps1" `
  -Phase RunUnit `
  -RepoRoot "repos\DEV-123 conf-main" `
  -ArtifactsRoot "DEV-123\local-ci"
```

Если изменялся `src/cf`, сначала обновить основную конфигурацию базы, затем тестовое расширение и Unit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File "tools\scripts\invoke-conf-main-local-unit.ps1" `
  -Phase UpdateConfig `
  -RepoRoot "repos\DEV-123 conf-main" `
  -ArtifactsRoot "DEV-123\local-ci"

powershell -NoProfile -ExecutionPolicy Bypass `
  -File "tools\scripts\invoke-conf-main-local-unit.ps1" `
  -Phase UpdateTests `
  -RepoRoot "repos\DEV-123 conf-main" `
  -ArtifactsRoot "DEV-123\local-ci"

powershell -NoProfile -ExecutionPolicy Bypass `
  -File "tools\scripts\invoke-conf-main-local-unit.ps1" `
  -Phase RunUnit `
  -RepoRoot "repos\DEV-123 conf-main" `
  -ArtifactsRoot "DEV-123\local-ci"
```

`UpdateConfig` должен использовать `vrunner make-dist --src src/cf`, затем `vrunner load`, затем `vrunner updatedb`. Не использовать `ibcmd config load/apply`: на локальной файловой базе TB этот путь зависает и не является поддерживаемым локальным flow.

## Отчеты

Основные отчеты:

- `repos\DEV-123 conf-main\.temp\genericExecution.xml`;
- `repos\DEV-123 conf-main\.temp\xunit\allure`.

После каждого прогона нужно разобрать список падений из `genericExecution.xml` и отделить:

- падения по изменяемой подсистеме;
- неидемпотентность тестов при повторном запуске на той же базе;
- загрязнение данных предыдущим прогоном;
- внешние интеграционные причины;
- реальные регрессии `src/cf` или `src/tests`.

Падения вне изменяемой подсистемы не исправлять попутно без явной договоренности. Зафиксировать их в статусе задачи.

Если повторный запуск на той же базе дает дубли пользователей, логинов, заявок, регистров, очередей или документов, сначала чинить очистку собственных fixture-данных теста в секции `// Дано`.
