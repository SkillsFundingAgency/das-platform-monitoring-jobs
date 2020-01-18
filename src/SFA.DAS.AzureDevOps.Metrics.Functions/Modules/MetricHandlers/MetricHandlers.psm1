function Get-DeploymentDuration {
    [CmdletBinding()]
    Param()

    $DefaultApiVersion = "6.0-preview.4"
    $LogType = "AzurePipelinesDeploymentDuration"

    $ExcludedDefinitionPaths = @(
        "\_Archive",
        "\Shared Packages",
        "\Platform Automation"
    )

    $MetricEnvironmentMap = @{
        "PP"         = "PP"
        "PREPROD"    = "PP"
        "PRE"        = "PP"
        "PROD"       = "PRD"
        "Production" = "PRD"
    }

    $MetricResult = [System.Collections.ArrayList]::new()

    Write-Information "Gathering metrics for environments [$($MetricEnvironmentMap.Keys -join ',')]"
    Write-Information "Excluding definition paths [$($ExcludedDefinitionPaths -join ',')]"

    try {

        $DefinitionsUri = "release/definitions?`$expand=Environments&queryOrder=nameAscending&"
        $DefinitionList = (Invoke-VstsRestMethod -Uri $DefinitionsUri -Service VSRM -ApiVersion $DefaultApiVersion).Value |
        Where-Object { $_.Path -notin $ExcludedDefinitionPaths } |
        Select-Object -Property Id, Name, Path, Environments

        $DefinitionList | ForEach-Object {

            $DefinitionId = $_.Id
            $DefinitionName = $_.Name
            $DefinitionPath = $_.Path.TrimStart("\")

            $_.Environments | Where-Object { $_.Name -in $MetricEnvironmentMap.Keys } | ForEach-Object {

                $EnvironmentName = $MetricEnvironmentMap[$_.Name]

                $DeploymentUri = "release/deployments?definitionId=${DefinitionId}&definitionEnvironmentId=$($_.Id)&deploymentStatus=succeeded&latestAttemptsOnly=true&`$top=1&"

                $Response = (Invoke-VstsRestMethod -Uri $DeploymentUri -Server VSRM -ApiVersion $DefaultApiVersion).Value |
                Select-Object -Property @{Name = "DefinitionId"; Expression = { $DefinitionId } },
                @{Name = "DefinitionName"; Expression = { $DefinitionName } },
                @{Name = "DefinitionPath"; Expression = { $DefinitionPath } },
                @{Name = "ReleaseId"; Expression = { $_.Release.Id } },
                @{Name = "Environment"; Expression = { $EnvironmentName.ToUpper() } },
                @{Name = "QueuedOn"; Expression = { $_.QueuedOn.ToString("u") } },
                @{Name = "StartedOn"; Expression = { $_.StartedOn.ToString("u") } },
                @{Name = "CompletedOn"; Expression = { $_.CompletedOn.ToString("u") } },
                @{Name = "DurationSeconds"; Expression = { [Math]::Round(($_.CompletedOn - $_.StartedOn).TotalSeconds) } }

                $null = $MetricResult.Add($Response)
            }
        }

        Send-LogAnalyticsPayload -Body ($MetricResult | ConvertTo-JSON) -LogType $LogType
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }


}

function Get-BuildCount {
    [CmdletBinding()]
    Param()

    $LogType = "AzurePipelinesBuildOutcomeCount"
    $EntitySet = "PipelineRuns"

    try {

        $Query = "`$apply=filter(Pipeline/PipelineName ne null)/groupby((RunOutcome), aggregate(`$count as OutcomeCount))"
        $Response = Invoke-ODataRestMethod -EntitySet ${EntitySet} -Query $Query -Verbose:$VerbosePreference

        Write-Information "Calculating metric values"
        $MetricResult = [PSCustomObject]@{
            ProjectName = $ENV:AZURE_DEVOPS_PROJECT
            Total = $null
        }

        $Response.Value | ForEach-Object {
            Add-Member -InputObject $MetricResult -Name $_.RunOutcome -Value $_.OutcomeCount -MemberType NoteProperty
        }

        $MetricResult.Total = ($MetricResult.PSObject.Properties | Where-Object {$_.Name -ne "ProjectName"} | Measure-Object -Property Value -Sum).Sum

        Send-LogAnalyticsPayload -Body ($MetricResult | ConvertTo-JSON) -LogType $LogType
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-BuildDuration {
    [CmdletBinding()]
    Param()

    $LogType = "AzurePipelinesBuildDuration"
    $EntitySet = "PipelineRuns"
    $DefaultApiVersion = "6.0-preview.4"

    $QueryFromDays = $ENV:AZURE_DEVOPS_BUILD_DURATION_QUERYFROMDAYS
    $QueryFromDate = [datetime]::Now.AddDays(-$QueryFromDays).ToString("yyyy-MM-ddTHH:mm:ssZ")

    $ExcludedDefinitionPaths = @(
        "_Archive",
        "Shared Packages",
        "_toDelete_DAS-Payments",
        "_toDelete_DAS-RAA",
        "_toDelete_DAS",
        "_toDelete_ROATP",
        "Security Tool"
    ) -join "|"

    $MetricResult = [System.Collections.ArrayList]::new()

    Write-Information "Excluding definition paths [$($ExcludedDefinitionPaths)]"

    try {

        $DefinitionsUri = "build/definitions?queryOrder=definitionNameAscending&"
        $DefinitionList = (Invoke-VstsRestMethod -Uri $DefinitionsUri -ApiVersion $DefaultApiVersion -Verbose).Value |
            Where-Object {$_.Path.TrimStart("\") -notmatch $ExcludedDefinitionPaths} |
            Select-Object -Property Id, Name, Path

        $DefinitionList | ForEach-Object {

            $PipelineName = $_.Name
            $PipelinePath = $_.Path

            $Query = "`$apply=filter(PipelineId eq $($_.Id) and (RunOutcome eq 'Succeed') and (CompletedDate ge ${QueryFromDate}))&`$orderby=CompletedDate desc&`$top=1"
            $Response = (Invoke-ODataRestMethod -EntitySet $EntitySet -Query $Query -Verbose).Value |
                Select-Object -Property PipelineId,
                    @{Name = "PipelineName"; Expression = { $PipelineName }},
                    @{Name = "PipelinePath"; Expression = { $PipelinePath.TrimStart("\") }},
                    @{Name = "BuildNumber"; Expression = { $_.RunNumber }},
                    @{Name = "QueuedOn"; Expression = { $_.QueuedDate }},
                    @{Name = "StartedOn"; Expression = { $_.StartedDate }},
                    @{Name = "CompletedOn"; Expression = { $_.CompletedDate }},
                    @{Name = "DurationSeconds"; Expression = { [Math]::Round($_.RunDurationSeconds) }}

            $null = $MetricResult.Add($Response)
        }

        Send-LogAnalyticsPayload -Body ($MetricResult | ConvertTo-JSON) -LogType $LogType
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function @(
    "Get-BuildCount",
    "Get-BuildDuration",
    "Get-DeploymentDuration"
)
