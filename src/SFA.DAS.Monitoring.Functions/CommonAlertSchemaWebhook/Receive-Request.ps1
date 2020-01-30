
param($Request, $TriggerMetadata)

try {

    $GLOBAL:Configuration = [ConfigurationBuilder]::New()
    $Configuration.SetBasePath()
    $Configuration.AddJsonFile("local.settings.json")
    $Configuration.AddEnvironmentVariables()
    $Configuration.Build()

    Test-RequestBody -Body $Request.Body
    Write-Information ($Request.Body | ConvertTo-Json -Depth 10)

    $AlertData = $Request.Body.data

    switch -wildcard ($AlertData.essentials.alertRule){

        "TEST - ZenDesk*" {
            $Channel = $Configuration.Get("SLACK_ZENDESKDEV_CHANNEL")
            Write-Information "Overriding SLACK_DEFAULT_CHANNEL with Slack channel $channel"
            break
        }

        "PROD - ZenDesk*" {
            $Channel = $Configuration.Get("SLACK_ZENDESKLIVE_CHANNEL")
            Write-Information "Overriding SLACK_DEFAULT_CHANNEL with Slack channel $channel"
            break
        }

        default {
            $Channel = $Configuration.Get("SLACK_DEFAULT_CHANNEL")
            break
        }

    }

    $Message = New-Message -AlertData $AlertData -Channel $Channel
    Send-SlackMessage -Message $Message -Channel $Channel
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
