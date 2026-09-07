Function Start-PoshWebGUI {
    <#
    .SYNOPSIS
        Hosts a localhost HttpListener and renders responses in a WPF browser window.
    .DESCRIPTION
        Starts an HttpListener on localhost:Port, invokes ScriptBlock once per
        request (with $Context in scope), and shows the result in a WPF window.
        Closing the window shuts the server down via an authenticated /kill URL.

        Windows-only: requires HttpListener + WPF (PresentationFramework), i.e.
        Windows PowerShell 5.1 or PowerShell 7 on Windows.
    .PARAMETER ScriptBlock
        Code run per request. $Context (HttpListenerContext) is in scope.
        Return a [string] for raw HTML, or any object (converted to JSON).
    .PARAMETER Port
        Localhost TCP port to listen on. Default 8000. Range 1-65535.
    .PARAMETER Title
        Window title. Default 'PowerShell HTML GUI'.
    .PARAMETER KillToken
        Token required to hit /kill?token=<value>. Auto-generated (GUID) if omitted.
    .PARAMETER StartupTimeoutSec
        How long the GUI waits for the server before giving up. Default 30.
    .PARAMETER NoGUI
        Start the server loop without opening the WPF window (useful for tests/automation).
        The caller must request /kill?token=<KillToken> to stop the server.
    .EXAMPLE
        Start-PoshWebGUI -ScriptBlock { "<html><body>Hello World!</body></html>" }
    .EXAMPLE
        Start-PoshWebGUI -Port 8080 -Title "Task Manager" -ScriptBlock {
            switch ($Context.Request.Url.LocalPath) {
                "/loadProcesses" {
                    # Query values should be treated as untrusted input:
                    $name = Get-PoshWebGUIQueryValue -Context $Context -Name "ProcessName" -MaxLength 100
                    Get-Process -Name $name -ErrorAction SilentlyContinue |
                        Select-Object Name, CPU | ConvertTo-Html | Out-String
                }
                default { "<h1>Simple Task Manager</h1>" }
            }
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 8000,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Title = 'PowerShell HTML GUI',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$KillToken = ([System.Guid]::NewGuid().ToString('N')),

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$StartupTimeoutSec = 30,

        [Parameter()]
        [switch]$NoGUI
    )

    $BaseUrl = "http://localhost:$Port/"

    # The GUI runs in its own STA runspace so the server loop can block on GetContext().
    $UserWindow = {
        param($BaseUrl, $KillToken, $WindowTitle, $TimeoutSec)

        # Poll until the server answers (loop + timeout, no recursion).
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        while ((Get-Date) -lt $deadline) {
            try {
                Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec 5 | Out-Null
                break
            }
            catch {
                Start-Sleep -Seconds 1
            }
        }

        try {
            Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec 5 | Out-Null
        }
        catch {
            Write-Error "Start-PoshWebGUI: server did not start within $TimeoutSec seconds ($BaseUrl)."
            return
        }

        Add-Type -AssemblyName PresentationFramework
        [xml]$XAML = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="PowerShell HTML GUI" WindowStartupLocation="CenterScreen">
        <WebBrowser Name="WebBrowser"></WebBrowser>
</Window>
'@
        $reader = New-Object System.Xml.XmlNodeReader $XAML
        $Form = [Windows.Markup.XamlReader]::Load($reader)
        $Form.Title = $WindowTitle
        $WebBrowser = $Form.FindName('WebBrowser')
        $WebBrowser.Navigate($BaseUrl)

        $Form.ShowDialog() | Out-Null
        Start-Sleep -Seconds 1

        # Authenticated shutdown: only a caller holding the token can stop the server.
        try {
            Invoke-WebRequest -Uri ("{0}kill?token={1}" -f $BaseUrl, $KillToken) -UseBasicParsing -TimeoutSec 5 | Out-Null
        }
        catch {
            Write-Verbose "Shutdown request failed (server may already be stopped): $_"
        }
    }

    $RunspacePool = $null
    $guiPowerShell = $null
    $guiHandle = $null
    $SimpleServer = $null

    try {
        if (-not $NoGUI) {
            $RunspacePool = [runspacefactory]::CreateRunspacePool()
            $RunspacePool.ApartmentState = 'STA'
            $RunspacePool.Open()

            $guiPowerShell = [powershell]::Create()
            $guiPowerShell.RunspacePool = $RunspacePool
            [void]$guiPowerShell.AddScript($UserWindow).AddArgument($BaseUrl).AddArgument($KillToken).AddArgument($Title).AddArgument($StartupTimeoutSec)
            $guiHandle = $guiPowerShell.BeginInvoke()
        }

        $SimpleServer = New-Object Net.HttpListener
        # Localhost only: no admin rights required. Never bind externally without adding authentication.
        $SimpleServer.Prefixes.Add($BaseUrl)
        $SimpleServer.Start()

        Write-Verbose "Listening on $BaseUrl"
        while ($SimpleServer.IsListening) {
            Write-Verbose 'Listening for request'
            $Context = $SimpleServer.GetContext()
            Write-Verbose 'Context has been captured'

            # Browsers request /favicon.ico automatically; answer empty instead of nesting GetContext().
            if ($Context.Request.Url.LocalPath -eq '/favicon.ico') {
                $Context.Response.StatusCode = 204
                $Context.Response.Close()
                continue
            }

            # Authenticated shutdown endpoint.
            if ($Context.Request.Url.LocalPath -eq '/kill') {
                if ($Context.Request.QueryString['token'] -ne $KillToken) {
                    $denied = [System.Text.Encoding]::UTF8.GetBytes('Forbidden')
                    $Context.Response.StatusCode = 403
                    $Context.Response.ContentType = 'text/plain; charset=utf-8'
                    $Context.Response.ContentLength64 = $denied.Length
                    $Context.Response.OutputStream.Write($denied, 0, $denied.Length)
                    $Context.Response.Close()
                    continue
                }
                $Context.Response.StatusCode = 200
                $Context.Response.Close()
                $SimpleServer.Stop()
                break
            }

            $statusCode = 200
            $result = try { . $ScriptBlock } catch {
                $statusCode = 500
                $msg = [System.Net.WebUtility]::HtmlEncode($_.Exception.Message)
                "<html><body><h1>500 Server Error</h1><p>$msg</p></body></html>"
            }

            $contentType = 'text/html; charset=utf-8'
            if ($null -eq $result) {
                $result = ''
            }
            elseif ($result -isnot [string]) {
                Write-Verbose 'Converting PS Objects into JSON objects'
                $result = $result | ConvertTo-Json
                $contentType = 'application/json; charset=utf-8'
            }
            else {
                Write-Verbose 'A [string] object was returned. Writing it directly to the response stream.'
            }

            Write-Verbose "Sending response of $result"

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($result)
            $Context.Response.StatusCode = $statusCode
            $Context.Response.ContentType = $contentType
            $Context.Response.ContentLength64 = $buffer.Length
            $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
            $Context.Response.Close()
        }
    }
    finally {
        try {
            if ($SimpleServer -ne $null) {
                if ($SimpleServer.IsListening) { $SimpleServer.Stop() }
                $SimpleServer.Close()
            }
        }
        catch { Write-Verbose "Listener cleanup: $_" }

        try {
            if ($guiHandle -ne $null -and $guiPowerShell -ne $null) {
                # Wait briefly for the GUI runspace to finish its shutdown request.
                [void]$guiHandle.AsyncWaitHandle.WaitOne(5000)
                $guiPowerShell.EndInvoke($guiHandle)
            }
        }
        catch { Write-Verbose "GUI runspace cleanup: $_" }
        finally {
            if ($guiPowerShell -ne $null) { $guiPowerShell.Dispose() }
            if ($RunspacePool -ne $null) { $RunspacePool.Close(); $RunspacePool.Dispose() }
        }
    }
}

Function Get-PoshWebGUIQueryValue {
    <#
    .SYNOPSIS
        Safely read a single query-string value (HTML-decoded, length-capped).
    .DESCRIPTION
        Treats all query input as untrusted. Returns '' when missing.
        Pair with [System.Net.WebUtility]::HtmlEncode before reflecting into HTML.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerContext]$Context,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateRange(1, 4096)]
        [int]$MaxLength = 200
    )

    $value = $Context.Request.QueryString[$Name]
    if ($null -eq $value) { return '' }
    $value = $value.Trim()
    if ($value.Length -gt $MaxLength) { $value = $value.Substring(0, $MaxLength) }
    return $value
}
