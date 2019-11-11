
param($Request, $TriggerMetadata)

try {

    $GLOBAL:Configuration = [ConfigurationBuilder]::New()
    $Configuration.SetBasePath()
    $Configuration.AddJsonFile("local.settings.json")
    $Configuration.AddEnvironmentVariables()
    $Configuration.Build()

    Test-RequestHeaders -Headers $Request.Headers
    Test-RequestBody -Body $Request.Body

    $AlertData = $Request.Body.data
    $Essentials = $AlertData.essentials

    $MessageMetadata = Get-MessageMetadata -MonitorCondition $Essentials.monitorCondition

    $Channel = $Configuration.Get("SLACK_DEFAULT_CHANNEL")
    if ($Request.Query.Channel) {
        $Channel = $Request.Query.Channel
        Write-Information "Overriding SLACK_DEFAULT_CHANNEL with parameter $Channel"
    }

    $SlackMessageParameters = @{
        WebhookUri       = $Configuration.Get("SLACK_WEBHOOK_URI")
        IconEmoji        = $Configuration.Get("SLACK_ICON_EMOJI")
        Username         = $Configuration.Get("SLACK_USERNAME")
        Channel          = $Channel
        AttachmentColour = $MessageMetadata.AttachmentColour
        AttachmentTitle  = "$($MessageMetadata.TitleEmoji) $($Essentials.alertRule) [$($Essentials.monitorCondition)]"
        AttachmentText   = Format-MessageText -AlertData $AlertData
    }

    Send-SlackMessage @SlackMessageParameters
    Push-OutputBindingWrapper -StatusCode 202 -Body "Message accepted"

}
catch [System.FormatException] {
    Push-OutputBindingWrapper -StatusCode 400 -Body $_.Exception.Message
}
catch [Microsoft.PowerShell.Commands.HttpResponseException] {
    Push-OutputBindingWrapper -StatusCode $_.Exception.Response.StatusCode.Value__ -Body $_
}
catch {
    throw $_
}
