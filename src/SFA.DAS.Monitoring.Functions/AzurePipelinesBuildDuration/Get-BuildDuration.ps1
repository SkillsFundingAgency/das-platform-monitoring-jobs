param($Timer, $TriggerMetadata)

Import-Module -Name MetricHelpers -ErrorAction Stop

if ($ENV:ENVIRONMENTNAME -notin @($ENV:AZURE_DEVOPS_METRIC_ENVIRONMENTS.Split(","))) {
    Write-Information "The function is not configured to run in this environment."
    return
}

$LogType = "AzurePipelinesBuildDuration"
$EntitySet = "Builds"
$ResultsPerSet = $ENV:AZURE_DEVOPS_BUILD_DURATION_RESULTSPERSET
$QueryFromDays = $ENV:AZURE_DEVOPS_BUILD_DURATION_QUERYFROMDAYS
$QueryFromDate = [datetime]::Now.AddDays(-$QueryFromDays).ToString("yyyy-MM-ddTHH:mm:ssZ")

$Query = @"
`$expand=BuildPipeline(`$select=BuildPipelineName)&
`$apply=filter(CompletedDate ge ${QueryFromDate} and (BuildOutcome eq 'Succeed') and BuildPipeline/BuildPipelineName ne null)
"@

Write-Information "Invoking query on EntitySet '${EntitySet}'"
$RawResult = Invoke-ODataRestMethod -EntitySet $EntitySet -Query $Query -Verbose

Write-Information "Calculating metric values"
$MetricResult = $RawResult.value `
    | Select-Object BuildPipelineId, CompletedDate, @{N = "BuildPipelineName"; E = { $_.BuildPipeline.BuildPipelineName } }, BuildDurationSeconds `
    | Sort-Object -Property CompletedDate -Descending `
    | Group-Object -Property BuildPipelineName `
    | ForEach-Object {
        $GroupedResult = $_ | Select-Object -ExpandProperty Group | Select-Object -First $ResultsPerSet
        $Measure = $GroupedResult | Measure-Object -Property BuildDurationSeconds -Average -Sum
        [PSCustomObject]@{
            BuildPipelineId   = $GroupedResult[0].BuildPipelineId
            BuildPipelineName = $GroupedResult[0].BuildPipelineName
            AverageDuration   = $Measure.Average
            TotalDuration     = $Measure.Sum
        }
    }

Write-Information "Sending metric payload to Log Analytics (${ENV:LOG_ANALYTICS_WORKSPACE_ID} as type ${LogType}"
Send-LogAnalyticsPayload -Body ($MetricResult | ConvertTo-JSON) -LogType $LogType -ErrorAction Stop
