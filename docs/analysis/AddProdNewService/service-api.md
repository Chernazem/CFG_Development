# Пилотный сервис дополнительных продуктов

Стенд на дату анализа 2026-08-24. Исходники сервиса: [https://gitlab.centrofinans.ru/d.yablokov/addproduct](https://gitlab.centrofinans.ru/d.yablokov/addproduct) (в workspace не клонирован). Канон поведения с 2026-08-24 вечера: [answers-from-service.md](answers-from-service.md) по ревизии `b22bb3b`; если OpenAPI стенда расходится — передеплоить стенд.

| Слой | URL | Назначение |
| --- | --- | --- |
| Admin UI (SPA) | `http://n8n1-main.centrozaim.local:3004` | Каталог, партнеры, preview офферов, журнал продаж, swagger UI |
| HTTP API | `http://n8n1-main.centrozaim.local:8000` | Runtime и admin API. OpenAPI: `GET /openapi.json`, UI: `GET /docs` |
| Health | `GET /health`, `GET /ready` | `service=app`, `version=dev`, `environment=stage` |

SPA на `:3004` ходит в API на `:8000`. Все бизнес-методы API - **POST JSON**. Auth: cookie `access_token` + `XSRF-TOKEN` / заголовок `X-XSRF-TOKEN`, корреляция `X-Correlation-ID`. Login: `POST /api/v1/auth/login` `{email, password}`.

Креды стенда в артефакты не копируются.

## Два контура API

### Runtime (то, что должна вызывать ТБ)

Это контракт выдачи, не админка.

```text
POST /api/v1/offerings/list            -> decision_id + offers[]
POST /api/v1/offerings/select          -> selection_id, activations[], contract_draft?
POST /api/v1/sales/confirm             -> активация (подпись / стороны / loan_context)
POST /api/v1/sales/payment             -> факт оплаты по activation_id
POST /api/v1/sales/list                -> состояние продаж по external_ref
POST /api/v1/sales/consume             -> расход услуги
POST /api/v1/sales/correct-usage
POST /api/v1/sales/cancel              -> отмена + расчет возврата
POST /api/v1/sales/payment-webhook
POST /api/v1/registries/ready | partner-code | sent
```

Сквозной ключ выдачи - `external_ref` (заявка/сделка 1С) и `activation_id`.

`coverage_scope` (обязателен на select):

- `kind`: `loan_agreement` | `credit_line_tranche` | `standalone`
- `scope_id`, `ends_at`
- описание схемы: внутри границы стабильный продукт можно активировать один раз

`deal_scenario` в list: `issue` | `prolongation` | `restructuring` | `refinancing`.

Каналы в пилотном каталоге: `office`, `web`, `mobile_app`, `call_center`.

### Admin (каталог и операции, не точка выдачи)

Жизненный цикл НСИ: draft продукта/комбо -> review -> compliance -> approve -> publish / close / archive.

Плюс:

- партнеры и onboarding (legal / finance / integration / pilot / withdraw);
- preview офферов по source (`centrofinance` = «Центрофинанс (1С)», `e2e_tb_sim`);
- журнал продаж, exceptions, integrations;
- аналитика `legacy-comparison` и `loan-sample` - готовый контур сравнения с 1С;
- `erp/documents/render` - печатный payload для ERP.

Для dual-run особенно важны `legacy-comparison` и source `centrofinance`: сервис уже закладывает сверку с ТБ.

## Контракт подбора: `POST /api/v1/offerings/list`

Обязательные поля: `client_ref`, `channel`.

Опциональные: `coverage_scope_kind` (транш КЛ: `credit_line_tranche`), `requested_amount`, `term_days`, `operation_kind`, `loan_kind`, `cash_delivery` (`cash`|`cashless`), `platform` (`android`|`ios`|`web`), `deal_scenario`, `subdivision`, `client_is_repeat`, `contour` (`production`|`test`, default `production`).

Ответ: `decision_id` + `offers[]`. Оффер: `offer_id`, `total_price`, `catalog_total`, `combo`, `supersedes`, `expires_at`, `items[]`.

Это прямой аналог `ПодобратьДополнительныеПродукты`, но идентификаторы - UUID/коды сервиса, не ссылки 1С.

На стенде вызов с admin-cookie вернул **403** (пустое тело). Права `additional_products.offerings.read` у admin при этом есть. Рабочая гипотеза: runtime отделен ACL/аутентификацией технического клиента. Подтвердить до первой задачи интеграции.

## Контракт выбора: `POST /api/v1/offerings/select`

Обязательные: `external_ref`, `decision_id`, `offer_ids[]` (min 1, max 16, uuid), `coverage_scope`.

Ответ `SelectionResponse`: `selection_id`, нормализованные offer_ids, `total_price`, `expires_at`, `contract_draft`, `activations[]`.

Аналог записи выбора на заявку, но сервис сразу резервирует активации и может отдать черновик договора (`ContractDraftResponse.print_payload`).

## Контракт активации: `POST /api/v1/sales/confirm`

Обязательное: `external_ref`. Опционально: `registry_data[]` (discriminator `schema_code`: `sberhealth` | `pharmiq` | `euroins`), `draft_revision`, `document_version`, `signed_at`, `parties` (`customer`, `seller`, `client_erp`), `loan_context` (`scope_kind`, `scope_id`, `attributes`).

Это ближе к «клиент подписал / сделка заключена», чем к проведению 1С-документа. 1С при dual-run должна вызывать confirm **в той же точке**, где сейчас `СформироватьДокументыДополнительныхПродуктов`, и параллельно проводить свои договоры.

## Контракт оплаты: `POST /api/v1/sales/payment`

Обязательные: `activation_id`, `payment_ref`, `amount`. Опционально: `provider`, `provider_payment_id`, `idempotency_key`, `currency` (default `RUB`), `signed_reference`, `paid_at`.

Ответ: `idempotent` + актуальная `activation`.

Состояния активации (схема `SelectionActivationResponse`):

- `payment_state`: `pending` | `paid` | `refunded` | `partially_refunded`
- `service_state`: `reserved` | `active` | `completed` | `revoked`
- `money_state`: `pending` | `paid` | `refund_due` | `refund_processing` | `refunded` | `failed`
- `partner_state`: `pending` | `ready` | `sent` | `revocation_pending` | `revoked`
- `erp_state`: `pending` | `sent` | `accepted` | `rejected` | `reconciled`

Оплата в сервисе - факт money/payment_state. В 1С тот же факт сегодня размазан по ППИ, включению в тело и `ОплатаЧерезПлатежнуюСистему`. Маппинг «какой 1С-документ = payment_ref» - отдельная задача, его нельзя угадывать.

## Каталог на пилотном стенде (admin `catalog/list`)

Партнеры: `cfg` (внутренний, ИНН 2902076410, `erp_counterparty_guid` заполнен), `euroins`, `innmed`, `pharmiq`.

Продукты: `cashback` (approved/production), `guarantee` (approved/production и draft), `sberhealth` (approved/production), `unemployment` (версий нет). Комбо: 0.

Пилот покрывает **узкий** набор относительно зоопарка `ДоговорДополнительногоПродукта*` в ТБ. Dual-run по всей номенклатуре ТБ сразу невозможен без наполнения каталога и карты кодов.

## Что сервис умеет сверх трех блоков

- комбо-офферы и `supersedes`;
- черновик договора и печатный payload;
- расход услуги (`consume`) и корректировка расхода;
- отмена с каналом возврата `client_account` | `organization_account` | `loan_principal`;
- реестры партнерам (PharmIQ-код, ready/sent);
- журнал исключений и интеграционных действий;
- сверка с легаси 1С (`legacy-comparison`, preview source `centrofinance`).
