# Волна 1 AddProd — закрыта (handoff PM)

**Дата закрытия:** 2026-10-26…27. Пилот CFE принят; APNS-010…012 влиты в `main` conf-main.

## Jira / MR / merge

| APNS | Jira | MR | Merge commit |
|------|------|-----|--------------|
| 010 | [DEV-78570](https://jira.centrofinans.ru/browse/DEV-78570) | [!6351](https://gitlab.centrofinans.ru/1c/TB/-/merge_requests/6351) | `06f92d1765` |
| 011 | [DEV-78571](https://jira.centrofinans.ru/browse/DEV-78571) | [!6348](https://gitlab.centrofinans.ru/1c/TB/-/merge_requests/6348) | `4d5866acb8` |
| 012 | [DEV-78572](https://jira.centrofinans.ru/browse/DEV-78572) | [!6349](https://gitlab.centrofinans.ru/1c/TB/-/merge_requests/6349) | `2d65292c3b` |

Порядок merge: **6351 → 6348 → 6349**. После каждого следующего MR — merge `main` в ветку (конфликты в тестах паритета/карты пилота).

## Что вошло в main (смысл релиза)

- Shadow `offerings/list` + факт в **РС** журнала интеграции (не ЖР).
- `parity/observations` (`available` / `shown`), fail-open.
- `not_called` вне карты пилота (APNS-012) + `decision_id: null`.
- P-13: `legacy_setting_id` = код настройки через `Программа.НастройкаДополнительногоПродукта`.
- P-14: цена с `ЧРД=.`.
- Имена: общепринятый термин **JSON** латиницей (не «Джейсон»).

## Hotfix компиляции (2026-10-27)

После merge в `main`/`prerelease` всплыли битые имена хелперов (`КонтурProduction`, `НастройкаShadow`, `РазобратьJSON`).  
Фикс: [!6779](https://gitlab.centrofinans.ru/1c/TB/-/merge_requests/6779) → main, [!6780](https://gitlab.centrofinans.ru/1c/TB/-/merge_requests/6780) → prerelease. Канон: [hotfix-compile-helper-names.md](hotfix-compile-helper-names.md).

## Открытые хвосты после волны 1

1. **Снять CFE** `DEV_78570` / `DEV_78571` с прод/тест ИБ (ADR-0001 п.4) — иначе двоится логика с main.
2. **APNS-013** (в работе): shadow для транша КЛ / продления; артефакты `DEV-APNS-013/`.
3. **Волна 2 ACTIVATED (safe-start):** APNS-020/021; 022/023 hold — `DEV-wave2/status/activated.md`.
4. **APNS-005** — матрица сверки после боевых observations.

## Правила PM (зафиксировано)

- Статусы Jira **не менять** (комментарии/ссылки можно) — `.cursor/rules/jira-no-status-transitions.mdc`.
- Реализация 1С — на TB-PC, четыре агента «ДопПродукты» 1…4; не cloud Task.
- Локальные `DEV-78570|78571|78572` / `DEV-wave1` после закрытия **удалены** (2026-10-27); канон продолжения — этот файл + `implementation-plan.md`.

## Слоты агентов (справочно)

| Имя | id |
|-----|-----|
| агент 1 | `bc-d8780b66-a25c-46e8-8e46-92f9d3d9ca82` |
| агент 2 | `bc-43dda3ef-16ca-4793-8995-8af30bc3759e` |
| агент 3 | `bc-07979030-1c56-46dd-8ca7-4dee97b4ba26` |
| агент 4 | `bc-79790979-a830-4a2a-811b-13c042cd180a` |

Пилотные findings: [cfe-pilot-findings-for-conf-main.md](cfe-pilot-findings-for-conf-main.md). ADR CFE: [0001-addprod-wave1-cfe-preprod.md](../../decisions/0001-addprod-wave1-cfe-preprod.md).
