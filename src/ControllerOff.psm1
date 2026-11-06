# SPDX-License-Identifier: MIT
Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

function Initialize-ControllerApi {
    if (-not ('DualSenseBluetoothOff.Native' -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot 'BluetoothController.cs')
    }
}

function ConvertTo-ControllerAddress {
    param([Parameter(Mandatory)][string]$Address)
    $hex = $Address -replace '[:-]', ''
    if ($hex -notmatch '^[0-9A-Fa-f]{12}$' -or $hex -eq '000000000000') {
        throw 'Use a Bluetooth address such as AA:BB:CC:DD:EE:FF.'
    }
    [Convert]::ToUInt64($hex, 16)
}

function Get-DualSenseControllers {
    Initialize-ControllerApi
    [DualSenseBluetoothOff.Native]::ListControllers()
}

function Select-DualSenseController {
    param([object[]]$Controllers = @(), [string]$Address)
    Initialize-ControllerApi
    $candidates = @($Controllers | Where-Object { [DualSenseBluetoothOff.Native]::IsSupportedName($_.Name) })
    if ($Address) {
        $value = ConvertTo-ControllerAddress $Address
        $candidates = @($candidates | Where-Object { (ConvertTo-ControllerAddress $_.Address) -eq $value })
    }
    if ($candidates.Count -eq 0) { throw 'No matching DualSense found. Pair it in Windows Bluetooth settings, then run -List.' }
    if ($candidates.Count -ne 1) { throw 'More than one DualSense found. Run -List, then select one with -Address.' }
    $candidates[0]
}

function Resolve-DualSenseController {
    param([string]$Address, [string]$ConfigPath)
    $expectedName = $null
    if (-not $Address -and $ConfigPath -and (Test-Path -LiteralPath $ConfigPath)) {
        $config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
        $Address = [string]$config.Address
        $expectedName = [string]$config.Name
        if (-not $Address -or -not $expectedName) { throw 'Controller configuration is incomplete. Run the installer again.' }
    }
    $controller = Select-DualSenseController -Controllers @(Get-DualSenseControllers) -Address $Address
    if ($expectedName -and $controller.Name -ne $expectedName) { throw 'The saved controller identity changed. Run the installer again.' }
    $controller
}

function Assert-DualSenseStatus {
    param([Parameter(Mandatory)]$State, [Parameter(Mandatory)][string]$ExpectedName)
    if (-not $State.Complete) { throw ('Bluetooth status is incomplete: ' + ($State.Errors -join '; ')) }
    if (-not $State.Known) { throw 'Windows could not find the selected controller. No disconnected state was inferred.' }
    if ($State.Name -ne $ExpectedName) { throw 'Controller identity changed; operation cancelled.' }
}

function Get-DualSenseStatus {
    param([Parameter(Mandatory)]$Controller)
    Initialize-ControllerApi
    $state = [DualSenseBluetoothOff.Native]::GetState((ConvertTo-ControllerAddress $Controller.Address))
    Assert-DualSenseStatus -State $state -ExpectedName $Controller.Name
    $state
}

function Disconnect-DualSenseController {
    param([Parameter(Mandatory)]$Controller)
    $before = Get-DualSenseStatus $Controller
    $after = $before
    $request = $null
    if ($before.Connected) {
        $request = [DualSenseBluetoothOff.Native]::Disconnect((ConvertTo-ControllerAddress $Controller.Address), $Controller.Name)
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            Start-Sleep -Milliseconds 250
            $after = Get-DualSenseStatus $Controller
            if (-not $after.Connected) { break }
        }
        if ($after.Connected) { throw ('Controller is still connected. Windows error codes: ' + ($request.Win32Errors -join ', ')) }
        if ($before.Paired -and -not $after.Paired) { throw 'Disconnected, but retained pairing could not be confirmed.' }
    }
    [pscustomobject][ordered]@{
        Result = $(if ($before.Connected) { 'Disconnected' } else { 'Already disconnected' })
        Name = $after.Name
        Connected = $after.Connected
        Paired = $after.Paired
        Request = $request
    }
}

Export-ModuleMember -Function Get-DualSenseControllers, Select-DualSenseController, Resolve-DualSenseController, Get-DualSenseStatus, Disconnect-DualSenseController, Assert-DualSenseStatus, ConvertTo-ControllerAddress, Initialize-ControllerApi
