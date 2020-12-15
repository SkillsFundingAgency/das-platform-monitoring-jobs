[CmdletBinding()]
param(
    [string]$AppInsightsNamePrefix
)

$AppInsightsResources = Get-AzResource -ResourceType "Microsoft.Insights/components" -Name "$AppInsightsNamePrefix*"

$AppInsightsResourcesArray = @()

foreach ($AppInsightsResource in $AppInsightsResources) {
    $AppInsightsResourceObject = New-Object PSObject
    $AppInsightsResourceObject | Add-Member -NotePropertyMembers @{
        appInsightsName             = $AppInsightsResource.Name
        appInsightsResourceGroup    = $AppInsightsResource.ResourceGroupName
    }
    $AppInsightsResourcesArray += $AppInsightsResourceObject
}

$AppInsightsResourcesArrayString = $AppInsightsResourcesArray | ConvertTo-Json -Compress

Write-Output "##vso[task.setvariable variable=APP_INSIGHTS_RESOURCES_ARRAY_STRING]$($AppInsightsResourcesArrayString)"
