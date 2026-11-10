# Поток C — требования волны 1 APNS-010…012 (analyst)

Роль: 1c-analyst + requirements-writer. Worker: TB-PC.
Правки src/ запрещены. Результат: Cursor Canvas FNC/ARC + снимок в docs/analysis/AddProdNewService/ или DEV-*/requirements.

## Цель
Постановка на shadow list: точки ПодобратьДополнительныеПродукты (available), форма ПодборДополнительныхПродуктов (shown), remote shown=копия; not_called вне карты; fail-open; порядок 1С → list → observations.

Опора: implementation-plan.md волна 1, answers-round-5/6, имена объектов из DEV-77738 в main.

## Не делать
Код BSL, MR, вызов сервиса.
