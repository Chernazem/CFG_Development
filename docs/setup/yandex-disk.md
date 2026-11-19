# Яндекс.Диск

По умолчанию файлы оболочки между ноутбуком и `TB-PC` идут через git `CFG_Development` (`docs/setup/shell-sync.md`). Исходники 1С — через GitLab в `repos/<id>/`.

Яндекс.Диск использовать только для больших файлов, которые не кладут в git, или когда пользователь явно просит передать что-то через диск. Правила, skills, скрипты и docs через диск не возить.

## Где лежит `_AI`

Поиск: `tools/scripts/Find-TbYandexAiDir.ps1`. Явный корень: переменная `TB_YANDEX_AI` или параметр `-YandexAiDir` / `-AiRoot`.

Порядок:

1. `TB_YANDEX_AI`, если каталог существует.
2. `SyncFolder\_AI` из `%LOCALAPPDATA%\Yandex\Yandex.Disk.2\*\settings.xml`.
3. Известные пути: `D:\YandexDisk_a.kuznecov@ftech.io\_AI`, `D:\YandexDisk\_AI`, `F:\YandexDisk\_AI`, `%USERPROFILE%\YandexDisk\_AI`, `%USERPROFILE%\Yandex.Disk\_AI`, каталоги `YandexDisk*` и `Yandex.Disk*` на `C:\`, `D:\`, `F:\`.

Папка комплекта, если ей пользуются явно: `<корень _AI>\TB-workspace`.

Скрипт `tools/scripts/sync-tb-workspace-yandex.ps1` сам не запускать. Его `-Action Export` / `-Action Apply` — только по явному запросу.
