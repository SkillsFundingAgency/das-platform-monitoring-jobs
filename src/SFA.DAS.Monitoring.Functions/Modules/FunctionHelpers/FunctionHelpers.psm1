function Push-OutputBindingWrapper {
    <#
.SYNOPSIS

A wrapper for pushing an HTTP Status and Body text to the azure functions output binding

.DESCRIPTION

A wrapper for pushing an HTTP Status and Body text to the azure functions output binding

.Parameter Status

HttpStatusCode. A member of the HttpStatusCode enumberation to send as the result of the current operation

.Parameter Body

String.  The text to return to the client.

#>

    Param(
        [Parameter(Mandatory = $true)]
        [HttpStatusCode] $StatusCode,
        [Parameter(Mandatory = $true)]
        [string] $Body
    )

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{
                statusCode = $StatusCode
                message    = $Body
            }
        }) -Clobber
}

function Test-RequestHeaders {
    Param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    Write-Debug -Message "Testing request headers for valid entries [$($Headers.Keys)]"

    $AcceptedHeaders = @{
        'Content-Type' = "application/json"
        'charset'      = 'utf-8'
    }

    $AcceptedHeaders.Keys | ForEach-Object {
        $Key = $_.ToLower()
        if ($Key -notin $Headers.Keys) {
            $ErrorResponse = "Required header has not been supplied as part of the request. Accepted values are [$($AcceptedHeaders.Keys -join ",")]"
            Write-Error -Message $ErrorResponse
            throw [System.FormatException]$ErrorResponse
        }

        if ($Headers[$Key] -ne $AcceptedHeaders[$Key]) {
            $ErrorResponse = "Value for $Key does not match expected value [Given: $($Headers[$Key]) != Expected: $($AcceptedHeaders[$Key])]"
            Write-Error -Message $ErrorResponse
            throw [System.FormatException]$ErrorResponse
        }
    }
}

function Test-RequestBody {
    Param(
        [Parameter(Mandatory = $false)]
        [Hashtable]$Body
    )

    if ([String]::IsNullOrWhiteSpace($Body)) {
        $ErrorResponse = "The request body did not contain any data"
        Write-Error -Message $ErrorResponse
        throw [System.FormatException]$ErrorResponse
    }

    if ($Body.schemaId -ne "azureMonitorCommonAlertSchema") {
        $ErrorResponse = "Expected schemaId 'azureMonitorCommonAlertSchema' but got '$($Body.schemaId)'"
        Write-Error -Message $ErrorResponse
        throw [System.FormatException]$ErrorResponse
    }
}

function Send-SlackMessage {
    <#
.SYNOPSIS

Sends a message to Slack

.DESCRIPTION

Sends an hashtable to slack using the given token.

.Parameter slackToken

String. The slack token to use to communicate with slack.

.Parameter message

hashtable.  A hashtable representing the message to send to slack.
#>

    Param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Message
    )

    try {

        Write-Information "Submitting slack message payload"
        $SerializedMessage = "payload=$($Message | ConvertTo-Json -Compress)"
        Write-Information $SerializedMessage
        Invoke-WebRequest -Uri $Configuration.Get("SLACK_WEBHOOK_URI") -Method POST -UseBasicParsing -Body $SerializedMessage
    }
    catch {
        $ErrorResponse = $_.Exception.Message
        Write-Error -Message $ErrorResponse
        throw $_
    }
}
