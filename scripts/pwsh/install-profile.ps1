# Made by rafaeloledo (rafaeloliveiraledo@gmail.com)

# Usage: powershell -ExecutionPolicy Bypass -File install-profile.ps1

$scoopPath = $env:SCOOP

if (-not $scoopPath) {
    Write-Host "SCOOP environment variable is not set." -ForegroundColor Red
    exit 1
}

$scoopPathEscaped = $scoopPath.Replace('\','\\')

function Get-WindowsTerminalSettingsPath {
    $scoopWtPersist = Join-Path $scoopPath "persist\windows-terminal\settings\settings.json"
    if (Test-Path $scoopWtPersist) { return $scoopWtPersist }

    $scoopWtCurrent = Join-Path $scoopPath "apps\windows-terminal\current\settings\settings.json"
    if (Test-Path $scoopWtCurrent) { return $scoopWtCurrent }

    $packagesPath = Join-Path $env:LOCALAPPDATA "Packages"
    $wtPackage = Get-ChildItem -Path $packagesPath -Filter "Microsoft.WindowsTerminal_*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $wtPackage) { return $null }

    $settingsPath = Join-Path $wtPackage.FullName "LocalState\settings.json"
    if (-not (Test-Path $settingsPath)) { return $null }
    return $settingsPath
}

$settingsPath = Get-WindowsTerminalSettingsPath
if (-not $settingsPath) { exit 1 }

$settingsText = Get-Content $settingsPath -Raw -Encoding UTF8

try {
    $settings = $settingsText | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Host "Please check for trailing commas or other syntax errors on $settingsPath" -ForegroundColor Red
    exit 1
}

$ProfileName = "PowerShell"
$existingProfile = $settings.profiles.list | Where-Object { $_.name -eq $ProfileName }
if ($existingProfile) { exit 0 }

$guid = [guid]::NewGuid().ToString()

$newProfile = @"
            {
                "commandline": "$scoopPathEscaped\\apps\\pwsh\\current\\pwsh.exe -nologo",
                "guid": "{$guid}",
                "hidden": false,
                "icon": "$scoopPathEscaped\\apps\\pwsh\\current\\pwsh.exe",
                "name": "$ProfileName",
                "startingDirectory": "%USERPROFILE%"
            }
"@

# magic regex
$regex = '(?s)(\"list\":\s*\[)(.*?)(\s*\])'

if ($settingsText -match $regex) {
    $listContent = $matches[2]

    if ($listContent.Trim() -eq "") {
        # empty list -> insert profile without a leading comma
        $result = "`$1`n$newProfile`$3"
    } else {
        # non-empty list -> append profile with a single separating comma
        $result = "`$1`$2,`n$newProfile`$3"
    }

    $settingsText = $settingsText -replace $regex, $result
}

[System.IO.File]::WriteAllText($settingsPath, $settingsText, [System.Text.UTF8Encoding]($false))
