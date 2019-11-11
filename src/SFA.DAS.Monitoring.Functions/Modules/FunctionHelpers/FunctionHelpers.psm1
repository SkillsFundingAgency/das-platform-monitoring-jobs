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
    }

    $AcceptedHeaders.Keys | ForEach-Object {
        $Key = $_.ToLower()
        if ($Key -notin $Headers.Keys) {
            $ErrorResponse = "Required header [$Key] has not been supplied as part of the request"
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

function Get-MessageMetadata {
    Param (
        [Parameter(Mandatory = $true)]
        [String]$MonitorCondition
    )

    $ConditionMetadata = @{
        AttachmentColour = $null
        TitleEmoji       = $null
    }

    switch ($MonitorCondition) {
        'Fired' {
            $ConditionMetadata.AttachmentColour = "#D40E0D"
            $ConditionMetadata.TitleEmoji = ":fire:"
            break
        }

        'Resolved' {
            $ConditionMetadata.AttachmentColour = "#49C39E"
            $ConditionMetadata.TitleEmoji = ":heavy_check_mark:"
            break
        }

        default {
            $ConditionMetadata.AttachmentColour = "#80D2DE"
            $ConditionMetadata.TitleEmoji = ":question:"
            break
        }
    }

    Write-Output $ConditionMetadata
}

function Format-MonitoringServiceResponse {
    Param(
        [Parameter(Mandatory = $true)]
        [Hashtable]$AlertData
    )

    $MonitoringService = $AlertData.essentials.monitoringService

    Switch ($MonitoringService) {
        "Application Insights" {
            Write-Debug -Message ($AlertData.alertContext | ConvertTo-Json)

            $EncodedUri = [System.Uri]::EscapeUriString($AlertData.alertContext.LinkToSearchResults)

            $Response = @{
                SearchIntervalDurationMin = $AlertData.alertContext.SearchIntervalDurationMin
                AlertType                 = $AlertData.alertContext.AlertType
                Threshold                 = $AlertData.alertContext.Threshold
                SearchResults             = "<$EncodedUri|Search Results>"
            }
            break
        }

        default {
            Write-Warning -Message "$MonitoringService monitoring service response has not been implemented"
            break
        }
    }

    Write-Output $Response
}

function Format-MessageText {

    Param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AlertData
    )

    $Essentials = $AlertData.essentials
    $AlertContext = Format-MonitoringServiceResponse -AlertData $AlertData

    $MessageText = @"
*Impacted resources:*
$(@($Essentials.alertTargetIDs | Foreach-Object {$_.Split('/')[-1]}) -join ' ,')
$(if($Essentials.description){"*Description*:
$($Essentials.description)"})

$(if($AlertContext){"*Details*:
$($AlertContext.Keys | Sort-Object | Foreach-Object {"• *$_* = $($AlertContext[$_])`r`n"})
"})
"@

    Write-Output $MessageText
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
        [String]$WebhookUri,
        [Parameter(Mandatory = $true)]
        [String]$Username,
        [Parameter(Mandatory = $true)]
        [String]$Channel,
        [Parameter(Mandatory = $true)]
        [String]$IconEmoji,
        [Parameter(Mandatory = $true)]
        [String]$AttachmentColour,
        [Parameter(Mandatory = $true)]
        [String]$AttachmentTitle,
        [Parameter(Mandatory = $true)]
        [String]$AttachmentText
    )

    try {

        $Body = @{
            channel     = "#$Channel"
            username    = $Username
            icon_emoji  = $IconEmoji
            attachments = @(
                @{
                    color = $AttachmentColour
                    title = $AttachmentTitle
                    text  = $AttachmentText
                }
            )
        }

        Write-Information "Submitting slack message payload"
        $SerializedMessage = "payload=$($Body | ConvertTo-Json -Compress)"
        Write-Information $SerializedMessage
        Invoke-WebRequest -Uri $WebhookUri -Method POST -UseBasicParsing -Body $SerializedMessage
    }
    catch {
        $ErrorResponse = $_.Exception.Message
        Write-Error -Message $ErrorResponse
        throw $_
    }
}
