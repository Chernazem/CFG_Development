# Обмен артефактами TB-PC ↔ основной ПК через git

Вместо Яндекс.Диска для точечной передачи обработок, CFE, логов и пакетов используйте:

[`artifacts/exchange/`](../../artifacts/exchange/README.md)

Кратко:

1. На TB-PC положить файл в `artifacts/exchange/tb-pc-to-main/DEV-XXXXXX/`
2. Commit + push корневого репозитория workspace (`CFG_Development`)
3. На основном ПК скачать по GitHub raw/blob ссылке или `git pull`

Полный sync overlay/tools через Яндекс (`sync-tb-workspace-yandex.ps1`) — только по явному запросу и только для массового обновления; **бинарные handoff-артефакты** — в `artifacts/exchange`.

Правило агента: `.cursor/rules/tb-pc-artifacts-exchange.mdc`.
