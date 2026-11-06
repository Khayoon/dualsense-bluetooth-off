# SPDX-License-Identifier: MIT
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param([string]$Address)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'src\ControllerOff.psm1') -Force
$installRoot = Join-Path $env:LOCALAPPDATA 'DualSenseBluetoothOff'
$configPath = Join-Path $installRoot 'controller.json'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'DualSense Off.lnk'
$launcherPath = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$launchArguments = '-NoProfile -NoLogo -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $installRoot 'Controller-Off.ps1') + '"'

try {
    $target = Resolve-DualSenseController -Address $Address -ConfigPath $configPath
    $null = Get-DualSenseStatus $target
    $shellLink = New-Object -ComObject WScript.Shell
    if (Test-Path -LiteralPath $shortcutPath) {
        $existing = $shellLink.CreateShortcut($shortcutPath)
        if (-not [String]::Equals($existing.TargetPath, $launcherPath, [StringComparison]::OrdinalIgnoreCase) -or
            -not [String]::Equals($existing.Arguments, $launchArguments, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'An unrelated DualSense Off desktop shortcut already exists. Rename it before installing.'
        }
    }
    if (-not $PSCmdlet.ShouldProcess($installRoot, 'Install DualSense Off and create its desktop shortcut')) { exit 0 }
    New-Item -ItemType Directory -Path (Join-Path $installRoot 'src') -Force | Out-Null
    foreach ($relative in @('Controller-Off.ps1', 'src\ControllerOff.psm1', 'src\BluetoothController.cs')) {
        $source = Join-Path $PSScriptRoot $relative
        $destination = Join-Path $installRoot $relative
        if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($destination)) {
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }
    }
    [ordered]@{ Version = 1; Address = $target.Address; Name = $target.Name } |
        ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
    $link = $shellLink.CreateShortcut($shortcutPath)
    $link.TargetPath = $launcherPath
    $link.Arguments = $launchArguments
    $link.WorkingDirectory = $installRoot
    $link.IconLocation = (Join-Path ([Environment]::SystemDirectory) 'joy.cpl') + ',0'
    $link.WindowStyle = 7
    $link.Description = 'Disconnect your DualSense Bluetooth controller; keep its saved pairing.'
    $link.Save()
    Write-Output 'Ready. Double-click DualSense Off on your desktop. Press PS to reconnect.'
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
