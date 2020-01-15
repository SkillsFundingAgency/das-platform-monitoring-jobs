function Get-DeploymentDuration {

    $DefaultApiVersion = "6.0-preview.4"
    $LogType = "AzurePipelinesDeploymentDuration"

    $ExcludedDefinitionPaths = @(
        "\_Archive",
        "\Shared Packages",
        "\Platform Automation"
    )

    $MetricEnvironmentMap = @{
        "PP" = "PP"
        "PREPROD" = "PP"
        "PRE" = "PP"
        "PROD" = "PRD"
        "Production" = "PRD"
    }

    $MetricResult = [System.Collections.ArrayList]::new()

    Write-Information "Gathering metrics for environments [$($MetricEnvironments -join ',')]"
    Write-Information "Excluding definition paths [$($ExcludedDefinitionPaths -join ',')]"

    $DefinitionsUri = "release/definitions?`$expand=Environments&queryOrder=nameAscending&"
    $DefinitionList = (Invoke-VstsRestMethod -Uri $DefinitionsUri -ApiVersion $DefaultApiVersion).Value |
        Where-Object {$_.Path -notin $ExcludedDefinitionPaths} |
        Select-Object -Property Id, Name, Path, Environments

    $DefinitionList | ForEach-Object {

        $DefinitionId = $_.Id
        $DefinitionName = $_.Name
        $DefinitionPath = $_.Path.TrimStart("\")

        $_.Environments | Where-Object {$_.Name -in $MetricEnvironmentMap.Keys } | ForEach-Object {

            $EnvironmentName = $MetricEnvironmentMap[$_.Name]

            $DeploymentUri = "release/deployments?definitionId=${DefinitionId}&definitionEnvironmentId=$($_.Id)&deploymentStatus=succeeded&latestAttemptsOnly=true&`$top=1&"

            $Response = (Invoke-VstsRestMethod -Uri $DeploymentUri -ApiVersion $DefaultApiVersion).Value |
                            Select-Object -Property @{Name = "DefinitionId"; Expression = {$DefinitionId}},
                                                    @{Name = "DefinitionName"; Expression = {$DefinitionName}},
                                                    @{Name = "DefinitionPath"; Expression = {$DefinitionPath}},
                                                    @{Name = "ReleaseId"; Expression = {$_.Release.Id}},
                                                    @{Name = "Environment"; Expression = {$EnvironmentName.ToUpper()}},
                                                    @{Name = "QueuedOn"; Expression = {$_.QueuedOn.ToString("u")}},
                                                    @{Name = "StartedOn"; Expression = {$_.StartedOn.ToString("u")}},
                                                    @{Name = "CompletedOn"; Expression = {$_.CompletedOn.ToString("u")}},
                                                    @{Name = "DurationSeconds"; Expression = {[Math]::Round(($_.CompletedOn - $_.StartedOn).TotalSeconds)}}

            $null = $MetricResult.Add($Response)

        }
    }

    Send-LogAnalyticsPayload -Body ($MetricResult | ConvertTo-JSON) -LogType $LogType -ErrorAction Stop

}

Export-ModuleMember -Function @(
    "Get-DeploymentDuration"
)
