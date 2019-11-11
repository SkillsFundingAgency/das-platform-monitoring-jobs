class ConfigurationBuilder {

    hidden [string]$BasePath
    hidden [System.Collections.ArrayList]$ConfigurationList
    hidden [hashtable]$Configuration
    hidden [Object[]]$AppSettingArray
    hidden [String]$EnvironmentName

    ConfigurationBuilder() {
        $this.Configuration = @{ }
    }

    [void] SetBasePath() {
        $this.BasePath = (Get-Location).Path
        Write-Information "Base path set to $($this.BasePath)"
    }

    [void] AddJsonFile([string]$FileName) {

        if (!$this.BasePath) {
            throw "Base path has not been set. You must use SetBasePath when building configuration"
        }
        Write-Information "Adding deserialized json file: $FileName"
        $FullFilePath = Join-Path -Path $this.BasePath -ChildPath $FileName -Resolve -ErrorAction Stop
        $DeserializedFileContent = Get-Content -Path $FullFilePath -Raw | ConvertFrom-Json -AsHashtable

        if (!$DeserializedFileContent.Values) {
            $this.ProcessHashtable($DeserializedFileContent.Values)
        }
        else {
            $this.ProcessHashtable($DeserializedFileContent)
        }
    }

    [void] AddEnvironmentVariables() {
        Write-Information "Adding environment variables"
        $Environment = Get-Item -Path Env:\
        $Environment | ForEach-Object {
            $this.Configuration.Add($_.Key, $_.Value)
        }
    }

    [void] Build() {
        Write-Information "Configuration initialized with $($this.Configuration.Count) properties"
    }

    [String] Get([String]$Name) {

        Write-Debug -Message "Retrieving setting [$NAME] from environment"
        $Value = $this.Configuration.Get_Item($Name)
        if (!$Value) {
            Write-Error -Message "App Setting $($Name) could not be found" -ErrorAction Stop
        }
        return $Value
    }

    [String[]] Keys() {
        return $this.Configuration.Keys
    }

    [int] Count() {
        return $this.Configuration.Count
    }

    hidden [void] ProcessHashtable([hashtable]$Value) {
        $Value.GetEnumerator() | ForEach-Object {
            if ($this.Configuration[$_.Key]) {
                Write-Verbose -Message "Updating existing property [$($_.Key)]"
                $this.Configuration[$_.Key] = $_.Value
            }
            else {
                $this.Configuration.Add($_.Key, $_.Value)
            }
        }
    }
}
