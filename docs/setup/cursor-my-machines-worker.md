# Cursor My Machines worker на ПК контура TB

Субагенты выполняют инструменты на всегда включённом Windows-ПК контура. Цикл модели — в облаке Cursor.

Имя машины: `TB-PC`. Корень worker: **весь workspace TB** (`D:\Dev Projects\TB` на контуре) — мультирепозиторий, не один git.

Вложенные клоны из `repos/manifest.yaml`:

| id | путь | GitLab |
|----|------|--------|
| `conf-main` | `repos/conf-main` | `1c/TB` |
| `extensions` | `repos/extensions` | `1c/TB_ext` |
| `api-swagger` | `repos/api-swagger` | `1c/tb_api` |

Скрипт старта передаёт `--worker-dir` на корень workspace **и** на каждый `repos/*` с `.git`. В [cursor.com/agents](https://cursor.com/agents) машина часто видна только под **primary** remote (`1c/TB`) — так устроен dashboard. Агент при этом видит все три каталога. В `%USERPROFILE%\.cursor\tb-worker.log` для каждого dir пишется `origin=…`. Idle-release выключен (`--idle-release-timeout 0`).

## Прокси (обязательно вне разрешённого региона Cursor)

Worker и PM-скрипты ходят в `api.cursor.com` через корпоративный outbound proxy (тот же, что `http.proxy` в Cursor IDE на ноутбуке). Без него API отвечает `permission_denied` / region.

В `%USERPROFILE%\.cursor\tb-worker.env` на **ноутбуке и на TB-PC**:

```text
HTTPS_PROXY=http://USER:PASS@proxy-ext.centrofinans.ru:3128
HTTP_PROXY=http://USER:PASS@proxy-ext.centrofinans.ru:3128
ALL_PROXY=http://USER:PASS@proxy-ext.centrofinans.ru:3128
NO_PROXY=localhost,127.0.0.1,.centrofinans.ru,centrofinans.ru,jenkins.centrofinans.ru,gitlab.centrofinans.ru
```

Значение брать из `http.proxy` в `%APPDATA%\Cursor\User\settings.json` (не коммитить в git). `install-tb-cursor-worker.ps1` при отсутствии `HTTPS_PROXY` один раз копирует `http.proxy` из настроек Cursor на этой машине.

`start-tb-cursor-worker.ps1` **больше не сбрасывает** proxy: если переменные заданы в `tb-worker.env`, они остаются у процесса `agent worker`. Внутренние `*.centrofinans.ru` идут мимо proxy через `NO_PROXY` (OpenVPN). После правки env — перезапуск задачи `TB-Cursor-Worker`.

Устойчивость: перед стартом скрипт ждёт, пока `api2.cursor.sh` доступен через proxy; при падении `agent worker` (в т.ч. `Failed to reach the Cursor API`) крутит retry без выхода. Задача `TB-Cursor-Worker-Watchdog` раз в 5 минут поднимает worker, если процесса нет. Старый `TB-Autostart-CursorWorker` (без proxy) держать **Disabled** — иначе region 403.

На TB-PC one-shot из Яндекс `_AI` (после синхронизации папки):

- `fix-tb-cursor-worker-proxy.bat` — Apply overlay, запись proxy из `TB-workspace\secrets\cursor-https-proxy.url`, restart `TB-Cursor-Worker`.
- Рядом: `fix-tb-cursor-worker-proxy.ps1`, `fix-tb-cursor-worker-proxy.README.txt`.

`launch-tb-machine-agent.ps1` передаёт тот же proxy в `curl -x`.

Не использовать Cursor-hosted Cloud VM: там нет 1С, `ibcmd`, Jenkins VPN.

## Обмен мелкими артефактами (без Яндекс.Диска)

EPF/CFE/логи для передачи между TB-PC и основным ПК кладите в [rtifacts/exchange/](../../artifacts/exchange/README.md) и скачивайте по GitHub-ссылке. Подробности: [tb-pc-artifacts-exchange.md](tb-pc-artifacts-exchange.md).

Полный sync overlay через Яндекс (sync-tb-workspace-yandex.ps1) для skills/docs по-прежнему ок.

## GitLab без окна Credential Manager

Агенты на TB-PC не должны получать UI Git Credential Manager. PAT кладётся в Windows CredMan **пользователя автологина worker**, в `tb-worker.env` — `GCM_INTERACTIVE=never`. Канон и скрипт: [tb-pc-git-credentials.md](tb-pc-git-credentials.md).

## Один раз / смена каталога

Автологин в Windows на контуре должен быть включён.

1. Синхронизировать overlay workspace на контур через Яндекс.Диск `_AI` (правила, skills, tools, docs — не git-клоны `repos/conf-main` и т.п.):

```powershell
# на этой машине (источник):
powershell -NoProfile -File .\tools\scripts\sync-tb-workspace-yandex.ps1 -Action Export

# на TB-PC, когда Яндекс докачает `_AI\TB-workspace`
# (корень диска может быть D:\YandexDisk_a.kuznecov@ftech.io\_AI — не только D:\YandexDisk\_AI):
powershell -NoProfile -File .\sync-tb-workspace-yandex.ps1 `
  -Action Apply -WorkspaceRoot "D:\Dev Projects\TB"
```

Либо задать явно: env `TB_YANDEX_AI=D:\YandexDisk_a.kuznecov@ftech.io\_AI` (или `-YandexAiDir`). Поиск корня: `tools/scripts/Find-TbYandexAiDir.ps1`.

Вторую команду запускать из корня `_AI` (там лежит копия скрипта) либо из `_AI\TB-workspace\overlay\tools\scripts\`. Не копировать `CursorAPIKey.txt` / `.env` / `secrets`. Исходники 1С на контуре — `git pull` в `repos/*`, не через диск.

2. Personal API key: [cursor.com/dashboard/api](https://cursor.com/dashboard/api).
3. От пользователя автологина, **остановить** старый `agent worker`, затем:

```powershell
cd "D:\Dev Projects\TB"
powershell -NoProfile -File .\tools\scripts\install-tb-cursor-worker.ps1 `
  -WorkspaceRoot "D:\Dev Projects\TB" `
  -WorkerDir "D:\Dev Projects\TB" `
  -WorkerName "TB-PC"
```

Либо только перезапуск, если CLI и задача уже есть:

```powershell
# В tb-worker.env на контуре:
# TB_WORKER_NAME=TB-PC
# TB_WORKSPACE_ROOT=D:\Dev Projects\TB
# TB_WORKER_DIR=D:\Dev Projects\TB
# HTTPS_PROXY / HTTP_PROXY / ALL_PROXY / NO_PROXY — как на ноутбуке (см. раздел «Прокси»)
Stop-ScheduledTask -TaskName TB-Cursor-Worker -ErrorAction SilentlyContinue
Get-Process -Name node -ErrorAction SilentlyContinue |
  Where-Object { $_.Path -like '*cursor-agent*' } |
  Stop-Process -Force
Start-ScheduledTask -TaskName TB-Cursor-Worker
```

Если задачи ещё нет — тот же `install-tb-cursor-worker.ps1`.

4. Проверка: [cursor.com/agents](https://cursor.com/agents) → **TB-PC**, workspace `D:\Dev Projects\TB`. Лог: `%USERPROFILE%\.cursor\tb-worker.log`.

## Постановка задач

- [cursor.com/agents](https://cursor.com/agents), среда `TB-PC` (весь workspace, не только TB.git).
- Slack/GitHub: `worker=TB-PC`. Для `TB_ext` / `tb_api` не требовать совпадения с primary `1c/TB`: worker уже в корне TB. Если Cursor отвергнет «другой репозиторий» — перезапустить worker скриптом `start-tb-cursor-worker.ps1` (лишние `--worker-dir` с git origin).
- С чата PM: `tools/scripts/launch-tb-machine-agent.ps1` (`TB_WORKER_NAME=TB-PC` в `%USERPROFILE%\.cursor\tb-worker.env` на ноутбуке). По умолчанию в API **не** передаётся `repos[]` (цель — машина). `-RepoId` / `-StartingRef` попадают в префикс промпта. `-BindRepo` — старое поведение: один GitLab URL.
