# AddProdNewService

Каталог артефактов анализа выноса подсистемы дополнительных продуктов из конфигурации ТБ (`repos/conf-main`) в отдельный сервис.

Подход, зафиксированный на старте анализа: сначала **дублируем** поведение (полный контур остается в 1С, сервис вызывается параллельно), затем после доказательства идентичности прод-поведения ТБ **отключаем** расчет и фиксацию в 1С.

На dual-run (стенд и прод-тесты) сбой сервиса **не стопает** выдачу и учёт 1С: недоступность, ошибки и таймауты — предупреждение в журнале плюс наблюдение `timeout`/`http_error`/`not_called`. Правило снимается только для блока, уже переключённого в `service-primary` (APNS-060+). Канон: [implementation-plan.md](implementation-plan.md), раздел «Инвариант».

Пилотная версия сервиса уже развернута. Админ-UI и HTTP API - разные порты одного стенда (`n8n1-main.centrozaim.local`). Креды и токены в этот каталог **не записываются**.

## Состав

| Файл | Содержание |
| --- | --- |
| [as-is-tb.md](as-is-tb.md) | Как подсистема живет в ТБ и где встроена в выдачу займа |
| [service-api.md](service-api.md) | Контракт пилотного сервиса (OpenAPI `dev`, стенд на дату анализа) |
| [mapping-and-gaps.md](mapping-and-gaps.md) | Соответствие блоков 1С <-> API и пропущенные контуры |
| [blockers-answers.md](blockers-answers.md) | Ответы на блокеры плана + корректировки по коду сервиса |
| [answers-from-service.md](answers-from-service.md) | Круг 1 (2026-08-24); при противоречии прав круг 2, затем [answers-round-5.md](answers-round-5.md) (S-18) |
| [answers-round-2.md](answers-round-2.md) | Круг 2 (2026-08-25): Q-01…Q-06, выкатка S-01a/b, S-21, S-23, S-24, S-26 |
| [answers-round-5.md](answers-round-5.md) | Круг 5 (2026-08-26): отмена S-18, `parity/observations`, available/shown, APNS-063 после 060, ПДн |
| [answers-round-6.md](answers-round-6.md) | Круг 6 (2026-08-28): стенд parity готов; `decision_id` — один UUID, не массив |
| [answers-to-service.md](answers-to-service.md) | Ответы ТБ сервису на В-1…В-7 |
| [answers-to-service-round-2.md](answers-to-service-round-2.md) | Ответ ТБ на В-8 + приём круга 2 |
| [answers-to-service-round-5.md](answers-to-service-round-5.md) | Приём отмены S-18 и трёх просьб круга 5 |
| [answers-to-service-round-6.md](answers-to-service-round-6.md) | Приём стенда parity; `decision_id` = UUID list, не массив |
| [questions-for-service.md](questions-for-service.md) | Список S-* сервису: отвечен, оглавление |
| [questions-remaining-for-service.md](questions-remaining-for-service.md) | После круга 6 новых вопросов нет; ждём CSV / каталог; parity на стенде готов |
| [questions-for-tb.md](questions-for-tb.md) | Вопросы В-1…В-7 обратно в ТБ + разбор из 1С |
| [stand-runtime.md](stand-runtime.md) | Как звать стенд (секреты в `.env.addproduct`, не в git) |
| [cfe-pilot-findings-for-conf-main.md](cfe-pilot-findings-for-conf-main.md) | Находки пилота CFE `DEV_78570`/`78571` → обязательные доработки в conf-main до снятия расширений |

Интерактивная сводка плана (открывается рядом с чатом): canvas `AddProdNewService-plan`.

## Затронутые репозитории

- `conf-main` - основная конфигурация ТБ, точки входа выдачи и `tb_api`.
- `api-swagger` - контракт внешних методов ТБ для ЛК/МП (`tag AdditionalProducts`).
- Сервис доппродуктов: [gitlab.centrofinans.ru/d.yablokov/addproduct](https://gitlab.centrofinans.ru/d.yablokov/addproduct). В workspace **не клонирован**. Канон приёмки dual-run с 2026-08-26 — [answers-round-5.md](answers-round-5.md); стенд parity — [answers-round-6.md](answers-round-6.md); круг 2 — [answers-round-2.md](answers-round-2.md); круг 1 — [answers-from-service.md](answers-from-service.md). Креды стенда в git **не пишем**.

## Граница анализа на 2026-08-24

- Исходники ТБ: `repos/conf-main/src/cf` и feature-docs `repos/conf-main/docs`.
- OpenAPI сервиса: `GET http://n8n1-main.centrozaim.local:8000/openapi.json`.
- Админ-API каталога проверен живыми POST-запросами (cookie-сессия admin).
- Runtime `POST /api/v1/offerings/list` с cookie админки вернул HTTP 403: по протоколу это ожидаемо (витрина = JWT источника, не admin UI).
- 2026-08-24: ответы на блокеры плана - `blockers-answers.md` (ППИ после включения в тело; материал «Полный цикл продажи»).
- 2026-08-25: круг 2 — `answers-round-2.md`. Учётка стенда заведена (секреты в `.env.addproduct`). Ответ ТБ на В-8 — `answers-to-service-round-2.md`.
- 2026-08-26: круг 5 — `answers-round-5.md`. Приёмка dual-run — `parity/observations` (S-18 круга 1 отменён). Ответ ТБ — `answers-to-service-round-5.md`.
- 2026-08-28: круг 6 — `answers-round-6.md`. Стенд parity готов, тот же JWT. `decision_id` — одна строка-UUID. Ответ ТБ — `answers-to-service-round-6.md`.
- 2026-09-03: инвариант fail-open на прод-тестах зафиксирован в плане (сервис не влияет на основной процесс до cutover).
