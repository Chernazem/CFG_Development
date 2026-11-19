# TB-PC: GitLab / Jenkins без окна Credential Manager

Агенты на `TB-PC` **не должны** видеть UI Git Credential Manager. Известный блокер SCREEN: диалоги GCM на `gitlab.centrofinans.ru` **и** на `jenkins.centrofinans.ru` (агент зависает, пока кто-то не кликнет).

## Почему всплывает GCM

1. Worker / агент под пользователем **без** записи CredMan для нужного host.
2. PAT/пароль истёк — GCM открывает окно.
3. В окружении агента нет `GCM_INTERACTIVE=never` → helper может запросить UI даже в non-TTY.
4. Скрипты/агент дергают `https://jenkins.centrofinans.ru/...` через git credential helper (или GCM как generic store) — нужен отдельный seed для Jenkins, не только GitLab.

Канон GitLab: [gitlab.md](gitlab.md). Транспорт: [codex-automations-access.md](codex-automations-access.md). Для Jenkins API предпочтителен Node `https` с явным Authorization, **не** интерактивный GCM.

## Разово на TB-PC (пользователь автологина worker)

1. Файл (не в git): `%USERPROFILE%\.cursor\tb-pc-credentials.env`

```text
GITLAB_HOST=gitlab.centrofinans.ru
GITLAB_USERNAME=a.kuznecov
GITLAB_PAT=<personal-access-token>

JENKINS_HOST=jenkins.centrofinans.ru
JENKINS_USERNAME=a.kuznecov
JENKINS_API_TOKEN=<jenkins api token или пароль>
```

Допускается старое имя `tb-gitlab.env` (скрипт читает оба).

- GitLab PAT: `read_repository` + `write_repository`.
- Jenkins: API token из user configure (предпочтительно) или пароль учётки, которой хватает на job `TB/TB`.

2. Запуск:

```powershell
cd "D:\Dev Projects\TB"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\scripts\setup-tb-pc-git-noninteractive.ps1
```

Скрипт:

- `git credential reject` + `approve` для GitLab **и** Jenkins;
- `credential.helper=manager`, username per host;
- в `tb-worker.env`: `GCM_INTERACTIVE=never`, `GIT_TERMINAL_PROMPT=0`, `GCM_MODAL_PROMPT=false`;
- `start-tb-cursor-worker.ps1` тоже принудительно выставляет non-interactive GCM при старте;
- проверка `git ls-remote` GitLab; опционально HEAD на Jenkins.

3. Перезапуск `TB-Cursor-Worker`.

4. Очистить PAT из `tb-pc-credentials.env` после успеха (секреты уже в CredMan).

## Проверка без UI

```powershell
$env:GCM_INTERACTIVE = 'never'
$env:GIT_TERMINAL_PROMPT = '0'
git -c http.sslbackend=openssl -c http.sslVerify=false `
  -c credential.helper=manager `
  ls-remote --heads https://gitlab.centrofinans.ru/1c/TB.git
```

Если снова UI — **не кликать** от имени агента; перезаписать CredMan скриптом.

## Таблица

| Сервис | Где | UI |
|--------|-----|-----|
| GitLab git/API | CredMan `gitlab.centrofinans.ru` | запрещён |
| Jenkins (если что-то зовёт GCM) | CredMan `jenkins.centrofinans.ru` | запрещён |
| Jenkins API в скриптах | Node + Authorization (предпочтительно) | — |
| Cursor API | `tb-worker.env` → `CURSOR_API_KEY` | — |
| Jira | CredMan `jira.centrofinans.ru` | запрещён |

Секреты не коммитить и не класть на Яндекс.Диск. Расположение диска — `docs/setup/yandex-disk.md`; для передачи оболочки он не используется.

## Если токены утеряны

Новые GitLab PAT + Jenkins API token → `tb-pc-credentials.env` → снова `setup-tb-pc-git-noninteractive.ps1` → restart worker.
