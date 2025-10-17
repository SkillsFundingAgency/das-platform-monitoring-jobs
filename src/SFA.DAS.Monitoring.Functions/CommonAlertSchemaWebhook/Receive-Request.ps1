
param($Request, $TriggerMetadata)

function Sanitize-Ascii {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    return ($Text -replace '[^\u0009\u000A\u000D\u0020-\u007E]', ' ')
}

function Build-AdaptiveCard-Min {
    param([hashtable]$Ess)

    $title = Sanitize-Ascii([string]($Ess.alertRule ?? 'Alert'))
    if ([string]::IsNullOrWhiteSpace($title)) { $title = 'Alert' }

    $sev   = Sanitize-Ascii([string]$Ess.severity)
    $cond  = Sanitize-Ascii([string]$Ess.monitorCondition)

    $desc = ""
    if ($Ess.description) {
        $desc = Sanitize-Ascii([string]$Ess.description)
        if ($desc.Length -gt 6000) { $desc = $desc.Substring(0,6000) + "..." }
    }

    $facts = @()
    if ($Ess.alertTargetIDs -and $Ess.alertTargetIDs.Count -gt 0) {
        $facts += @{ title='Resource:'; value= Sanitize-Ascii([string]$Ess.alertTargetIDs[0]) }
    }
    if ($Ess.monitoringService) {
        $facts += @{ title='Service:';  value= Sanitize-Ascii([string]$Ess.monitoringService) }
    }
    if ($Ess.firedDateTime) {
        $facts += @{ title='Fired:';    value= Sanitize-Ascii([string]$Ess.firedDateTime) }
    }
    if ($sev)  { $facts += @{ title='Severity:'; value= $sev } }
    if ($cond) { $facts += @{ title='State:';    value= $cond } }

    $body = @(
        @{ type='TextBlock'; text=$title; weight='Bolder'; size='Medium'; wrap=$true },
        @{ type='TextBlock'; text=("Severity: {0} | Condition: {1}" -f $sev,$cond); isSubtle=$true; wrap=$true }
    )

    if (-not [string]::IsNullOrWhiteSpace($desc)) {
        $body += @{ type='TextBlock'; text=$desc; wrap=$true }
    }

    if ($facts.Count -gt 0) {
        $body += @{ type='FactSet'; facts=$facts }
    }

    return @{
        '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
        type      = 'AdaptiveCard'
        version   = '1.4'
        body      = $body
    }
}

function Post-ToFlow-AttachmentsOnly {
    param([hashtable]$Card, [string]$Url)

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $fallbackText = ($Card.body | Where-Object { $_.type -eq 'TextBlock' } | Select-Object -First 1 -ExpandProperty text)
    if (-not $fallbackText) { $fallbackText = 'Alert' }
    $fallbackText = Sanitize-Ascii($fallbackText)

    $payload = @{
        type = 'message'
        text = $fallbackText
        attachments = @(@{
            contentType = 'application/vnd.microsoft.card.adaptive'
            content     = $Card
        })
    }

    $json   = ($payload | ConvertTo-Json -Depth 20)
    $utf8   = New-Object System.Text.UTF8Encoding($false)
    $bytes  = $utf8.GetBytes($json)
    $ctype  = 'application/json; charset=utf-8'

    Write-Information ("Flow host: " + ([uri]$Url).Host)
    Write-Information ("Payload length: " + $bytes.Length)
    Write-Information ("Payload first 300: " + ($json.Substring(0,[Math]::Min(300,$json.Length))))

    try {
        $resp = Invoke-RestMethod -Method POST -Uri $Url -ContentType $ctype -Body $bytes -ErrorAction Stop
        Write-Information "Flow accepted (HTTP 200/202)."
    }
    catch {
        $status  = -1
        $errBody = ""
        try {
            if ($_.Exception.Response) {
                try { $status = [int]$_.Exception.Response.StatusCode } catch {}
                try {
                    if ($_.Exception.Response.Content -and $_.Exception.Response.Content.ReadAsStringAsync) {
                        $errBody = $_.Exception.Response.Content.ReadAsStringAsync().Result
                    }
                } catch {}
            }
        } catch {}
        if (-not $errBody -and $_.ErrorDetails -and $_.ErrorDetails.Message) { $errBody = $_.ErrorDetails.Message }
        if (-not $errBody) { $errBody = $_.Exception.Message }
        Write-Error ("Flow HTTP {0}: {1}" -f $status,$errBody)
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

    $flowUrl = $Configuration.Get("POWER_AUTOMATE_TEAMS_WEBHOOK_URL")
    if (-not $flowUrl) { throw "POWER_AUTOMATE_TEAMS_WEBHOOK_URL not set" }

    $ess  = $Request.Body.data.essentials
    $card = Build-AdaptiveCard-Min -Ess $ess
    Post-ToFlow-AttachmentsOnly -Card $card -Url $flowUrl

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
