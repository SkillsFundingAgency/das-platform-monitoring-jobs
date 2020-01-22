. $PSScriptRoot/DevSetup.ps1

function Get-DeploymentCount {
    [CmdletBinding()]
    Param()

    $DefaultApiVersion = "6.0-preview.2"

    $Counts = [System.Collections.ArrayList]::new()


    $DeploymentsUri = "release/deployments"
    $Result = Invoke-VstsRestMethod -Uri $DeploymentsUri -Service VSRM -ApiVersion $DefaultApiVersion -Verbose
    $ContinueationToken = $Result.Headers['x-ms-continuationtoken']
    $null = $Counts.Add($Result.Response.Count)
    while($ContinueationToken){
        $Result = Invoke-VstsRestMethod -Uri $DeploymentsUri -Service VSRM -ApiVersion $DefaultApiVersion -Verbose
        $ContinueationToken = $Result.Headers['x-ms-continuationtoken']
        $null = $Counts.Add($Result.Response.Count)
    }

    $Counts


}

Get-DeploymentCount
