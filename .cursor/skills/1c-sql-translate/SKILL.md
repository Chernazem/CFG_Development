---
name: 1c-sql-translate
description: >-
  Переводит текст SQL-запроса из технологического журнала 1С (DBMSSQL) в имена
  метаданных 1С по снимку схемы *_dbschema через CLI-скрипт. Используй когда нужно
  расшифровать _InfoRg/_AccumRg/_Reference/_Document/_Fld, понять SQL из
  ТЖ/Graylog/профилировщика. Перевод детерминирован — не угадывай имена сам.
---

# Перевод текста SQL-запроса (ТЖ → метаданные 1С)

## Когда использовать

- В SQL из ТЖ / Graylog / плана запроса видны `_InfoRg…`, `_AccumRg…`, `_Fld…RRef`.
- Нужно понять, какой это регистр/справочник/реквизит в терминах 1С.
- Не для выполнения языка запросов 1С (`ВЫБРАТЬ`) — это другой навык (`1c-queries`).

## Важно

Перевод **полностью детерминирован** (снимок `schema` + правила замены).  
**Не** переводи SQL «по смыслу» и **не** подбирай имена метаданных сам.  
Только запуск CLI ниже. Если скрипт упал — покажи ошибку, не делай ручной перевод.

## Что нужно на входе

1. Текст SQL (или файл).
2. Путь к каталогу `schema` нужного репозитория снимка (топик GitLab [dbschema](https://gitlab.centrofinans.ru/explore/projects/topics/dbschema)), например:
   - ТБ ЦФГ: `…/tb_cfg_dbschema/schema`

Описание снимков: [Confluence — схемы хранения БД](https://confluence.centrofinans.ru/pages/viewpage.action?pageId=444573570).

## Как выполнить

Из корня workspace TB:

```bat
oscript .cursor/skills/1c-sql-translate/scripts/main.os translate --schema-root <path\to\schema> --sql-file query.sql
oscript .cursor/skills/1c-sql-translate/scripts/main.os translate --schema-root <path\to\schema> --sql "SELECT ..."
```

JSON в stdout: `sql` (переведённый текст), `tables`, `fields`, `skipped`.  
Покажи пользователю переведённый SQL (и при необходимости краткую таблицу замен из `tables` / `fields`).

Скрипт игнорирует `#tt…` / `#t…` и `_Q_…`; заменяет физические `_Reference*` / `_Document*` / `_InfoRg*` / `_AccumRg*` и поля `_Fld*` / служебные на имена 1С.

## Пример результата

Было:

```sql
SELECT
    T._Period,
    T._Fld26004RRef,
    T._Fld26005RRef,
    T._Fld26006
FROM
    dbo._InfoRg26003 AS T
WHERE
    T._Period <= ?
    AND T._Fld26004RRef = ?
```

Стало:

```sql
SELECT
    T.[Период],
    T.[Клиент],
    T.[УровеньЛояльности],
    T.[НакопленныеДни]
FROM
    dbo.[РегистрСведений.ДействующиеУровниЛояльностиКлиентов] AS T
WHERE
    T.[Период] <= ?
    AND T.[Клиент] = ?
```

## Проверка примера

Из корня workspace TB через [oneunit](https://github.com/sfaqer/oneunit):

```bat
oneunit execute -f .cursor/skills/1c-sql-translate/scripts/tests/ТестПримераИзSkill.os
```

Фикстура: `scripts/fixtures/skill-example/` (`input.sql`, `expected.json`, мини-`schema/`).

## Ограничения

- Только CLI — без ручного разбора `schema/` и без «угадывания» имён.
- Не меняй данные в СУБД и не правь файлы в `schema/` снимка.
- Выбери репозиторий схемы под нужную конфигурацию (ТБ, ERP, ДО, …), не смешивай снимки.
