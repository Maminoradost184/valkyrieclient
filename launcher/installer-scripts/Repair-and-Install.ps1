# Ставит Valkyrie Launcher поверх любой ранее установленной версии.
#
# Зачем это нужно. Собранный jpackage установщик отказывается ставиться поверх
# старой сборки и возвращает 1638 ("Another version of this product is already
# installed"): его кастомный экшен JpFindRelatedProducts ищет продукт по имени,
# а в таблице Upgrade старой сборки нет, потому что она собрана без
# --win-upgrade-uuid и получила случайный UpgradeCode. Из-за этого на машине с
# прежней версией новую поставить нельзя в принципе, и лаунчер остаётся в
# старом, частично удалённом состоянии. Здесь старая регистрация снимается
# явно, после чего установщик проходит чисто.

param(
    # -Quiet передаёт установщику ключ /quiet: полезно для автоматической
    # установки и для проверки сборки без диалоговых окон.
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$ProductName = 'ValkyrieLauncher'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Write-Info($text) { Write-Host "    $text" }
function Write-Fail($text) { Write-Host "!!! $text" -ForegroundColor Red }

$uninstallRoots = @(
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

function Get-InstalledLauncherProduct {
    $found = @()
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($key in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue) {
            if ($key.PSChildName -notmatch '^\{[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}$') { continue }
            $entry = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if ($entry.DisplayName -ne $ProductName) { continue }
            $found += [pscustomobject]@{
                Code = $key.PSChildName
                Version = $entry.DisplayVersion
                Location = $entry.InstallLocation
                Root = $root
            }
        }
    }
    return $found
}

function Invoke-MsiExec {
    param([string[]]$Arguments)
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $Arguments -Wait -PassThru
    return $process.ExitCode
}

# --- 1. Снимаем прежние регистрации ------------------------------------------
Write-Step 'Ищу ранее установленные версии'
$installed = @(Get-InstalledLauncherProduct)
if ($installed.Count -eq 0) {
    Write-Info 'Не найдено — ставлю с нуля.'
} else {
    foreach ($product in $installed) {
        Write-Info ("Удаляю {0} {1} ({2})" -f $ProductName, $product.Version, $product.Code)
        $code = Invoke-MsiExec @('/x', $product.Code, '/qn', '/norestart')
        if ($code -eq 0) {
            Write-Info 'Удалено.'
        } elseif ($code -eq 1605) {
            Write-Info 'Уже отсутствует.'
        } elseif ($code -eq 1618) {
            Write-Fail 'Другая установка уже выполняется. Закрой окно установки и запусти ещё раз.'
            exit 1618
        } else {
            Write-Fail ("msiexec вернул {0}. Продолжаю: остатки будут убраны вручную." -f $code)
        }
    }
}

# --- 2. Убираем то, что удаление обычно не уносит -----------------------------
# Каталог с настройками и игровым профилем (%APPDATA%\ValkyrieLauncher) здесь
# намеренно не трогаем: это данные пользователя, а не файлы установки.
Write-Step 'Убираю остатки прежней установки'
$leftovers = New-Object System.Collections.Generic.List[string]
foreach ($base in @($env:ProgramW6432, $env:ProgramFiles, $env:LOCALAPPDATA)) {
    if (-not $base) { continue }
    $candidate = Join-Path $base $ProductName
    if (Test-Path -LiteralPath $candidate) { $leftovers.Add($candidate) }
}
if ($leftovers.Count -eq 0) {
    Write-Info 'Каталогов установки не найдено.'
} else {
    foreach ($folder in $leftovers) {
        Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $folder) {
            Write-Fail ("Не удалось удалить {0}. Закрой лаунчер и запусти скрипт от администратора." -f $folder)
        } else {
            Write-Info ("Удалён {0}" -f $folder)
        }
    }
}

$shortcutFolders = @(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Valkyrie'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Valkyrie'),
    [Environment]::GetFolderPath('DesktopDirectory'),
    (Join-Path $env:PUBLIC 'Desktop')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
foreach ($folder in $shortcutFolders) {
    Get-ChildItem -LiteralPath $folder -Filter "$ProductName*.lnk" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
Write-Info 'Ярлыки пересоздаст установщик.'

# --- 3. Ставим свежую версию --------------------------------------------------
Write-Step 'Запускаю установщик'
$installer = Get-ChildItem -LiteralPath $scriptDir -Filter "$ProductName-*.exe" -File -ErrorAction SilentlyContinue |
    Sort-Object Name | Select-Object -Last 1
if (-not $installer) {
    Write-Fail ("Рядом со скриптом нет {0}-*.exe. Положите установщик в ту же папку." -f $ProductName)
    exit 4
}
Write-Info $installer.Name

$installerArguments = if ($Quiet) { @('/quiet') } else { @() }
$process = Start-Process -FilePath $installer.FullName -ArgumentList $installerArguments -Wait -PassThru
$exitCode = $process.ExitCode
if ($exitCode -eq 0) {
    Write-Info 'Установлено.'
} elseif ($exitCode -eq 1638) {
    Write-Fail 'Установщик снова не смог вытеснить прежнюю версию. Перезагрузите компьютер и запустите скрипт заново.'
} else {
    Write-Fail ("Установщик вернул {0}." -f $exitCode)
}

# --- 4. Проверяем результат ---------------------------------------------------
$expected = Join-Path $env:LOCALAPPDATA $ProductName
Write-Step 'Проверяю установку'
if (Test-Path -LiteralPath (Join-Path $expected "$ProductName.exe")) {
    Write-Info (Join-Path $expected "$ProductName.exe")
} else {
    Write-Info ("Каталог установки не найден в стандартном месте ({0}). Возможно, при установке выбран другой путь." -f $expected)
}

Write-Host ''
Write-Host 'Если лаунчер все еще не открывается, отправьте содержимое журнала:'
Write-Host (Join-Path $env:APPDATA "$ProductName\logs\launcher.log")
Write-Host 'При запуске текст ошибки также копируется в буфер обмена.'

exit $exitCode
