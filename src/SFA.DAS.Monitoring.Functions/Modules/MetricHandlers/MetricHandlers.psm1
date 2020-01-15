function Get-DeploymentDuration {

    $DefaultApiVersion = "6.0-preview.4"
    $LogType = "AzurePipelinesDeploymentDuration"

    $ExcludedDefinitionPaths = @(
        "\_Archive",
        "\Shared Packages"
    )

    $IncludedEnvironments = @(
        "PP",
        "PREPROD",
        "PRE"
    )

    $MetricResult = [System.Collections.ArrayList]::new()

    Write-Information "Collecting deployment metrics for environments [$($IncludedEnvironments -join ',')}]"
    Write-Information "Excluding the definition paths [$($ExcludedDefinitionPaths -join ',')]"

    $DefinitionsUri = "release/definitions?`$expand=Environments&queryOrder=nameAscending&"
    $DefinitionList = (Invoke-VstsRestMethod -Uri $DefinitionsUri -ApiVersion $DefaultApiVersion).Value |
        Where-Object {$_.Path -notin $ExcludedDefinitionPaths} |
        Select-Object -Property Id, Name, Environments

    $DefinitionList | ForEach-Object {

        $DefinitionId = $_.Id
        $DefinitionName = $_.Name

        $EnvironmentIdList = $_.Environments | Where-Object {$_.Name -in $IncludedEnvironments} | Select-Object -ExpandProperty Id

        $EnvironmentIdList | ForEach-Object {

            $DeploymentUri = "release/deployments?definitionId=${DefinitionId}&definitionEnvironmentId=$_&deploymentStatus=succeeded&latestAttemptsOnly=true&`$top=1&"

            $Response = (Invoke-VstsRestMethod -Uri $DeploymentUri -ApiVersion $DefaultApiVersion).Value |
                            Select-Object -Property @{Name = "DefinitionId"; Expression = {$DefinitionId}},
                                                    @{Name = "DefinitionName"; Expression = {$DefinitionName}},
                                                    @{Name = "Environment"; Expression = {$_.ReleaseEnvironment.Name}},
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
