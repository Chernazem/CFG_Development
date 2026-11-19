# Скрипты workspace

Скрипты оболочки `CFG_Development`: локальный Unit, worker TB-PC, обновление оболочки с `origin` и доступ к данным 1С. Клоны продуктовых репозиториев заводятся по `repos/manifest.yaml` и `docs/setup/gitlab.md`, не отдельным скриптом из этой папки.

Репозиторий-специфичные скрипты — в `repos/<id>/tools/` (создайте при необходимости).

## Локальный CI

- `invoke-conf-main-local-unit.ps1` — общий локальный контур Unit для эталонного `repos/conf-main` и task-клонов основной конфигурации. Скрипт повторяет порядок продуктивной Jenkins-сборки: чистая файловая ИБ из `src/cf`, файл поставки, БСП, тестовое расширение, первый запуск/обновление ИБ, syntax-check, загрузка поставляемых данных, Unit. Артефакты по умолчанию размещаются вне репозитория в `.local-ci/conf-main`.

Reusable CI-скрипты хранить здесь, в `tools/scripts/`. В task-каталогах `DEV-*` должны оставаться только временные базы, логи, отчеты, локальные патчи и прочие одноразовые артефакты конкретной задачи.

## Оболочка CFG_Development

- `update-cfg-development-shell.ps1` — `git fetch` и fast-forward корня workspace на `origin/main`. Запуск в старте задачи и раз в сутки на каждой машине. Канон: `docs/setup/shell-sync.md`.

## Яндекс.Диск

Не использовать для правил, skills и скриптов. Только большие файлы или явный запрос. Пути и поиск корня `_AI`: `docs/setup/yandex-disk.md`, `Find-TbYandexAiDir.ps1`. `sync-tb-workspace-yandex.ps1` сам не запускать.

## Worker My Machines

- `install-tb-cursor-worker.ps1` / `start-tb-cursor-worker.ps1` — worker на TB-PC.
- `apply-tb-worker-proxy-from-cursor-settings.ps1` — HTTPS_PROXY в `tb-worker.env` из Cursor `http.proxy` (+ `-RestartWorker`).
- `fix-tb-cursor-worker-proxy.bat` / `.ps1` — прокси из настроек Cursor и перезапуск worker на TB-PC. Запускать из клона `CFG_Development`.
- `launch-tb-machine-agent.ps1` — постановка Cloud Agent на машину `TB-PC`.

## Codex / Cursor automations

- `repair-codex-automation-git-acl.ps1` — общий preflight для automation перед git-операциями: чинит DACL `.git`, удаляет stale `index.lock` при отсутствии активных git-процессов и проверяет `git add -A --dry-run`. Для ручного elevated-обслуживания можно добавить `-FixPackFiles`.

## Данные 1С и RAG

- `query-1c-llm-requests.ps1` — fallback запроса к ИБ, если MCP `execute_1c_query` недоступен. Канон: `docs/setup/1c-llm-requests.md`.
- `start-mcp-1c-v1.ps1`, `status-mcp-1c-v1.ps1`, `stop-mcp-1c-v1.ps1` — локальный RAG по структуре 1С. Канон: `docs/setup/mcp-1c-v1.md`.
