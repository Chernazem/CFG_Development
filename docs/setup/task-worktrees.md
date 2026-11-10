# Task-клоны через git worktree

Канонический способ изоляции DEV-задачи — **linked worktree** от эталонного клона, а не второй `git clone`. Каталог тот же: `repos/DEV-123 conf-main`. EDT MCP, Unit и `.cursorignore` смотрят на путь рабочего дерева (`docs/setup/edt-mcp.md`).

Эталон `repos/<id>/` остаётся на default-ветке (для `conf-main` — `main`) и не является рабочим деревом задачи.

## Зачем

- `conf-main` большой: worktree делит объекты, LFS и refs с эталоном, не качает репозиторий заново.
- Fetch/prune достаточно сделать в эталоне.
- Скрипт ACL уже обходит `.git/worktrees/` (у worktree `.git` — файл с `gitdir:`).

## Создать

Из эталона, после `git fetch` default-ветки:

```powershell
cd repos/conf-main
git fetch origin
git worktree add --guess-remote "..\DEV-123 conf-main" -b DEV-123 origin/main
```

Если ветка `DEV-123` уже есть на remote:

```powershell
git fetch origin DEV-123
git worktree add --guess-remote "..\DEV-123 conf-main" DEV-123
```

Для `extensions` / `api-swagger` то же, с их эталоном и default-веткой (`master` / `main`).

Нельзя одновременно checkout одной и той же ветки в эталоне и в worktree. Эталон держать на default-ветке.

## Проверка

```powershell
git -C "repos/conf-main" worktree list
git -C "repos/DEV-123 conf-main" status --short --branch
```

В task-каталоге `.git` должен быть **файл** (не папка), указывающий в `repos/conf-main/.git/worktrees/...`.

## Работа

- Правки, commit, push — только в worktree.
- `git pull`/`push` в worktree обычные; `git fetch` можно в эталоне.
- EDT MCP: проекты `DEV-123-TB` / `DEV-123-tests` на `src/cf` и `src/tests` worktree (`docs/setup/edt-mcp.md`).
- Unit: `run_yaxunit_tests` по этим проектам; запасной vrunner — `-RepoRoot` на каталог worktree.
- Не открывать эталон и worktree как два равноправных корня для правок одной задачи.
- Чат агента остаётся в корневом workspace TB. Не вызывать `move_agent_to_root` / `move_agent_to_cloned_root` и не открывать `repos/DEV-*` как новый корень агента: иначе чат пропадёт из списка мультирепо-проекта.

## Снять

После явного «задача завершена», если дерево чистое и ветка запушена (или уже смержена):

```powershell
git -C repos/conf-main worktree remove --force "..\DEV-123 conf-main"
git -C repos/conf-main worktree prune
```

`--force` только если пользователь подтвердил зачистку при грязном дереве. Затем убрать EDT-проекты задачи и каталог `DEV-123/` артефакты.

Полный второй clone допустим только если worktree невозможно создать (сломанный `.git` эталона после неудачного ACL self-heal). Это исключение, не правило.
