# Import the module manifest's RootModule.
. "$PSScriptRoot/New-PoshWebGUI.ps1"

Export-ModuleMember -Function Start-PoshWebGUI, Get-PoshWebGUIQueryValue
