# SonarQube Quality Gate (MR TB)

Обязательный контроль готовности Merge Request для `conf-main` (`1c/TB`) и других репо контура, где pipeline содержит Sonar.

## Где в pipeline

В `repos/conf-main/build/build.jenkinsfile`:

1. Stage `Анализ SonarQube с результатами тестов` — `stepSonarScanner`.
2. Stage `SonarQube Quality gate` — `waitForQualityGate abortPipeline: true` (ошибка stage ловится в `catchError` → часто `UNSTABLE` сборки).

Сервер: корпоративный SonarQube (см. ссылки в UI Jenkins / GitLab check; для смежных проектов встречается `sonar2.centrofinans.ru`).

## Правило для агента / разработчика

| Условие | Действие |
| --- | --- |
| QG **OK** (зелёный) | Можно считать Sonar-gate пройденным |
| QG **ERROR** / красный / stage FAILURE | Блокер merge: разобрать new code issues, исправить, push, новый мониторинг |
| Сборка `UNSTABLE` из‑за QG при зелёных тестах | Тот же блокер — не закрывать задачу «потому что unit зелёный» |
| Сборка ещё без stage Sonar | Продолжать heartbeat 30m, не объявлять готовность |

Готовность задачи (critical-flow): локальные проверки + актуальный MR + Jenkins без падений/MR-only UNSTABLE **и** зелёный SonarQube Quality Gate.

## Evidence в статусе / MR

После терминальной сборки зафиксировать:

```text
SonarQube Quality Gate: OK | ERROR
- Jenkins build: <url>
- Sonar project / dashboard: <url if available>
- Blocking findings: none | list (rule, file, message)
```

В описании MR — краткий итог QG; при ERROR — список блокеров и что исправлено в следующем push.

## Локальный предконтроль (TB-PC)

Перед push обязателен **LSP** на проекте task-клона (`docs/setup/lsp-task-clones.md`) — локальная замена Sonar. Все правила диагностики LSP должны быть включены. Это не отменяет внешний Quality Gate после Jenkins. EDT MCP не использовать.