param($Request, $TriggerMetadata)

function New-AdaptiveCardFromMonitor {
    param([hashtable]$Essentials)

    $alertRule = [string]$Essentials.alertRule
    $sev       = [string]$Essentials.severity
    $cond      = [string]$Essentials.monitorCondition
    $fired     = [string]$Essentials.firedDateTime
    $link      = $Essentials.portalLink
    if ([string]::IsNullOrWhiteSpace($link)) { $link = $Essentials.investigationLink }

    $resource  = $null
    if ($Essentials.alertTargetIDs -and $Essentials.alertTargetIDs.Count -gt 0) {
        $resource = [string]$Essentials.alertTargetIDs[0]
    } else {
        $resource = ""
    }

    $desc = ""
    if ($Essentials.description) { $desc = [string]$Essentials.description }

    $color = switch -regex ($sev) {
        '^Sev0|^Sev1' { 'Attention' }
        '^Sev2'      { 'Warning' }
        '^Sev3'      { 'Default' }
        default      { 'Good' }
    }

    $card = @{
        '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
        type      = 'AdaptiveCard'
        version   = '1.5'
        body      = @(
            @{ type='TextBlock'; text=$alertRule; weight='Bolder'; size='Medium'; wrap=$true },
            @{ type='TextBlock'; text=("Severity: {0} · Condition: {1}" -f $sev,$cond); isSubtle=$true; wrap=$true; color=$color },
            @{ type='TextBlock'; text=$desc; wrap=$true },
            @{ type='FactSet'; facts=@(
                @{ title='Resource:'; value=$resource },
                @{ title='Fired:';    value=$fired },
                @{ title='Service:';  value=([string]$Essentials.monitoringService) }
            )}
        )
    }

    if (-not [string]::IsNullOrWhiteSpace($link)) {
        $card.actions = @(
            @{ type='Action.OpenUrl'; title='View in Azure'; url=$link }
        )
    }

    return $card
}

function Send-ToTeamsWebhookFlow {
    param([hashtable]$AdaptiveCard, [string]$FlowUrl)

    $envelope = @{
        type        = 'message'
        attachments = @(@{
            contentType = 'application/vnd.microsoft.card.adaptive'
            content     = $AdaptiveCard
        })
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $json = $envelope | ConvertTo-Json -Depth 20

    Write-Information ("Flow URL host: " + ([uri]$FlowUrl).Host)
    Write-Information ("Payload preview: " + ($json.Substring(0,[Math]::Min(300,$json.Length))))

    try {
        $resp = Invoke-RestMethod -Method POST -Uri $FlowUrl -ContentType 'application/json' -Body $json -ErrorAction Stop
        Write-Information "Flow status: 202 Accepted"
    }
    catch {
        $respObj = $_.Exception.Response
        if ($respObj -is [System.Net.Http.HttpResponseMessage]) {
            $errBody = $respObj.Content.ReadAsStringAsync().Result
            Write-Error ("Flow HTTP " + [int]$respObj.StatusCode + ": " + $errBody)
        } elseif ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            Write-Error $_.ErrorDetails.Message
        } else {
            Write-Error $_.Exception.Message
        }
        throw
    }
}

try {
    $GLOBAL:Configuration = [ConfigurationBuilder]::New()
    $Configuration.SetBasePath()
    $Configuration.AddEnvironmentVariables()
    $Configuration.Build()

    Test-RequestBody -Body $Request.Body
    Write-Information ($Request.Body | ConvertTo-Json -Depth 10)

    $AlertData  = $Request.Body.data
    $Essentials = $AlertData.essentials

    $flowUrl = $Configuration.Get("POWER_AUTOMATE_TEAMS_WEBHOOK_URL")
    if (-not $flowUrl) { throw "POWER_AUTOMATE_TEAMS_WEBHOOK_URL not set" }

    $card = New-AdaptiveCardFromMonitor -Essentials $Essentials
    Send-ToTeamsWebhookFlow -AdaptiveCard $card -FlowUrl $flowUrl

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