#Requires -Version 5.1
<#
.SYNOPSIS
    Runnable Simple Task Manager demo for New-PoshWebGUI.
.DESCRIPTION
    Serves a small HTML form at http://localhost:<Port>/ with
    /loadProcesses and /loadServices routes. Query input is length-capped
    and HTML-encoded before reflection. Windows-only (HttpListener + WPF).
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 8000
)

Import-Module "$PSScriptRoot/../New-PoshWebGUI.psd1" -Force

Start-PoshWebGUI -Port $Port -Title 'Simple Task Manager' -ScriptBlock {
    switch ($Context.Request.Url.LocalPath) {
        '/loadProcesses' {
            $filter = Get-PoshWebGUIQueryValue -Context $Context -Name 'ProcessName' -MaxLength 100
            $safe = [System.Net.WebUtility]::HtmlEncode($filter)
            $procs = if ([string]::IsNullOrWhiteSpace($filter)) {
                Get-Process -ErrorAction SilentlyContinue
            }
            else {
                # Wildcard Lookup: escape user input so '*' etc. can't broaden the match unintentionally.
                $pattern = [System.Management.Automation.WildcardPattern]::Escape($filter) + '*'
                Get-Process -Name $pattern -ErrorAction SilentlyContinue
            }
            $table = $procs | Select-Object Name, CPU | ConvertTo-Html -Fragment | Out-String
            "<html><body><h1>Processes matching '$safe'</h1>$table<p><a href='/'>Back</a></p></body></html>"
        }
        '/loadServices' {
            $filter = Get-PoshWebGUIQueryValue -Context $Context -Name 'ServiceName' -MaxLength 100
            $safe = [System.Net.WebUtility]::HtmlEncode($filter)
            $svcs = if ([string]::IsNullOrWhiteSpace($filter)) {
                Get-Service -ErrorAction SilentlyContinue
            }
            else {
                $pattern = [System.Management.Automation.WildcardPattern]::Escape($filter) + '*'
                Get-Service -Name $pattern -ErrorAction SilentlyContinue
            }
            $table = $svcs | Select-Object Status, Name, DisplayName | ConvertTo-Html -Fragment | Out-String
            "<html><body><h1>Services matching '$safe'</h1>$table<p><a href='/'>Back</a></p></body></html>"
        }
        default {
            @'
<html><body>
<h1>Simple Task Manager</h1>
<form action="/loadProcesses">
    <h2>Load Processes</h2>
    <p>Filter by name</p>
    <input name="ProcessName"></input>
    <button type="submit">Submit</button>
</form>
<form action="/loadServices">
    <h2>Load Services</h2>
    <p>Filter by name</p>
    <input name="ServiceName"></input>
    <button type="submit">Submit</button>
</form>
</body></html>
'@
        }
    }
}
