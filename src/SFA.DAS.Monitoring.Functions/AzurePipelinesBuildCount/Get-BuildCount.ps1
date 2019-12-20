param($Timer, $TriggerMetadata)

Import-Module -Name MetricHelpers -ErrorAction Stop

if ($ENV:ENVIRONMENTNAME -notin @($ENV:AZURE_DEVOPS_METRIC_ENVIRONMENTS.Split(","))) {
    Write-Information "The function is not configured to run in this environment."
    return
}

$LogType = "AzurePipelinesBuildOutcomeCount"
$EntitySet = "Builds"

# --- Get project metrics
Write-Information "Gathering metadata"
$Query = @"
`$expand=Project(`$select=ProjectId,ProjectName)&
`$apply=filter(BuildPipeline/BuildPipelineName ne null)
"@
$Metadata = Invoke-ODataRestMethod -EntitySet "${EntitySet}" -Query $Query -Verbose

# --- Get count of succeeded builds
$SucceededCount = Get-BuildOutcomeCount -EntitySet $EntitySet -Outcome "Succeed"

# --- Get count of failed builds
$FailedCount = Get-BuildOutcomeCount -EntitySet $EntitySet -Outcome "Failed"

# --- Get count of partially succeeded builds
$PartiallySucceededCount = Get-BuildOutcomeCount -EntitySet $EntitySet -Outcome "PartiallySucceeded"

# --- Get count of cancelled builds
$CancelledCount = Get-BuildOutcomeCount -EntitySet $EntitySet -Outcome "Canceled"

# --- Get count of none builds
$NoneCount = Get-BuildOutcomeCount -EntitySet $EntitySet -Outcome "None"

# --- Get total count of builds
$Query = @"
`$apply=filter(BuildPipeline/BuildPipelineName ne null)
"@
$TotalCount = (Invoke-ODataRestMethod -EntitySet "${EntitySet}/`$count" -Query $Query -Verbose) -replace "ï»¿"

Write-Information "Calculating metric values"
$MetricResult = [PSCustomObject]@{
    ProjectId          = $Metadata.Value[0].Project.ProjectId
    ProjectName        = $Metadata.Value[0].Project.ProjectName
    Suceeded           = [int]$SucceededCount
    PartiallySucceeded = [int]$PartiallySucceededCount
    Failed             = [int]$FailedCount
    Cancelled          = [int]$CancelledCount
    None               = [int]$NoneCount
    Total              = [int]$TotalCount
}

Write-Information "Sending metric payload to Log Analytics (${ENV:LOG_ANALYTICS_WORKSPACE_ID} as type ${LogType}"
Send-LogAnalyticsPayload -Body ($MetricResult | ConvertTo-JSON) -LogType $LogType -ErrorAction Stop
