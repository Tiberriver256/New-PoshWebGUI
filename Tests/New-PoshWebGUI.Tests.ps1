#Requires -Modules Pester
<#
.SYNOPSIS
    Static/unit tests for New-PoshWebGUI. No HttpListener or WPF required.
#>

BeforeAll {
    $ModuleRoot = Split-Path $PSScriptRoot -Parent
    $MainScript = Join-Path $ModuleRoot 'New-PoshWebGUI.ps1'
    $Manifest = Join-Path $ModuleRoot 'New-PoshWebGUI.psd1'
    $Source = Get-Content $MainScript -Raw
}

Describe 'Module packaging' {
    It 'has a manifest with expected metadata' {
        Test-Path $Manifest | Should -Be $true
        $data = Import-PowerShellDataFile $Manifest
        $data.RootModule | Should -Be 'New-PoshWebGUI.psm1'
        $data.FunctionsToExport | Should -Contain 'Start-PoshWebGUI'
        $data.FunctionsToExport | Should -Contain 'Get-PoshWebGUIQueryValue'
        $data.PowerShellVersion | Should -Be '5.1'
    }

    It 'psm1 dot-sources the ps1' {
        $psm1 = Get-Content (Join-Path $ModuleRoot 'New-PoshWebGUI.psm1') -Raw
        $psm1 | Should -Match 'New-PoshWebGUI\.ps1'
        $psm1 | Should -Match 'Export-ModuleMember'
    }

    It 'example exists and has no hardcoded machine paths' {
        $example = Join-Path $ModuleRoot 'Examples/SimpleTaskManager.ps1'
        Test-Path $example | Should -Be $true
        $text = Get-Content $example -Raw
        $text | Should -Match 'Start-PoshWebGUI'
        $text | Should -Not -Match 'C:\\cms'
        $text | Should -Not -Match 'Haworth\.ico'
    }
}

Describe 'Reliability fixes' {
    It 'exposes Port, Title, KillToken, StartupTimeoutSec, NoGUI parameters' {
        $Source | Should -Match 'param\('
        $Source | Should -Match '\$Port'
        $Source | Should -Match '\$Title'
        $Source | Should -Match '\$KillToken'
        $Source | Should -Match '\$StartupTimeoutSec'
        $Source | Should -Match '\$NoGUI'
    }

    It 'uses loop+timeout instead of recursive Wait-ServerLaunch' {
        $Source | Should -Not -Match 'function Wait-ServerLaunch'
        $Source | Should -Match 'AddSeconds\(\$TimeoutSec\)'
    }

    It 'cleans up listener and runspace in finally' {
        $Source | Should -Match 'finally'
        $Source | Should -Match '\$SimpleServer\.Close\(\)'
        $Source | Should -Match '\$RunspacePool\.Dispose\(\)'
    }

    It 'uses UTF8 and sets ContentType' {
        $Source | Should -Match "UTF8\.GetBytes"
        $Source | Should -Match 'ContentType'
        $Source | Should -Not -Match 'ASCII\.GetBytes'
    }
}

Describe 'Security' {
    It 'requires a token for /kill and returns 403 otherwise' {
        $Source | Should -Match "QueryString\['token'\]"
        $Source | Should -Match '403'
    }

    It 'ships a safe query helper with length cap' {
        $Source | Should -Match 'function Get-PoshWebGUIQueryValue'
        $Source | Should -Match 'MaxLength'
    }

    It 'example HTML-encodes reflected input and escapes wildcards' {
        $text = Get-Content (Join-Path $ModuleRoot 'Examples/SimpleTaskManager.ps1') -Raw
        $text | Should -Match 'HtmlEncode'
        $text | Should -Match 'WildcardPattern\]::Escape'
    }
}

Describe 'Modernized APIs' {
    It 'does not use LoadWithPartialName or WebClient in main module' {
        $Source | Should -Not -Match 'LoadWithPartialName'
        $Source | Should -Not -Match 'System\.Net\.WebClient'
    }

    It 'loads WPF via Add-Type and uses Invoke-WebRequest' {
        $Source | Should -Match "Add-Type -AssemblyName PresentationFramework"
        $Source | Should -Match 'Invoke-WebRequest'
    }

    It 'has no hardcoded machine-specific icon path' {
        $Source | Should -Not -Match 'C:\\cms'
        $Source | Should -Not -Match 'Haworth\.ico'
        $learning = Get-Content (Join-Path $ModuleRoot 'Learning/4_GettingToTheGUI.ps1') -Raw
        $learning | Should -Not -Match 'C:\\cms\\OneDrive Fix\\Haworth\.ico'
    }
}
