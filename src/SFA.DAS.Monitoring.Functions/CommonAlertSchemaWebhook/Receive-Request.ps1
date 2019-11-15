
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

    $Channel = $Configuration.Get("SLACK_DEFAULT_CHANNEL")
    if ($Request.Query.Channel) {
        $Channel = $Request.Query.Channel
        Write-Information "Overriding SLACK_DEFAULT_CHANNEL with parameter $Channel"
    }

    $Message = New-Message -AlertData $AlertData -Channel $Channel
    Send-SlackMessage -Message $Message
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
