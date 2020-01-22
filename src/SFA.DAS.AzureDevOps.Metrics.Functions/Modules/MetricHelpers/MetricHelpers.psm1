function New-Signature {
    <#
    .SYNOPSIS
    Generate a signature for authorization.

    .DESCRIPTION
    Generate a signature for authorization.

    .PARAMETER WorkspaceID
    The ID of the log analytics workspace.

    .PARAMETER SharedKey
    The primary or secondary key for the log analytics workspace.

    .PARAMETER ContentLength
    The length of the payload being sent to the API.

    .PARAMETER Date
    The date to be used for authorization and in the request headers. Must be in RFC1123 format.

    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceID,
        [Parameter(Mandatory = $true)]
        [string]$SharedKey,
        [Parameter(Mandatory = $true)]
        [int]$ContentLength,
        [Parameter(Mandatory = $true)]
        [string]$Date
    )

    $Resource = "/api/logs"
    $ContentType = "application/json"
    $Method = "POST"
    $Headers = "x-ms-date:${Date}"
    $StringToHash = $Method + "`n" + $ContentLength + "`n" + $ContentType + "`n" + $Headers + "`n" + $Resource

    $BytesToHash = [Text.Encoding]::UTF8.GetBytes($StringToHash)
    $KeyBytes = [Convert]::FromBase64String($SharedKey)

    $Sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $Sha256.Key = $KeyBytes
    $CalculatedHash = $Sha256.ComputeHash($BytesToHash)
    $EncodedHash = [Convert]::ToBase64String($CalculatedHash)
    $Authorization = "SharedKey ${WorkspaceID}:${EncodedHash}"

    Write-Output $Authorization
}

function Send-LogAnalyticsPayload {
    <#
    .SYNOPSIS
    Send a payload to the log analytics ingestion api.

    .DESCRIPTION
    Send a payload to the log analytics ingestion api.

    .PARAMETER Body
    A serialized object representing the data to send.

    .PARAMETER LogType
    The type name of the custom log.

    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Body,
        [Parameter(Mandatory = $true)]
        [string]$LogType
    )

    if ($Body) {
        # --- To be pulled from env
        $WorkspaceID = $ENV:LOG_ANALYTICS_WORKSPACE_ID
        $SharedKey = $ENV:LOG_ANALYTICS_WORKSPACE_KEY
        $Date = [DateTime]::UtcNow.ToString("r")

        $NewSignatureParameters = @{
            WorkspaceID   = $WorkspaceID
            SharedKey     = $SharedKey
            ContentLength = $Body.Length
            Date          = $Date
        }

        $Signature = New-Signature @NewSignatureParameters

        $Headers = @{
            "Authorization" = $Signature
            "Log-Type"      = $LogType
            "x-ms-date"     = $Date
        }

        $InvokeRestMethodParameters = @{
            Uri             = "https://${WorkspaceId}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01"
            Method          = "POST"
            ContentType     = "application/json"
            Headers         = $Headers
            Body            = ([System.Text.Encoding]::UTF8.GetBytes($Body))
            UseBasicParsing = $true
        }

        try {
            Write-Information "Sending metric payload to Log Analytics workspace ${WorkspaceID} as type ${LogType}"
            Invoke-RestMethod @InvokeRestMethodParameters -ErrorAction Stop
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

    } else {

        $Exception = [Exception]::("The Body parameter was null or empty. The function won't continue because a payload is required.", $_)
        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
            $Exception,
            "1",
            [System.Management.Automation.ErrorCategory]::InvalidData
        )
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
}

function Invoke-ODataRestMethod {
    <#
    .SYNOPSIS
    A generic wrapper for Invoke-RestMethod for use with OData Apis.

    .DESCRIPTION
    A generic wrapper for Invoke-RestMethod for use with OData Apis.

    .PARAMETER EntitySet
    The name of the odata entityset to query.

    .PARAMETER Query
    The odata query to send.

    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$EntitySet,
        [Parameter(Mandatory = $false)]
        [String]$Query
    )

    $AnalyticsBaseURI = "https://analytics.dev.azure.com/${ENV:AZURE_DEVOPS_ORGANIZATION}/${ENV:AZURE_DEVOPS_PROJECT}/_odata/v3.0-preview"
    $AuthenticationToken = $ENV:AZURE_DEVOPS_ACCESS_TOKEN

    $Base64Authentication = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("pat-token:$AuthenticationToken")))
    $Headers = @{
        Authorization = "Basic $Base64Authentication"
        Accept        = "application/json; odata=verbose"
    }

    $RequestURI = "${AnalyticsBaseURI}/${EntitySet}?${Query}"

    $InvokeRestMethodParameters = @{
        Uri         = $RequestURI
        Headers     = $Headers
        Method      = "GET"
        ErrorAction = "STOP"
    }

    try {
        $Response = Invoke-RestMethod @InvokeRestMethodParameters -Verbose:$VerbosePreference

        if ($Response."@vsts.warnings") {
            $Response."@vsts.warnings" | ForEach-Object {
                Write-Warning -Message "$_"
            }
        }

        Write-Output $Response

    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Invoke-VstsRestMethod {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$Uri,
        [Parameter(Mandatory = $false)]
        [ValidateSet("VSRM", "None")]
        [String]$Service = "None",
        [Parameter(Mandatory = $false)]
        [ValidateSet("5.1","6.0-preview.2","6.0-preview.4","6.0-preview.6")]
        [String]$ApiVersion
    )


    switch($Service){
        "VSRM" {
            $ApiService = "vsrm.dev.azure.com"
            break
        }

        default {
            $ApiService = "dev.azure.com"
        }
    }

    $FullUri = "https://${ApiService}/${ENV:AZURE_DEVOPS_ORGANIZATION}/${ENV:AZURE_DEVOPS_PROJECT}/_apis/${Uri}?api-version=${ApiVersion}"

    $AuthenticationToken = $ENV:AZURE_DEVOPS_ACCESS_TOKEN

    $Base64Authentication = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("pat-token:$AuthenticationToken")))
    $Headers = @{
        Authorization = "Basic $Base64Authentication"
        Accept        = "application/json"
    }

    try {
        $InvokeRestMethodParameters = @{
            Method  = "GET"
            Uri = $FullUri
            Headers = $Headers
            ErrorAction = "Stop"
            ResponseHeadersVariable = "ResponseHeaders"
        }

        $Response = Invoke-RestMethod @InvokeRestMethodParameters -Verbose:$VerbosePreference

        [PSCustomObject]@{
            Headers = $ResponseHeaders
            Response = $Response
        }

    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function @(
    "Send-LogAnalyticsPayload",
    "Invoke-ODataRestMethod",
    "Invoke-VstsRestMethod"
)
