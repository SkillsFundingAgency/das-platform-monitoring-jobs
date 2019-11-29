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

    Write-Debug -Message ($AlertData.alertContext | ConvertTo-Json)
    $EncodedUri = [System.Uri]::EscapeUriString($AlertData.alertContext.LinkToSearchResults)
    $SearchResults = "<$EncodedUri|:notebook_with_decorative_cover:>"

    Switch ($MonitoringService) {

        "SmartDetector" {
            $Response = @{
                DetectionSummary = $AlertData.alertContext.DetectionSummary
                FailureRate      = "The usual failure rate for this resource is $($AlertData.alertContext.NormalFailureRate) but this has spiked to $($AlertData.alertContext.DetectedFailureRate)"
            }
            break
        }

        "Application Insights" {
            $Response = @{
                SearchResults = $SearchResults
            }
            break
        }

        "Log Analytics" {
            $Response = @{
                Resource     = ($AlertData.alertContext.AffectedConfigurationItems.Split("/")[-1] -join ", ").ToLower()
                LogAnalytics = $SearchResults
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
$(if($Essentials.description){"*Description*:
$($Essentials.description)"})

$(if($AlertContext){"$($AlertContext.Keys | Sort-Object | Foreach-Object {":black_small_square: *$_*: $($AlertContext[$_])`r`n"})"})
"@

    Write-Output $MessageText
}

function New-Message {
    Param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AlertData,
        [Parameter(Mandatory = $true)]
        [string]$Channel
    )

    $MessageMetadata = Get-MessageMetadata -MonitorCondition $AlertData.essentials.monitorCondition

    $Body = @{
        channel     = "#$Channel"
        username    = $Configuration.Get("SLACK_USERNAME")
        icon_emoji  = $Configuration.Get("SLACK_ICON_EMOJI")
        attachments = @(
            @{
                color = $MessageMetadata.AttachmentColour
                title = "$($MessageMetadata.TitleEmoji) $($AlertData.essentials.alertRule)"
                text  = Format-MessageText -AlertData $AlertData
            }
        )
    }

    Write-Output $Body

}

Export-ModuleMember -Function New-Message
