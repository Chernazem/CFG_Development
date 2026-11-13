# Обмен артефактами TB-PC ↔ основной ПК через git

Вместо Яндекс.Диска для точечной передачи обработок, CFE, логов и пакетов используйте:

[rtifacts/exchange/](../../artifacts/exchange/README.md)

Кратко:

1. На TB-PC положить файл в rtifacts/exchange/tb-pc-to-main/DEV-XXXXXX/
2. Commit + push корневого репозитория workspace (CFG_Development)
3. На основном ПК скачать по GitHub raw/blob ссылке или git pull

Полный sync overlay/tools через Яндекс (sync-tb-workspace-yandex.ps1) остаётся для
массового обновления skills/docs; **бинарные handoff-артефакты** — в rtifacts/exchange.
