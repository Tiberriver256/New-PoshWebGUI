@{
    RootModule        = 'New-PoshWebGUI.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b3d7f1a2-4c5e-4a8f-9d0b-7e6a5c4b3a29'
    Author            = 'Micah Rairdon'
    Description       = 'Host a localhost HttpListener and render responses in a WPF browser window.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport = @('Start-PoshWebGUI', 'Get-PoshWebGUIQueryValue')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags = @('GUI', 'HttpListener', 'WPF', 'Windows')
            # TODO: publish to the PowerShell Gallery, then set:
            # LicenseUri = 'https://github.com/Tiberriver256/New-PoshWebGUI/blob/master/LICENSE'
            # ProjectUri = 'https://github.com/Tiberriver256/New-PoshWebGUI'
        }
    }
}
