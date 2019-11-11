@{
    # Script module or binary module file associated with this manifest.
    RootModule = '.\FunctionHelpers.psm1'

    # Version number of this module.
    ModuleVersion = '0.1'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID = '9a4e51ee-0b2a-4f45-bd40-ee7d45ed1dfd'

    # Author of this module
    Author = 'Craig Gumbley'

    # Company or vendor of this module
    CompanyName = 'helloitscraig.co.uk'

    # Copyright statement for this module
    Copyright = '(c) 2019 Craig Gumbley. All rights reserved.'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Push-OutputBindingWrapper',
        'Test-RequestBody',
        'Test-RequestHeaders',
        'Get-MessageMetadata',
        'Format-MessageText',
        'Send-SlackMessage'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
        }
    }
}
