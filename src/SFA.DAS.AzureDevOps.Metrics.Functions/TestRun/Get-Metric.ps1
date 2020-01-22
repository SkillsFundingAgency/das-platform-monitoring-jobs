param($Timer, $TriggerMetadata)

if ($ENV:ENVIRONMENTNAME -notin @($ENV:AZURE_DEVOPS_METRIC_ENVIRONMENTS.Split(","))) {
    Write-Information "The function is not configured to run in this environment."
    return
}

Get-TestRun
