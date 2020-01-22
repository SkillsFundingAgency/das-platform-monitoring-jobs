<#
Dot source this script in to other .ps1 files when developing or exploring APIs.

It will load local.settings.json and add environment variables from your function app.
#>

$ErrorActionPreference = "STOP"
$AppSettings = (Get-Content -Path "${PSScriptRoot}/../src/SFA.DAS.AzureDevOps.Metrics.Functions/local.settings.json" -Raw | ConvertFrom-Json).values

$AppSettings.PSObject.Properties |  ForEach-Object {
    Set-Item -Path "ENV:\$($_.Name)" -Value $_.Value
}

Import-Module -Name "${PSScriptRoot}/../src/SFA.DAS.AzureDevOps.Metrics.Functions/Modules/MetricHelpers/MetricHelpers.psm1" -Force
Import-Module -Name "${PSScriptRoot}/../src/SFA.DAS.AzureDevOps.Metrics.Functions/Modules/MetricHandlers/MetricHandlers.psm1" -Force
