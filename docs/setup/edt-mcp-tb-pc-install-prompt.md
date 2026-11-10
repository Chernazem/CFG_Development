# Установка EDT MCP на TB-PC (волна 1)

Роль: инженер контура на машине TB-PC. Workspace: `D:\Dev Projects\TB`. Не вызывать `move_agent_to_root` / `move_agent_to_cloned_root`. Не править `repos/conf-main/src` и не коммитить в эталоны. Не трогать git-клоны 1С, кроме чтения путей.

Плагин: https://github.com/DitriXNew/EDT-MCP  
Update site: https://ditrixnew.github.io/EDT-MCP/  
IU: `com.ditrix.edt.mcp.server.feature.feature.group`  
MCP URL: `http://127.0.0.1:8765/mcp`  
EDT data: `D:\Dev Projects\TB\.edt-workspace`

## Цель волны 1

Плагин установлен в EDT, сервер MCP слушает :8765, smoke-проверка живая. Импорт всей конфигурации TB и YAXUnit — НЕ делать в этой волне (это часы). Если волна 1 зелёная и останется время — кратко опиши, что нужно для волны 2, но полный import XML не запускай.

## Шаги

1. Инвентаризация (зафиксируй в ответе точные пути и версии):
   - Найти `1cedt.exe` (типично `C:\Program Files\1C\1CE\components\1c-edt-*-x86_64\`).
   - Версия EDT (имя каталога + About/ini). Если EDT нет — остановись, это блокер, не ставь EDT без явного ТЗ на дистрибутив.
   - Java, которую использует EDT.
   - Платформа 1С (`1cv8.exe` / `1cv8c.exe`), ожидается 8.3.27.
   - Занят ли порт 8765, процесс EDT уже запущен?
   - Установлен ли уже feature `com.ditrix.edt.mcp.server` (Installation Details / p2).

2. Совместимость:
   - EDT 2026.1+ → ставить текущий плагин с update site.
   - EDT 2025.x → плагин v1.26.1 (GitHub Releases), не latest.
   - Иная версия — остановись с evidence.

3. Установка:
   - Закрыть все EDT.
   - p2 director `-nosplash -application org.eclipse.equinox.p2.director -repository https://ditrixnew.github.io/EDT-MCP/ -installIU com.ditrix.edt.mcp.server.feature.feature.group -profileProperties org.eclipse.update.reconcile=true`
   - В `1cedt.ini` после `-vmargs` добавить `-DnativeFormBufferedLayoutRender=true`, если ещё нет.

4. Workspace и запуск:
   - Создать `D:\Dev Projects\TB\.edt-workspace`, если нет.
   - Запустить EDT с `-data "D:\Dev Projects\TB\.edt-workspace" -nl ru`.
   - Окружение процесса: `EDT_MCP_DESTRUCTIVE_CONSENT=allow`.
   - Preferences → MCP Server: Auto-start ON, port 8765, Plain text mode (Cursor compatibility) ON.
   - Если UI недоступен агенту: выставь prefs в `.edt-workspace/.metadata/.plugins` (Eclipse preference store плагина) и перезапусти EDT. Не ломай workspace.

5. Cursor MCP на этой машине:
   - В `D:\Dev Projects\TB\.cursor\mcp.json` должен быть сервер `edt` → `http://localhost:8765/mcp` (ключ `servers`, как остальные). Если файла нет или нет ключа — добавь только этот сервер, не затирая остальные.
   - Пользовательский MCP Cursor на TB-PC тоже можно дополнить тем же URL.

6. Smoke:
   - `Invoke-WebRequest` на `http://127.0.0.1:8765/mcp` (ожидаем не connection refused).
   - По возможности вызвать MCP `get_edt_version` и `get_server_status` (plugin version, plainText, port).
   - `list_projects` — можно пустой список.

## Не делать

- `import_configuration_from_xml` всей TB.
- `create_infobase` / `run_yaxunit_tests`.
- Коммиты, push, правки `src/`.
- Установка EDT с нуля без дистрибутива в наличии.
- Смена git config.

## Отчёт (обязательные поля)

```text
EDT path/version:
Plugin installed (yes/no, IU, version):
1cedt.ini flag:
Workspace:
EDT running (pid):
MCP :8765 (ok/fail, evidence):
get_server_status:
Plain text / auto-start:
mcp.json edt:
Blockers:
Next wave:
```
