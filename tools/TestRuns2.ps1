. $PSScriptRoot/DevSetup.ps1

$ResultsPerSet = 100
$EntitySet = "Releases"
$QueryFromDate = [datetime]::Now.AddDays(-10).ToString("yyyy-MM-ddTHH:mm:ssZ")


# $Query = ""
# $Response = Invoke-ODataRestMethod -EntitySet "${EntitySet}" -Query $Query -Verbose
# $Response.Value


$DefaultApiVersion = "6.0-preview.4"
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

$Uri = "release/definitions?`$expand=Environments&queryOrder=nameAscending&"
$DefinitionList = (Invoke-VstsRestMethod -Uri $Uri -ApiVersion $DefaultApiVersion).Value | Where-Object {$_.Path -notin $ExcludedDefinitionPaths}
$DefinitionList | ForEach-Object {

    $DefinitionId = $_.Id
    $DefinitionName = $_.Name
    $DefinitionPath = $_.Path

        $EnvironmentIdList = $_.Environments | Where-Object {$_.Name -in $IncludedEnvironments} | Select-Object -ExpandProperty Id

        $EnvironmentIdList | ForEach-Object {

            $Uri = "release/deployments?definitionId=${DefinitionId}&definitionEnvironmentId=$_&deploymentStatus=succeeded&latestAttemptsOnly=true&`$top=1&"

            $Result = (Invoke-VstsRestMethod -Uri $Uri -ApiVersion $DefaultApiVersion).Value |
                Select-Object -Property @{Name = "DefinitionId"; Expression = {$DefinitionId}},
                                        @{Name = "DefinitionName"; Expression = {$DefinitionName}},
                                        # @{Name = "DefinitionPath"; Expression = {$DefinitionPath}},
                                        @{Name = "Environment"; Expression = {$_.ReleaseEnvironment.Name}},
                                        # @{Name = "Status"; Expression = {$_.DeploymentStatus}},
                                        @{Name = "QueuedOn"; Expression = {$_.QueuedOn}},
                                        @{Name = "StartedOn"; Expression = {$_.StartedOn}},
                                        @{Name = "CompletedOn"; Expression = {$_.CompletedOn}},
                                        @{Name = "DurationSeconds"; Expression = {[Math]::Round(($_.CompletedOn - $_.StartedOn).TotalSeconds)}}

            $MetricResult.Add($Result)

        }
    }

    $MetricResult










    # $LastReleaseId = $_.LastRelease.Id
    # if ($LastReleaseId) {
    #     # [PscustomObject]@{
    #     #     DefinitionId = $_.Id
    #     #     DefinitionName = $_.name
    #     #     LastReleaseId = $_.LastRelease.Id
    #     # }

    #     $Uri = "release/releases/${LastReleaseId}"
    #     $LastRelease = Invoke-VstsRestMethod -Uri $Uri -ApiVersion "6.0-preview.4"

    #     [PscustomObject]@{
    #         DefinitionId = $_.Id
    #         DefinitionName = $_.name
    #         LastReleaseId = $LastRelease.Id
    #         Environments = $LastRelease.Environments.Name -join ','
    #     }

    #     # $EnvironmentId = ($LastRelease.Environments | Where-Object {$_.name.ToLower() -eq "PP"})[0].Id
    #     # $EnvironmentId
    #     # $Uri = "release/releases/${LastReleaseId}/environments/${EnvironmentId}"
    #     # $Environment = Invoke-VstsRestMethod -Uri $Uri -ApiVersion "6.0-preview.4"
    #     # $Environment


    #     # if ($Environment.Status -eq "succeeded"){
    #     #     $Environment.DeploySteps
    #     # }




# $LastRelease = $DefinitionList.value | select -First 1 -ExpandProperty LastRelease

# # $LastRelease.ReleaseDefinition



# $Uri = "release/releases/34332/environments/166127"
# $s = Invoke-VstsRestMethod -Uri $Uri -ApiVersion "6.0-preview.4"

# $S
