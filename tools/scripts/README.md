# Скрипты workspace

Общие утилиты для всех репозиториев: массовый clone по `repos/manifest.yaml`, матричный CI, синхронизация версий платформы.

Репозиторий-специфичные скрипты — в `repos/<id>/tools/` (создайте при необходимости).

## Локальный CI

- `invoke-conf-main-local-unit.ps1` — общий локальный контур Unit для эталонного `repos/conf-main` и task-клонов основной конфигурации. Скрипт повторяет порядок продуктивной Jenkins-сборки: чистая файловая ИБ из `src/cf`, файл поставки, БСП, тестовое расширение, первый запуск/обновление ИБ, syntax-check, загрузка поставляемых данных, Unit. Артефакты по умолчанию размещаются вне репозитория в `.local-ci/conf-main`.

Reusable CI-скрипты хранить здесь, в `tools/scripts/`. В task-каталогах `DEV-*` должны оставаться только временные базы, логи, отчеты, локальные патчи и прочие одноразовые артефакты конкретной задачи.

## Overlay на контур (Яндекс.Диск `_AI`)

- `sync-tb-workspace-yandex.ps1 -Action Export` — выгрузка правил, skills, tools, docs в `_AI/TB-workspace` (без `repos/conf-main`, секретов, `DEV-*`).
- Корень `_AI` ищется автоматически (`Find-TbYandexAiDir.ps1`), в т.ч. `D:\YandexDisk_a.kuznecov@ftech.io\_AI`. Override: `TB_YANDEX_AI` или `-YandexAiDir`.
- `sync-tb-workspace-yandex.ps1 -Action Apply` — накат той же папки на workspace TB-PC (`D:\Dev Projects\TB`).

## Worker My Machines

- `install-tb-cursor-worker.ps1` / `start-tb-cursor-worker.ps1` — worker на TB-PC.
- `apply-tb-worker-proxy-from-cursor-settings.ps1` — HTTPS_PROXY в `tb-worker.env` из Cursor `http.proxy` (+ `-RestartWorker`).
- `fix-tb-cursor-worker-proxy.bat` / `.ps1` — one-shot на TB-PC из Yandex `_AI` (overlay + proxy + restart).
- `launch-tb-machine-agent.ps1` — постановка Cloud Agent на машину `TB-PC`.

## Codex / Cursor automations

- `repair-codex-automation-git-acl.ps1` — общий preflight для automation перед git-операциями: чинит DACL `.git`, удаляет stale `index.lock` при отсутствии активных git-процессов и проверяет `git add -A --dry-run`. Для ручного elevated-обслуживания можно добавить `-FixPackFiles`.
