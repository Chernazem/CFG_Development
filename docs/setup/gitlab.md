# GitLab (centrofinans)

Учётные данные сохранены в **Windows Credential Manager** (`git credential.helper = manager`, пользователь `a.kuznecov`).

## Репозитории

| В чате | GitLab | Локально | Ветка |
|--------|--------|----------|-------|
| **TB**, **ТБ** | [1c/TB](https://gitlab.centrofinans.ru/1c/TB) | `repos/conf-main/` | `main` |
| **TB_ext** | [1c/TB_ext](https://gitlab.centrofinans.ru/1c/TB_ext) | `repos/extensions/` | `master` |
| **tb_api** | [1c/tb_api](https://gitlab.centrofinans.ru/1c/tb_api) | `repos/api-swagger/` | `main` |

```powershell
cd "repos\conf-main";    git pull
cd "repos\extensions";   git pull
cd "repos\api-swagger";  git pull
```

## tb_api — публикация

- Документация: https://developers.centrofinans.ru/api/tb/
- Спецификация в репо: `openapi.json`
- Прод также в S3 — см. README `repos/api-swagger/`

## Смена токена

Удалить запись `gitlab.centrofinans.ru` в учётных данных Windows → `git credential approve` с новым токеном.

На **TB-PC** (агенты без UI GCM): [tb-pc-git-credentials.md](tb-pc-git-credentials.md) и `tools/scripts/setup-tb-pc-git-noninteractive.ps1`.
