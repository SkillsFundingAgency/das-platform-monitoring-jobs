. $PSScriptRoot/DevSetup.ps1

$ResultsPerSet = 100
$EntitySet = "TestResultsDaily"
$QueryFromDate = [datetime]::Now.AddDays(-10).ToString("yyyy-MM-ddTHH:mm:ssZ")
$Query = @"
`$expand=ReleasePipelines(`$select=ReleasePipelineName)&
`$apply=filter(AnalyticsUpdatedDate ge ${QueryFromDate} and (TestRunType eq 'Automated') and (Workflow eq 'Release'))
"@

$Query2 = @"
`$apply=filter(ReleasePipeline/ReleasePipelineId eq 158 and DateSK ge 20191219  )
    /groupby((TestSK, Test/TestName),
        aggregate(
            ResultCount with sum as TotalCount,
            ResultDurationSeconds with sum as TotalDuration,
            ResultPassCount with sum as PassedCount,
            ResultFailCount with sum as FailedCount,
            ResultNotExecutedCount with sum as NotExecutedCount,
            ResultNotImpactedCount with sum as NotImpactedCount)
        )
        /filter(FailedCount gt 0)
        /compute(
            TotalDuration div cast(TotalCount,Edm.Double) as AvgDuration,
            iif(TotalCount gt NotExecutedCount, (
                (PassedCount add NotImpactedCount) div cast(TotalCount sub NotExecutedCount, Edm.Decimal)
            ) mul 100, 0) as PassRate)&
`$orderby: FailedCount desc
"@

$Query3 = @"
`$apply=filter(ReleasePipeline/ReleasePipelineId eq 158 and DateSK ge 20191226 and ResultFailCount gt 0 )
    /groupby((TestSK))
    /aggregate(`$count as TotalFailingTestsCount)
"@

$Response = Invoke-ODataRestMethod -EntitySet "${EntitySet}" -Query $Query3 -Verbose
$Result = $Response.Value
$Result
# Get-ReleaseDefinition -Id $Result.ReleasePipelineId

# $MetricResult = $Response.value `
#     | Select-Object TestRunId, CompletedDate, RunDurationSeconds, ReleaseId, ReleaseEnvironmentId `
#     | Sort-Object -Property CompletedDate -Descending `
#     | Group-Object -Property TestRunId `
#     | ForEach-Object {
#         $GroupedResult = $_ | Select-Object -ExpandProperty Group | Select-Object -First $ResultsPerSet
#         $Measure = $GroupedResult | Measure-Object -Property RunDurationSeconds -Average -Sum
#         $ReleaseMetadata = Get-ReleaseMetaData -ReleaseId $GroupedResult[0].ReleaseId -ReleaseEnvironmentId $GroupedResult[0].ReleaseEnvironmentId
#         [PSCustomObject]@{
#             TestRunId   = $GroupedResult[0].TestRunId
#             ReleaseDefinitionName = $ReleaseMetadata.DefinitionName
#             ReleaseEnvironmentName = $ReleaseMetadata.EnvironmentName
#             EnvironmentStatus = $ReleaseMetadata.EnvironmentStatus
#             AverageDuration   = $Measure.Average
#             TotalDuration     = $Measure.Sum
#         }
#     }

# $MetricResult | Sort-Object AverageDuration -Descending
