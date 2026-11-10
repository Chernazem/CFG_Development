# Dot-source helper: resolve Yandex.Disk "_AI" folder for TB overlay.
# Prefers TB_YANDEX_AI, then Yandex Disk settings SyncFolder, then YandexDisk*\_AI on fixed drives.
# ASCII-only for Windows PowerShell 5.1.

function Find-TbYandexAiDir {
    param([string]$Hint = '')

    if ($Hint) {
        if (-not (Test-Path -LiteralPath $Hint)) { throw "Yandex _AI not found: $Hint" }
        return (Resolve-Path -LiteralPath $Hint).Path
    }
    if ($env:TB_YANDEX_AI -and (Test-Path -LiteralPath $env:TB_YANDEX_AI)) {
        return (Resolve-Path -LiteralPath $env:TB_YANDEX_AI).Path
    }

    $found = New-Object System.Collections.Generic.List[string]
    $settingsGlob = Join-Path $env:LOCALAPPDATA 'Yandex\Yandex.Disk.2\*\settings.xml'
    foreach ($f in @(Get-ChildItem -Path $settingsGlob -ErrorAction SilentlyContinue)) {
        try {
            [xml]$xml = Get-Content -LiteralPath $f.FullName -Encoding UTF8
            $sync = $xml.Settings.SyncFolder
            if ($sync) {
                $ai = Join-Path $sync '_AI'
                if (Test-Path -LiteralPath $ai) {
                    [void]$found.Add((Resolve-Path -LiteralPath $ai).Path)
                }
            }
        } catch { }
    }

    foreach ($c in @(
            'D:\YandexDisk\_AI',
            'F:\YandexDisk\_AI',
            'D:\Yandex.Disk\_AI',
            (Join-Path $env:USERPROFILE 'YandexDisk\_AI'),
            (Join-Path $env:USERPROFILE 'Yandex.Disk\_AI')
        )) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            [void]$found.Add((Resolve-Path -LiteralPath $c).Path)
        }
    }

    # New account folders e.g. D:\YandexDisk_a.kuznecov@ftech.io\_AI
    foreach ($drive in @('D:\', 'F:\', 'C:\')) {
        if (-not (Test-Path -LiteralPath $drive)) { continue }
        Get-ChildItem -Path $drive -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'YandexDisk*' -or $_.Name -like 'Yandex.Disk*' } |
            ForEach-Object {
                $ai = Join-Path $_.FullName '_AI'
                if (Test-Path -LiteralPath $ai) {
                    [void]$found.Add((Resolve-Path -LiteralPath $ai).Path)
                }
            }
    }

    $uniq = @($found | Select-Object -Unique)
    if ($uniq.Count -eq 0) {
        throw 'Cannot find Yandex.Disk _AI. Set TB_YANDEX_AI (example: D:\YandexDisk_a.kuznecov@ftech.io\_AI) or pass -YandexAiDir / -AiRoot.'
    }
    foreach ($p in $uniq) {
        if (Test-Path -LiteralPath (Join-Path $p 'TB-workspace')) { return $p }
    }
    return $uniq[0]
}
