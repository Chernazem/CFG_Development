---
name: requirements-writer
description: "Writes structured task requirements in the Confluence-style FNC/ARC format for 1C and platform subsystem tasks. Use when the user asks to prepare, write, formalize, decompose, refine, or review requirements, a постановка, ТЗ, функциональные требования, архитектурные требования, FNC, or ARC. Results must be delivered as a Cursor Canvas."
---

# requirements-writer

## Purpose

Prepare implementation-ready requirements for 1C tasks in the project style:

- functional requirements with `FNC-*****-NNN` identifiers;
- architectural requirements with `ARC-*****-NNN` identifiers;
- explicit dependency links from `ARC` to `FNC`;
- Confluence-like page layout with section links and requirement tables;
- enough detail for development, review, and testing without inventing unconfirmed scope.

## Mandatory Canvas Output

When producing the final requirements artifact:

1. Read and follow the built-in `canvas` skill.
2. Create a `.canvas.tsx` file in the Cursor canvas directory.
3. Put the requirements into the canvas, not only into chat.
4. In chat, return only a short summary and a markdown link to the canvas file.

Do not use a markdown table in chat as the primary result. Render the requirements as Confluence-like tables inside the canvas.

## Workspace

- Корень workspace: текущий TB (каталог с `repos/manifest.yaml`). Конфигурация: `repos/conf-main/`, расширения: `repos/extensions/`, API: `repos/api-swagger/`.
- Canvas-файл: `DEV-XXXXX-requirements.canvas.tsx` в каталоге canvases Cursor IDE (не в git репозитория). Без задачи — `<slug>-requirements.canvas.tsx`.
- Снимок для задачи (опционально): `DEV-XXXXX/requirements-YYYY-MM-DD.md` или `docs/requirements/`.
- Для docs TB — `repos/conf-main/docs/` и `docs/` корня workspace (таблицы FNC/ARC в `feature.md`, если они там приняты).

## Input Handling

Before writing requirements, determine:

1. Numeric task identifier for requirements. If the source key contains a letter prefix and a number, use only the number in requirements. If absent, use a neutral placeholder like `<номер>` and state that the number must be replaced.
2. Business goal and user-visible behavior.
3. Affected configuration-owned objects: subsystem, metadata objects, modules, forms, registers, constants, roles, scheduled jobs, HTTP services, integrations entry points, or APIs implemented in the configuration.
4. Existing behavior and the requested change.
5. External dependencies and settings.
6. Known exclusions and risks.

Ask clarifying questions when a missing fact changes the requirement set materially or when the implementation approach cannot be described from the source. Do not put `Требует уточнения: ...` into final requirements before asking the user.

## Clarification-First Workflow

Use a two-step workflow whenever the source is incomplete:

1. Prepare a short list of blocking questions before creating the requirements canvas.
2. Group questions by affected `FNC` or future `ARC`.
3. For each question, explain what requirement it blocks and what kind of answer is needed: object name, method, storage, status, role, schedule, integration point, or migration rule.
4. Wait for the user's answers.
5. Create the final requirements canvas only after the answers are received.

Question format:

```text
Перед подготовкой требований нужно уточнить:

1. Для FNC-*****-001: какой объект конфигурации выполняет поиск/подбор?
   Нужно указать квалифицированное имя, например `Справочники.<Имя>` или `Обработки.<Имя>.<Форма>`.

2. Для FNC-*****-002: где хранится настройка?
   Нужно выбрать или назвать объект: `Константы.<Имя>`, `Справочники.<Имя>`, табличная часть, регистр.
```

Only use `Требует уточнения` in the final canvas when the user explicitly says to proceed without the missing answer or confirms that the requirement must keep an open question.

## Clarification Over Invention

Never invent business rules, algorithms, metadata objects, module names, method signatures, roles, settings, integrations, update handlers, or testing obligations to make the requirements look complete.

If the agent does not understand how to describe the implementation, it must ask before producing the final canvas. Ask concise questions that unblock the exact requirement, for example:

- "Где должна храниться настройка: в константе, справочнике настроек или существующем объекте?"
- "Каким методом должна вызываться обработка: регламентным заданием, ручной командой или при записи объекта?"
- "Нужно ли сохранить существующее поведение для старых настроек через обработчик обновления?"
- "Какие статусы считаются допустимыми для очистки?"
- "Какая подсистема или функциональная опция должна включать новый объект?"

If the user does not know the answer, ask whether to stop or proceed with an open question. Record uncertainty in `Вопросы и допущения` and mark affected `ARC` rows as `Требует уточнения` only after that confirmation.

Allowed inference:

- Decompose requirements using patterns already present in the source examples.
- Preserve and reorganize terms explicitly provided by the user.
- Add neutral placeholders like `<ИмяПодсистемы>` only when clearly marked as placeholders.

Forbidden inference:

- Choosing storage, schedule, module context, method name, role name, or migration strategy without source evidence.
- Adding "standard" update handlers, constants, functional options, logging, retries, or tests just because they are common.
- Converting an open question into an `ARC` as if it were confirmed scope.

## Only Changed And Confirmed Scope

Requirements describe what must be changed or created. Do not add explanatory placeholders, meta-comments, or notes about things that are not part of the task.

Forbidden wording in final requirements:

- "(имя реквизита в метаданных - по проектному неймингу)";
- "название определить по проектным правилам";
- "при необходимости";
- "если потребуется";
- "остальное поведение не менять";
- "существующая логика остается без изменений".

If a name, object, field, or method is unknown, ask a clarification question before finalizing. Do not write a placeholder comment inside `FNC` or `ARC`.

Do not mention unchanged behavior unless it is a real requirement for compatibility, migration, or data preservation. If no change is needed for an object or behavior, omit it from the requirements.

## Configuration-Owned Scope

All requirements must be centered on objects that belong to the 1C configuration. The requirement page may mention users, external systems, business processes, queues, files, messages, or services only through the configuration object that owns the behavior.

Allowed anchors:

- subsystem, common module, object module, manager module, form module;
- catalog, document, enumeration, information register, accumulation register, constant;
- functional option, session parameter, role, command, command interface;
- scheduled job, event subscription, HTTP service, WS reference, external integration settings object;
- form, template, DCS schema, report, data processor;
- extension object or adopted object when the task is in an extension.

Not allowed as the main subject of a requirement:

- "пользователь должен...", without naming the form/command/object that implements it;
- "внешний сервис должен...", without naming the configuration integration point and contract stored in the configuration;
- "очередь должна...", without naming the register/catalog/object that stores the queue;
- "процесс должен...", without naming the scheduled job/module/method/form event that executes it;
- "данные должны...", without naming the configuration storage object and fields.

If the source describes only an external or business-level action, translate it into a configuration-owned requirement by asking which configuration object owns the behavior. Do not invent the owner.

## Multi-Task Pages

A single requirements page may include several Jira tasks and several numeric requirement groups. Keep the original grouping:

- `FNC-56264-001` can coexist with `FNC-60550-001` on one page.
- `ARC-56264-013` can depend on `FNC-56264-003 FNC-56264-005`.
- `ARC-60550-004` can depend on `FNC-60550-001`.
- The `Задача` column in the functional table stores the numeric implementation task, for example `56264` or `61034`; do not include a letter prefix.

When the source contains several task keys, do not merge them into one artificial identifier. Preserve the numeric source task number in every `FNC` and `ARC`.

Numbering rules:

- New pages normally start from `001`.
- Existing pages may have gaps, for example no `ARC-56264-006`; preserve existing numbering and continue from the next free number.
- If adding requirements to an existing group, continue the existing numeric sequence.
- If the work belongs to a new Jira task on the same page, create a new `FNC-*****-001` and `ARC-*****-001` group using the numeric task id.

## Requirement Format

Use this page structure in the canvas:

1. Page title: `Требования "<Название задачи или подсистемы>"`.
2. Small metadata line if known: creator/source/date/task key.
3. Section links:
   - `Функциональные требования`
   - `Архитектурные требования`
4. Section `Функциональные требования` as a table.
5. Section `Архитектурные требования` as a table.
6. Optional blocks below the tables: `Матрица покрытия`, `Вопросы и допущения`, only if useful.

The default visual style is a Confluence page: white background, blue clickable requirement identifiers, compact table borders, gray table headers, wide `Описание` column, narrow identifier and dependency columns.

Canvas rendering guidance:

- Show `FNC` and `ARC` ids as blue pill/link labels, like Jira/Confluence issue links.
- Keep the `Описание` column visually dominant.
- Preserve blank lines inside long descriptions.
- Render code snippets and BSL fragments in monospace blocks inside table cells.
- Render dependency ids in the `Зависит от` column as separate blue link labels.
- Do not add decorative cards around every requirement; the table is the main artifact.

### Functional Requirements

Each functional requirement describes business behavior, not an implementation step.

Render functional requirements as a table with exactly these columns:

| Column | Content |
|---|---|
| `#` | Requirement id as a blue link-style label, for example `FNC-56264-001`. |
| `Описание` | Business behavior text. Preserve paragraphs and lists inside the cell when needed. |
| `Задача` | Numeric task id, for example `56264`. If unknown, ask before finalizing. Do not include a letter prefix. |
 
Text format inside the `Описание` cell:

```text
<Requirement text>

<Optional second paragraph with details or exclusions>
```

Rules:

- Use imperative or outcome wording: "Добавить возможность...", "Обеспечить...", "При ... система должна ...".
- One requirement covers one independently checkable behavior.
- Include variants and edge cases when they affect expected behavior.
- Do not hide implementation objects in `FNC` unless the business behavior is tied to that object.

### Architectural Requirements

Each architectural requirement describes a concrete applied implementation obligation. It must be specific enough that a 1C developer can start implementation or ask one targeted clarification, not reinterpret the business requirement.

Render architectural requirements as a table with exactly these columns:

| Column | Content |
|---|---|
| `#` | Requirement id as a blue link-style label, for example `ARC-56264-001`. |
| `Описание` | Implementation obligation. Use paragraphs and bullet lists inside the cell for affected objects, methods, fields, rules, and examples. |
| `Зависит от` | One or more linked `FNC` identifiers. |

Text format inside the `Описание` cell:

```text
<Main architectural action>

<Details, affected objects, methods, attributes, rules>

- <Optional bullet>
- <Optional bullet>
```

Rules:

- Specify metadata names, modules, methods, constants, registers, roles, forms, scheduled jobs, endpoints, and settings explicitly when known.
- Write configuration object references as qualified 1C metadata names, for example `Справочники.НастройкиПодсистемыCRM` or `Обработки.РабочееМестоОператораCRM.ОсновнаяФорма`.
- For new metadata, specify type, name, subsystem, key attributes/resources, roles, and important constraints.
- For modules, specify client/server context, export methods, parameters, return value, and main branching rules.
- For integrations, specify endpoint/service, request contract, response handling, retries/errors, logging constraints, and secrets/PII limits if known.
- For behavior preservation, add a dedicated `ARC` for update handlers, migrations, default filling, and compatibility settings.
- For renamed objects, list all known usage locations that must be renamed.
- For settings objects, describe constants, functional options, roles, tabular sections, attributes/resources, and how cached settings are read.
- Every `ARC` must depend on at least one `FNC`.
- Do not create an `ARC` that cannot be traced to a functional requirement.

## Qualified Object Names

In architectural requirements, describe configuration-owned objects with qualified metadata names. Do not use loose phrases like "справочник настроек", "форма обработки", "общий модуль" when the exact object name is known.

Preferred format:

- `Справочники.<ИмяСправочника>`
- `Справочники.<ИмяСправочника>.<ИмяФормы>`
- `Документы.<ИмяДокумента>`
- `Документы.<ИмяДокумента>.<ИмяФормы>`
- `Обработки.<ИмяОбработки>`
- `Обработки.<ИмяОбработки>.<ИмяФормы>`
- `Отчеты.<ИмяОтчета>`
- `Отчеты.<ИмяОтчета>.<ИмяФормы>`
- `РегистрыСведений.<ИмяРегистра>`
- `РегистрыНакопления.<ИмяРегистра>`
- `Перечисления.<ИмяПеречисления>`
- `Константы.<ИмяКонстанты>`
- `ОбщиеМодули.<ИмяМодуля>`
- `Роли.<ИмяРоли>`
- `ФункциональныеОпции.<ИмяФункциональнойОпции>`
- `ПараметрыСеанса.<ИмяПараметраСеанса>`
- `РегламентныеЗадания.<ИмяРегламентногоЗадания>`
- `ПодпискиНаСобытия.<ИмяПодписки>`
- `HTTPСервисы.<ИмяСервиса>`
- `Подсистемы.<ИмяПодсистемы>`

For module methods, write the object first and the method after it:

```text
`ОбщиеМодули.ФП_ОбработкаПроизошедшихБизнесСобытий`, процедура `ДобавитьОбъектВОчередь(...)`
`Справочники.НастройкиПодсистемыCRM.МодульМенеджера`, процедура `ЗаполнитьНастройки()`
`Обработки.РабочееМестоОператораCRM.ОсновнаяФорма`, обработчик `ПриОткрытии(...)`
```

If the exact qualified object name is unknown, do not invent it. Ask the user before finalizing the requirements.

## Applied ARC Detail Level

Architectural requirements must be предметные/прикладные. Avoid high-level rows that merely repeat the `FNC`.

For each `ARC`, include as many of these details as are known from the source:

- exact metadata object: type, name, subsystem, functional option;
- exact module and method/procedure/function name;
- new or changed parameters, default values, return value, exported flag;
- attributes, resources, dimensions, tabular sections, types, lengths, precision;
- read/write target: register, catalog, constant, queue, scheduled job, service;
- conditions and branching: when to exit, when to write, when to skip, statuses, flags;
- algorithm steps in execution order;
- affected existing usages: where to call, where to rename, where to remove;
- rights/roles and command interface placement when the object is user-facing;
- update handler or migration rule when existing data/settings must be preserved.

Bad `ARC` examples:

```text
ARC-56264-012
Доработать запись бизнес-событий с учетом новых настроек.
```

```text
ARC-60550-004
Добавить проверку регистрации событий.
```

Good `ARC` example:

```text
ARC-60550-004
В `ОбщиеМодули.ФП_ОбработкаПроизошедшихБизнесСобытий`, процедуре `ДобавитьОбъектВОчередь(...)`, добавить проверку, что переданный `ВидСобытия` есть в массиве `РегистрацияБизнесСобытий` настроек подсистемы.

Получить настройки через функцию `НастройкиПодсистемы()`.
Если `ВидСобытия` не найден в массиве `РегистрацияБизнесСобытий`, не добавлять запись в `РегистрыСведений.ФП_ПроизошедшиеБизнесСобытия` и завершить процедуру.
Если `ВидСобытия` найден, выполнить существующую запись в очередь без изменения дальнейшего алгоритма.
```

If the source does not contain enough facts to make the `ARC` applied, ask a clarification question instead of writing a generic `ARC`.

## Clear Concepts In ARC

Architectural requirements must use clear, domain-specific concepts. A reader must understand what each term means without guessing from context.

When an `ARC` mentions a concept, define it through concrete 1C terms:

- not "настройка", but `константа <Имя>`, `справочник <Имя>`, `табличная часть <Имя>`, `реквизит <Имя>`, `ресурс <Имя>`;
- not "данные события", but exact structure fields, register resources, storage type, or passed parameter;
- not "обработчик", but module/object and method signature, for example `общий модуль <Имя>`, `процедура <Имя>(...)`;
- not "очередь", but register/catalog/table that stores queue rows, key dimensions/resources, and status field;
- not "статус", but enumeration name and concrete values when known;
- not "настройки подсистемы", but method returning them, source object, and fields included in the returned structure;
- not "существующее поведение", but which records/settings/users are affected and how they are migrated or preserved.

Avoid vague nouns without definition: `механизм`, `логика`, `данные`, `обработка`, `интеграция`, `настройка`, `контекст`, `сущность`, `объект`, `список`, `параметры`. These words are allowed only when the same sentence or paragraph gives the exact name, type, and role.

If a clear concept cannot be named from the source, ask the user what the concept should mean instead of inventing a name or type.

## Decomposition Patterns

Use these recurring patterns when the source supports them.

### Rename or Prefix Replacement

Create separate `ARC` rows for each metadata object type when it improves reviewability:

- enumeration rename;
- register rename;
- role rename;
- module references and tests update.

In each row, include "Заменить наименование во всех местах вхождений" and list known modules/methods.

### Feature Toggle

For optional subsystem behavior, include separate architectural rows for:

- Boolean constant or setting flag;
- functional option covering subsystem objects;
- cached reusable method in `ПовтИсп`;
- early exit in public entry points when the subsystem is disabled;
- scheduled job settings if background processing is affected.

### Settings Directory

For settings stored in a catalog, specify:

- catalog name, subsystem, functional option;
- tabular sections and their fields with exact types;
- view/change roles;
- constant pointing to the current settings element;
- service method that returns a fixed structure;
- reusable cached method that exposes the settings.

### Queue or Register Enrichment

When a queue/register gets new data:

- add a resource/attribute requirement with type and storage rule;
- update enqueue method signature with default value;
- describe serialization/compression if present;
- state when the data is written and when it is ignored.

### Scheduled Processing

For cleanup or background processing, split into:

- service method algorithm;
- scheduled job metadata and handler;
- registration in settings of scheduled jobs;
- functional option binding;
- filters, statuses, periods, and delete/update rules.

### Pluggable Handlers

For extensibility points, specify:

- overridable module and export method;
- return type and key/value types;
- expected handler contract, for example `ОбработкаСобытия(ДанныеОбработки)`;
- exception handling and status/logging behavior.

### Parallel Processing

For multithreading requirements, specify:

- source selection and grouping key;
- settings field that controls thread count;
- distribution algorithm;
- fallback for rows without explicit settings;
- where each thread obtains handlers/settings;
- expected idempotency or retry behavior if known.

### Existing Behavior Preservation

If new settings could change existing behavior, add an `ARC` for data migration or update handler:

- object/module where the handler is placed;
- procedure name;
- how existing elements are found;
- how new tabular sections/settings are filled;
- where the handler is registered in the IB update pipeline.

## Coverage Matrix

Use the matrix as an internal check and add it to the canvas only when the user asks for traceability details or when coverage is non-obvious:

- `FNC`
- linked `ARC`
- acceptance check
- test idea

The matrix must reveal uncovered functional requirements and architectural work that lacks a functional reason.

## Quality Gate

Before finalizing:

1. All identifiers are unique and ordered with three digits: `001`, `002`, `003`.
2. Every `ARC` has a `Зависит от` link.
3. Every `FNC` has at least one implementation path or an explicit note why it is deferred.
4. Requirements are verifiable: each has observable behavior, changed object, or acceptance check.
5. No invented business rules, roles, integrations, or deadlines are added without source evidence.
6. Terms from the user are preserved verbatim: object names, method names, attributes, statuses, settings.
7. Open questions are separated from requirements and are not silently converted into scope.
8. Multi-task pages preserve original task numbers instead of renumbering everything under one task.
9. Compatibility and update-handler work is present when new settings would otherwise alter existing behavior.
10. Every implementation detail in `ARC` is either present in the source, follows an existing explicit pattern, or was clarified with the user before finalizing.
11. If an `ARC` cannot be written without choosing an unknown implementation approach, stop and ask the user before finalizing the canvas.
12. Requirement ids match `FNC-*****-001` or `ARC-*****-001`: use the numeric task id only, without a letter prefix.
13. The `Задача` column also uses the numeric task id only, without a letter prefix.
14. No generic `ARC` rows like "доработать механизм", "реализовать возможность", "добавить обработку", or "учесть настройку" unless the same row names the concrete object/method/data and execution rule.
15. Each `ARC` contains at least one concrete implementation anchor: metadata object, module method, register/resource, setting, scheduled job, role, form, integration endpoint, or update handler.
16. Every important concept in `ARC` has a clear name, type, and role. Vague concepts like "настройка", "данные", "обработка", "контекст", or "объект" are not allowed unless immediately defined.
17. If a concept cannot be defined clearly from the source, ask a clarification question before finalizing.
18. Every `FNC` and `ARC` is centered on a configuration-owned object or behavior implemented by a configuration-owned object.
19. External systems, users, business processes, and data flows are never the standalone owner of a requirement; they must be tied to the configuration object that stores, calls, displays, processes, or schedules them.
20. Configuration objects in `ARC` are written as qualified metadata names, for example `Справочники.НастройкиПодсистемыCRM`, `Обработки.РабочееМестоОператораCRM.ОсновнаяФорма`, `ОбщиеМодули.<Имя>`, `РегистрыСведений.<Имя>`.
21. If blocking facts are missing, the agent has asked questions and received answers before creating the final canvas.
22. `Требует уточнения` appears in the final canvas only when the user explicitly confirmed proceeding with an open question.
23. Final requirements contain no meta-comments, placeholder wording, or notes like "по проектному неймингу", "при необходимости", "если потребуется".
24. Unchanged behavior is omitted unless preserving it is an explicit compatibility, migration, or data-preservation requirement.
25. Text is checked for spelling, typos, repeated words, broken endings, and accidental keyboard-layout mistakes before finalizing.

## Style

- Language: Russian.
- Tone: neutral Confluence-style specification.
- Check spelling and grammar before final output.
- No estimates in hours, days, money, or story points.
- No marketing prose.
- Avoid "ё"; use "е".
- Use regular hyphen only, not long dashes.

## Mini Example

```text
Требования "Обработка произошедших бизнес событий"

Функциональные требования

| # | Описание | Задача |
|---|---|---|
| FNC-56264-001 | Произвести замену префикса объектов метаданных подсистемы с `ЦОГ_` на `ФП_`. | 56264 |
| FNC-56264-002 | Добавить возможность записи вместе с бизнес-событием произвольных данных. | 56264 |
| FNC-60550-001 | Добавить возможность настройки регистрации бизнес событий.\n\nВключение/отключение регистрируемых в системе событий. | 61034 |

Архитектурные требования

| # | Описание | Зависит от |
|---|---|---|
| ARC-56264-001 | Изменить наименование перечисления с `Перечисления.ЦОГ_ВидыСобытий` на `Перечисления.ФП_ВидыПроизошедшихБизнесСобытий`.\n\nЗаменить наименование во всех местах вхождения:\n\n- `ОбщиеМодули.ФП_ОбработкаПроизошедшихБизнесСобытий`, метод `ДобавитьОбъектВОчередь(...)`;\n- `ОбщиеМодули.Тест_ОбработкаПроизошедшихБизнесСобытий`. | FNC-56264-001 |
| ARC-56264-002 | Изменить наименование перечисления с `ЦОГ_СтатусыОбработкиПроизошедшихБизнесСобытий` на `ФП_СтатусыОбработкиПроизошедшихБизнесСобытий`.\n\nЗаменить наименование во всех местах вхождения. | FNC-56264-001 |
| ARC-60550-001 | В `Справочники.ФП_НастройкиОбработкаПроизошедшихБизнесСобытий` добавить табличную часть `РегистрацияБизнесСобытий`.\n\nРеквизиты табличной части:\n\n- `ВидСобытия` - `ПеречислениеСсылка.ФП_ВидыПроизошедшихБизнесСобытий`.\n\nВ таблицу будут добавляться события, которые необходимо регистрировать в системе. | FNC-60550-001 |
| ARC-60550-004 | В `ОбщиеМодули.ФП_ОбработкаПроизошедшихБизнесСобытий`, процедуре `ДобавитьОбъектВОчередь(...)`, добавить проверку, что событие есть в списке регистрируемых событий в настройках подсистемы.\n\nПолучить настройки с помощью функции `НастройкиПодсистемы()`. Если переданный `ВидСобытия` не найден в массиве `РегистрацияБизнесСобытий`, не добавлять запись в очередь. Если найден, добавить запись. | FNC-60550-001 |
| ARC-60550-005 | Для сохранения существующего поведения в `Справочники.ФП_НастройкиОбработкаПроизошедшихБизнесСобытий.МодульМенеджера` добавить оперативный обработчик обновления `ЗаполнитьНастройкиРегистрацииБизнесСобытий()`.\n\nВ процедуре получить все элементы `Справочники.ФП_НастройкиОбработкаПроизошедшихБизнесСобытий` и заполнить табличную часть `РегистрацияБизнесСобытий` всеми значениями `Перечисления.ФП_ВидыПроизошедшихБизнесСобытий`.\n\nВызов обработчика обновления разместить в `ОбщиеМодули.ОбновлениеИнформационнойБазыЗаймы`, процедуре `ПриДобавленииОбработчиковОбновления(...)`. | FNC-60550-001 |
```

For richer examples, keep the same layout but put multi-paragraph and bullet-heavy descriptions inside the table cells, not under separate `ARC` blocks.
