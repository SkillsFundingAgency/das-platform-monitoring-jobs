param($Timer, $TriggerMetadata)

Import-Module -Name MetricHelpers -ErrorAction Stop
Import-Module -Name MetricHandlers -ErrorAction Stop

if ($ENV:ENVIRONMENTNAME -notin @($ENV:AZURE_DEVOPS_METRIC_ENVIRONMENTS.Split(","))) {
    Write-Information "The function is not configured to run in this environment."
    return
}

Get-DeploymentDuration
