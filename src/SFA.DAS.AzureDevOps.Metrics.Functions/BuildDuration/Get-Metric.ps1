param($Timer, $TriggerMetadata)

if ($ENV:ENVIRONMENTNAME -notin @($ENV:AZURE_DEVOPS_METRIC_ENVIRONMENTS.Split(","))) {
    Write-Information "The function is not configured to run in this environment."
    ##TO DO: remove this
    Write-Information "This environment is running PSVersion $($PSVersionTable.PSVersion.ToString())"
    return
}

Get-BuildDuration
