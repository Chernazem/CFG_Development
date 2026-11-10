# Codex automations: доступ к Centrofinans

Эта памятка фиксирует инфраструктурные нюансы workspace TB для всех новых Codex automations, которые ходят в Jenkins, Allure, GitLab или другие `*.centrofinans.ru`.

## Общий сетевой контур

- Доступ к внутренним ресурсам идет через OpenVPN.
- Профиль OpenVPN: `C:\Program Files\OpenVPN\config\a_kuznecov-pers_devStation.ovpn`.
- Лог OpenVPN: `C:\Users\Chernazem\OpenVPN\log\a_kuznecov-pers_devStation.log`.
- Нормальные признаки: процессы `openvpn`, `openvpnserv`, `openvpn-gui`; в логе `Initialization Sequence Completed` или `CONNECTED,SUCCESS`; VPN IP вида `172.20.52.*`; маршрут до внутренних сетей через VPN.
- Для `*.centrofinans.ru` нельзя идти через proxy `127.0.0.1:9`.

Перед сетевыми запросами в automation:

```powershell
foreach ($n in 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy') {
    Remove-Item "Env:$n" -ErrorAction SilentlyContinue
}
$env:NO_PROXY = 'localhost,127.0.0.1,.centrofinans.ru,centrofinans.ru,jenkins.centrofinans.ru,gitlab.centrofinans.ru'
$env:no_proxy = $env:NO_PROXY
```

## Jenkins / Allure

- `curl.exe` на Windows может падать до HTTP-уровня с `schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS`.
- Это не ошибка Jenkins login/password и не HTTP `401/403`; TLS handshake не завершается.
- Основной транспорт для Jenkins/Allure в automations: Node.js `https`/`fetch`, потому что он использует OpenSSL и уже проверен как рабочий для Jenkins API.
- `curl` использовать только для диагностики Schannel, не как блокирующий транспорт.
- Jenkins credentials хранить и выводить аккуратно: пароль не печатать в summary, memory, логах или командах диагностики.
- Для детализации failed/broken в Allure 2 не использовать старые endpoints `widgets/failed-tests.json`, `widgets/defects.json` как обязательные: они могут возвращать `302` на `index.html#404`, и это означает отсутствие endpoint, а не проблему auth.
- Рабочая схема детализации Allure: читать `widgets/summary.json` и `widgets/categories.json` для агрегатов, затем `data/categories.json`; из дерева `data/categories.json` брать leaf-тесты со `status` = `failed`/`broken`, по каждому читать `data/test-cases/<uid>.json`.

## GitLab / Git

- Remote TB: `https://gitlab.centrofinans.ru/1c/TB.git`.
- GitLab должен использовать credentials основной сессии через Git Credential Manager. Не использовать Jenkins credentials для GitLab.
- В основной сессии настроен `credential.helper manager` и username `a.kuznecov`.
- Git for Windows собран с OpenSSL, но системный config может задавать `http.sslbackend=schannel`; в automation Schannel может падать с `SEC_E_NO_CREDENTIALS`.

Для GitLab-команд использовать форму:

```powershell
git `
  -c http.sslbackend=openssl `
  -c http.sslVerify=false `
  -c http.proxy= `
  -c https.proxy= `
  -c http.https://gitlab.centrofinans.ru.proxy= `
  -c credential.helper=manager `
  fetch origin
```

`http.sslVerify=false` использовать только как флаг конкретной команды для внутреннего GitLab через VPN, не записывать в global/local config.

## `.git` ACL и `index.lock`

Для всех новых automation обязательный первый шаг перед любыми git-операциями:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\scripts\repair-codex-automation-git-acl.ps1" -WorkspaceRoot "<workspace-root>" -RemoveStaleLocks -VerifyGit
```

Для ручного elevated-фикса или обслуживания рабочей станции запускать тот же скрипт с `-FixPackFiles`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\scripts\repair-codex-automation-git-acl.ps1" -WorkspaceRoot "<workspace-root>" -RemoveStaleLocks -FixPackFiles -VerifyGit
```

Скрипт защищает DACL каждого `.git` от наследования с сохранением текущих allow-прав, удаляет только `DENY` для известного SID, проверяет пробную запись в `.git`, умеет удалять stale `index.lock` при отсутствии активных git-процессов и выполняет `git add -A --dry-run` для проверки записи в индекс. Без elevated-прав скрипт может не снять старый inherited `DENY` с уже существующих `pack-*.pack`; это не заменяет ручной elevated-фикс, но предотвращает повторение проблемы для новых `.git`-объектов после защиты DACL.

Перед commit/push automation должна проверить:

- `whoami /user`
- `icacls .git`
- отсутствие `.git/index.lock`
- пробную запись и удаление `.git/codex_acl_write_test.tmp`
- после ACL-fix выполнить безопасную git-проверку записи, например `git add -A --dry-run`, до настоящего `git add`/`commit`.

Известный локальный риск: на `.git` может снова появляться явный `DENY` ACE для SID:

```text
S-1-5-21-2994193773-3879609815-543980735-1115835159
```

Если он блокирует создание `.git/index.lock`, надо снять только explicit non-inherited `DENY` ACE этого SID с `.git`, не меняя allow-права и не трогая рабочие файлы.

Устойчивый локальный фикс, применённый для `repos/conf-main`: ACL на `.git` защищён от наследования (`AreAccessRulesProtected=True`) с сохранением текущих allow-прав, затем явные deny удалены через .NET `DirectoryInfo.GetAccessControl(AccessControlSections.Access)` и `DirectoryInfo.SetAccessControl`. Важно читать/писать только DACL `Access`-section, не SACL; иначе можно получить `SeSecurityPrivilege`/`UnauthorizedAccessException`. Это предотвращает повторное появление deny во вложенных `.git/objects` через наследование во время работы automations. Обычный `icacls /remove:d` для неизвестного SID здесь не сработал, а `Set-Acl` может упираться в права процесса.

Рабочий шаблон:

```powershell
$root = (Resolve-Path -LiteralPath '.git').Path
$sid = [System.Security.Principal.SecurityIdentifier]'S-1-5-21-2994193773-3879609815-543980735-1115835159'
$di = [System.IO.DirectoryInfo]::new($root)
$acl = $di.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Access)
$rules = @($acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
    Where-Object { $_.IdentityReference -eq $sid -and $_.AccessControlType -eq 'Deny' })
foreach ($rule in $rules) { [void]$acl.RemoveAccessRuleSpecific($rule) }
$acl.SetAccessRuleProtection($true, $true)
$di.SetAccessControl($acl)
```

Проверка после фикса:

```powershell
Get-Acl .git | Format-List AreAccessRulesProtected
icacls .git
icacls .git\objects
```

В выводе не должно быть `DENY` для SID `S-1-5-21-2994193773-3879609815-543980735-1115835159`, а `AreAccessRulesProtected` должен быть `True`.

Если `.git/index.lock` уже существует, сначала проверить активные `git`-процессы. Удалять lock можно только если это stale lock.

Automation не должна останавливаться с блокером на известном `.git` ACL до self-heal. Обязательный порядок:

1. применить DACL-fix из шаблона выше;
2. повторить пробную запись `.git/codex_acl_write_test.tmp`;
3. выполнить безопасную проверку git-записи (`git add -A --dry-run` или эквивалент);
4. если запись в `.git` всё ещё запрещена, пересоздать task-клон в каталоге задачи по правилам изоляции DEV-задач и продолжить работу в новом task-клоне;
5. блокером считать только ситуацию, когда не удалось ни починить ACL, ни пересоздать task-клон; в отчете указать обе попытки и точную диагностику.
