# Клиент runtime на дев-стенде

Дата: 2026-08-25, уточнение 2026-10-22. Секреты учётки **не в git**: `.env.addproduct` в корне workspace.

## Стенд

- API: `http://n8n1-main.centrozaim.local:8000` (**http**, без TLS)
- Источник: `centrofinance`, роль `integration`
- Email / пароль: `.env.addproduct` (`ADDPRODUCT_EMAIL`, `ADDPRODUCT_PASSWORD`)

## Токен

`POST /api/v1/auth/token`, тело `{"email":"...","password":"..."}`.

Ответ: `{"access_token":"...","expires_in":...}` (обычно 3600 с). Refresh нет: по **401** — новый логин. Дальше везде `Authorization: Bearer <access_token>`.

## offerings/list

`POST /api/v1/offerings/list`. Обязательные: `client_ref`, `channel`; для источника ТБ ещё `operation_kind`, `loan_kind`, `requested_amount`, `term_days`. Рекомендуется `external_ref` (заявка) — связь решения с заявкой и безопасный повтор.

**Таймаут HTTP list: 15–20 с** (в элементе `НастройкиСервисаДополнительныхПродуктов`, не 5 с). Значение по умолчанию в коде, если реквизит пуст — см. `ТаймаутПодключенияПоУмолчанию` (целим **20**).

## Fail-open / независимость выдачи

Выдача займа **не зависит** от ответа сервиса в shadow/dual-write: таймаут или ошибка list → клиенту и учёту 1С — как без допов сервиса (инвариант ТБ). На стороне сервиса то же ожидание: их выдача не ждёт наш ответ.

На стенде 2026-08-25 прогнан полный цикл list/select/release и confirm/payment/sales/list.

С 2026-08-28 на том же JWT роли `integration`: `POST /api/v1/parity/observations` и `POST /api/v1/parity/observations/export` (круг 6). `decision_id` — одна строка-UUID из `offerings/list`, не массив.

## Каталог стенда vs пилот

Сейчас на стенде: `guarantee`, `sberhealth`, `cashback`. Нет опубликованного `unemployment`, нет комбо `guarantee_health_start`. Shadow по этим позициям не сравнивать.

Примеры тел — [answers-round-2.md](answers-round-2.md) и письмо `dev-access.md`. Поля `signed_at` и `paid_at` лучше не слать, если нет фактического момента (окно брони).
