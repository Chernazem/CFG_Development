# Вопросы команде сервиса доппродуктов

Статус: **отвечены 2026-08-24.** Полный текст: [answers-from-service.md](answers-from-service.md) (код `b22bb3b`, не PDF и не стенд). Вопросы обратно в ТБ: [questions-for-tb.md](questions-for-tb.md).

Репозиторий: https://gitlab.centrofinans.ru/d.yablokov/addproduct  
Стенд: `http://n8n1-main.centrozaim.local:8000` — если расходится с answers, править стенд.

Исходный список S-01, S-07…S-20 ниже оставлен как оглавление. Не пересылать сервису повторно.

| ID | Коротко | Итог |
| --- | --- | --- |
| S-01 | JWT источника | Код `centrofinance`, роль `integration`, Bearer из cookie login. Закроют S-01a (`/auth/token`) и S-01b (учётка stage/prod). `e2e_tb_sim` не наш. `contour=production`. |
| S-07 | `external_ref` / `client_ref` | Непрозрачные строки 1–128. Рекомендация: GUID заявки и GUID контрагента. |
| S-08 | `scope_id` | GUID договора займа, глобально уникален. На select договора может не быть → В-2. |
| S-09 | `parties` | Канон OpenAPI. Нет обязательного поля → 422 `ERP_SNAPSHOT_INCOMPLETE`. PDF `party` нет. |
| S-10 | `loan_context` | `scope_kind`/`scope_id`/`attributes`. Для ERP-комментария: `loan_application_number`, `loan_application_date`. |
| S-11 | `payment` в confirm | Не реализован. Канон: confirm, затем payment. |
| S-12 | `organization` | Нет такого поля. Это `parties.seller`, обязательно целиком. |
| S-13 | TTL | 30 мин, select не продлевает. Повтор `list`+`select` штатный. Пересмотр — S-22 / В-3. |
| S-14 | Повторный select | Тот же `selection_id`; состав замещается; `activation_id` меняются; после confirm — 409. |
| S-15 | Отказ до select | Не звать select. `sales/cancel` **не** снимает draft (409). Будет `offerings/release` (S-21). Словаря `cancel_reason` нет — В-7. |
| S-16 | Обязательность | Флага нет. Dual-run остаётся в ТБ. Cutover — В-4. |
| S-17 | Чёрный список | API нет (S-24). `client_ref` = GUID контрагента. До заливки фильтр пустой. |
| S-18 | `legacy-comparison` | Не приёмка (статический JSON). Круг 1: журнал ТБ + S-25. **Круг 5 отменяет:** канон — `parity/observations`, см. [answers-round-5.md](answers-round-5.md). |
| S-19 | Каталог | 4 продукта + комбо `guarantee_health_start`. Карту ведёт сервис: `ap_legacy_tariff_mapping.csv`. |
| S-20 | `confirm_policy` | `explicit` для `centrofinance` на stage и prod. |

Четыре факта, которые ломают прежние формулировки плана: TTL 30 мин; `sales/cancel` не для draft; `payment_ref` 1:1 с активацией; токен сегодня только из cookie (Bearer всё же работает).
