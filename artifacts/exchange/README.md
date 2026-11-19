# Обмен артефактами TB-PC ↔ основной ПК

Каталог в корневом git-репозитории workspace (`CFG_Development`), чтобы передавать файлы
**по ссылкам GitHub** вместо Яндекс.Диска.

## Структура

| Путь | Назначение |
|------|------------|
| `tb-pc-to-main/` | Собрано на **TB-PC** → скачать на основной ПК |
| `main-to-tb-pc/` | Положить с основного ПК → забрать на **TB-PC** |

Внутри — подкаталог по задаче: `DEV-XXXXXX/` (или `misc/YYYY-MM-DD-тема/`).

## Что класть

- Внешние обработки/отчёты: `.epf`, `.erf`
- Сборки расширений для ручной проверки: `.cfe` (не путать с merge в GitLab)
- Логи, JSON/XML отчёты, скриншоты, zip-пакеты для ручной передачи
- Короткий `NOTES.md` рядом с бинарником (что это, для какой ИБ, дата)

## Чего не класть

- Секреты (`.env`, токены, пароли)
- Полные выгрузки ИБ / `.dt` / `.1cd`
- Большие vendor/tool архивы (лучше `.tools` + docs)
- Исходники конфигурации — только `repos/<id>/`

## Как выложить (TB-PC или основной ПК)

```powershell
# 1) файл в нужную папку
# artifacts/exchange/tb-pc-to-main/DEV-79192/Имя.epf

# 2) commit + push в ветку workspace (корневой репо)
git add artifacts/exchange/...
git commit -m "chore: exchange artifact DEV-XXXXXX ..."
git push -u origin HEAD
```

Глобальный ignore `*.epf` / `*.cfe` перекрыт исключениями для `artifacts/exchange/**`; при сомнении используйте `git add -f`.

Крупные бинарники идут через **Git LFS** (см. `.gitattributes`).

## Как скачать по ссылке

После push на GitHub (`Chernazem/CFG_Development`), для файла на ветке `<branch>`:

- Browse: `https://github.com/Chernazem/CFG_Development/blob/<branch>/artifacts/exchange/...`
- Raw/download: `https://github.com/Chernazem/CFG_Development/raw/<branch>/artifacts/exchange/...`

Для LFS-файлов удобнее кнопка **Download** на странице blob или raw-ссылка выше.

Локально на машине с клоном:

```powershell
git pull
# файл уже в artifacts/exchange/...
```

## Текущий пример

`tb-pc-to-main/DEV-79192/ТестИнтеграцииСервисДопПродуктов.epf` —
ручной e2e AddProd: локальный `ends_at` с `+03:00` и дата окончания в будущем.
