# SPDX-License-Identifier: MIT
# Deterministic checks. Does not disconnect devices or run the installer.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\ControllerOff.psm1') -Force
Initialize-ControllerApi
$script:checks = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Assert-Throws {
    param([scriptblock]$Action, [string]$Message)
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert-True $threw $Message
}

foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') -and $_.FullName -notmatch '[\\/]\.git[\\/]' }) {
    $tokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    Assert-True ($parseErrors.Count -eq 0) ('PowerShell parse error in ' + $file.Name)
}

Assert-True ([DualSenseBluetoothOff.Native]::DeviceInfoSize -eq 560) 'Incorrect native device structure layout.'
$expectedSearchSize = if ([IntPtr]::Size -eq 8) { 40 } else { 32 }
Assert-True ([DualSenseBluetoothOff.Native]::SearchParamsSize -eq $expectedSearchSize) 'Incorrect native search structure layout.'
Assert-True ([DualSenseBluetoothOff.Native]::DisconnectInputSize -eq 8) 'Bluetooth address must remain 8 bytes.'
Assert-True ([DualSenseBluetoothOff.Native]::DisconnectIoctl -eq 0x41000C) 'Incorrect disconnect IOCTL.'

$value = ConvertTo-ControllerAddress 'AA:BB:CC:DD:EE:FF'
Assert-True ($value -eq [Convert]::ToUInt64('AABBCCDDEEFF', 16)) 'Address byte order is incorrect.'
Assert-True ([DualSenseBluetoothOff.Native]::FormatAddress($value) -eq 'AA:BB:CC:DD:EE:FF') 'Address round-trip failed.'
$bytes = [BitConverter]::GetBytes($value)
Assert-True (($bytes -join ',') -eq '255,238,221,204,187,170,0,0') 'Native address buffer order is incorrect.'
Assert-Throws { ConvertTo-ControllerAddress 'invalid' } 'Invalid address was accepted.'
Assert-Throws { ConvertTo-ControllerAddress '00:00:00:00:00:00' } 'Zero address was accepted.'

$first = [pscustomobject]@{ Name = 'DualSense Wireless Controller'; Address = 'AA:BB:CC:DD:EE:FF' }
$second = [pscustomobject]@{ Name = 'DualSense Wireless Controller'; Address = '11:22:33:44:55:66' }
$other = [pscustomobject]@{ Name = 'Bluetooth Keyboard'; Address = '22:33:44:55:66:77' }
Assert-True ((Select-DualSenseController -Controllers @($first)).Address -eq $first.Address) 'Single-controller selection failed.'
Assert-True ((Select-DualSenseController -Controllers @($first, $other)).Address -eq $first.Address) 'Unrelated Bluetooth device was considered a controller.'
Assert-Throws { Select-DualSenseController -Controllers @($first, $second) } 'Ambiguous controller selection was accepted.'
Assert-Throws { Select-DualSenseController -Controllers @() } 'Empty controller selection was accepted.'
Assert-Throws { Select-DualSenseController -Controllers @($other) } 'Unrelated device was selected.'
Assert-True ((Select-DualSenseController -Controllers @($first, $second) -Address '11-22-33-44-55-66').Address -eq $second.Address) 'Explicit controller selection failed.'
Assert-Throws { Select-DualSenseController -Controllers @($first) -Address $second.Address } 'Nonmatching target was accepted.'

$state = [pscustomobject]@{ Known = $true; Complete = $false; Connected = $false; Name = $first.Name; Errors = @('Access denied') }
Assert-Throws { Assert-DualSenseStatus -State $state -ExpectedName $first.Name } 'Incomplete status was treated as a disconnect.'
$state.Complete = $true
$state.Known = $false
Assert-Throws { Assert-DualSenseStatus -State $state -ExpectedName $first.Name } 'Unknown state was treated as a disconnect.'
$state.Known = $true
$state.Name = 'Bluetooth Keyboard'
Assert-Throws { Assert-DualSenseStatus -State $state -ExpectedName $first.Name } 'Changed device identity was accepted.'
$state.Name = $first.Name
Assert-DualSenseStatus -State $state -ExpectedName $first.Name
Assert-True $true 'Valid status rejected.'

$null = Get-Content -Raw -LiteralPath (Join-Path $root 'codemeta.json') | ConvertFrom-Json
Assert-True $true 'CodeMeta JSON is invalid.'
Write-Output ("Passed {0} checks; no Bluetooth connections were changed." -f $script:checks)
