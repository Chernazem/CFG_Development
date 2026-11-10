# mcp-1c-v1

Источник: [FSerg/mcp-1c-v1](https://github.com/FSerg/mcp-1c-v1), ветка `main`.

Локальный клон лежит в `.tools/mcp-1c-v1`. MCP поднимает RAG по структуре конфигурации 1С:

- `qdrant` — векторная БД, http://localhost:6333/dashboard
- `embedding-service` — сервис эмбеддингов, http://localhost:5000
- `loader` — Streamlit-загрузчик ZIP-выгрузки структуры, http://localhost:8501
- `mcp-server` — Streamable HTTP MCP, http://localhost:8000/mcp
- `mcp-inspector` — инспектор MCP, http://localhost:6274

## Запуск

Требуется Docker Desktop или совместимый Docker CLI с `docker compose`.

```powershell
.\tools\scripts\start-mcp-1c-v1.ps1
```

Остановка:

```powershell
.\tools\scripts\stop-mcp-1c-v1.ps1
```

Статус контейнеров:

```powershell
.\tools\scripts\status-mcp-1c-v1.ps1
```

По умолчанию используется коллекция Qdrant `tb_1c_rag`. Для другой коллекции:

```powershell
.\tools\scripts\start-mcp-1c-v1.ps1 -CollectionName "conf_main_rag"
```

## Подключение Cursor

Проектный MCP-конфиг: `.cursor/mcp.json`.

```json
{
  "servers": {
    "tb-1c-rag": {
      "headers": {
        "x-collection-name": "tb_1c_rag"
      },
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

## Загрузка данных

1. В 1С запустить обработку `.tools/mcp-1c-v1/ПолучитьТекстСтруктурыКонфигурацииФайлами.epf`.
2. Получить ZIP с markdown-файлами и `objects.csv`.
3. Открыть http://localhost:8501.
4. Загрузить ZIP и запустить обработку.
5. После загрузки спрашивать MCP `tb-1c-rag` о структуре конфигурации.

## Текущее состояние

Docker Desktop установлен и после `wsl --update` демон стартует. Для обхода сбоя `pip` на JSON Simple API `pypi.org` Dockerfile'ы локального клона используют зеркало `https://mirrors.aliyun.com/pypi/simple`.

В этом окружении крупные PyTorch wheel-пакеты обрывались/hash mismatch при скачивании. Чтобы MCP можно было поднять сразу, `embedding-service` локально переведен на легкий deterministic hashing embedder без `torch`/`sentence-transformers`. Это рабочий режим для первичного RAG по именам и описаниям объектов; для более качественного семантического поиска можно вернуть оригинальный `sentence-transformers`, когда сеть позволит скачать PyTorch.

Запуск:

```powershell
.\tools\scripts\start-mcp-1c-v1.ps1
```
