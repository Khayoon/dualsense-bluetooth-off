# SPDX-License-Identifier: MIT
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low', DefaultParameterSetName = 'Off')]
param(
    [Parameter(ParameterSetName = 'List')][switch]$List,
    [Parameter(ParameterSetName = 'Status')][switch]$Status,
    [Parameter(ParameterSetName = 'Off')]
    [Parameter(ParameterSetName = 'Status')][string]$Address,
    [string]$ConfigPath = (Join-Path $env:LOCALAPPDATA 'DualSenseBluetoothOff\controller.json'),
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'src\ControllerOff.psm1') -Force
$resultPath = Join-Path $env:LOCALAPPDATA 'DualSenseBluetoothOff\last-result.json'

try {
    if ($List) {
        $controllers = @(Get-DualSenseControllers | Select-Object Name, Address, Connected, Paired)
        if ($Json) { ConvertTo-Json -InputObject $controllers -Depth 4 } else { $controllers }
        exit 0
    }
    $target = Resolve-DualSenseController -Address $Address -ConfigPath $ConfigPath
    if ($Status) {
        $state = Get-DualSenseStatus $target
        $result = $state | Select-Object Name, Connected, Paired, Remembered
    } else {
        if (-not $PSCmdlet.ShouldProcess($target.Name, 'Disconnect Bluetooth, keeping pairing')) { exit 0 }
        $result = Disconnect-DualSenseController $target
        New-Item -ItemType Directory -Path (Split-Path -Parent $resultPath) -Force | Out-Null
        $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    }
    if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result }
} catch {
    $failure = [pscustomobject]@{ Result = 'Error'; Message = $_.Exception.Message }
    if (-not $List -and -not $Status -and -not $WhatIfPreference) {
        try {
            New-Item -ItemType Directory -Path (Split-Path -Parent $resultPath) -Force | Out-Null
            $failure | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding UTF8
        } catch { }
    }
    if ($Json) { $failure | ConvertTo-Json } else { Write-Error -Message $failure.Message -ErrorAction Continue }
    exit 1
}
