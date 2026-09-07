# New-PoshWebGUI

Host a `localhost` web server from PowerShell and render the responses in a WPF browser window.

> Windows-only. Requires `HttpListener` + WPF (`PresentationFramework`): Windows PowerShell 5.1 or PowerShell 7 on Windows.

## Quick start

```powershell
Import-Module ./New-PoshWebGUI.psd1

Start-PoshWebGUI -ScriptBlock {
    "<html><body><h1>Hello World!</h1></body></html>"
}
```

Closing the window shuts the server down (via an authenticated `/kill` URL).

## Runnable example

```powershell
# See Examples/SimpleTaskManager.ps1
.\Examples\SimpleTaskManager.ps1
```

It serves a small task-manager form at `http://localhost:8000/` with
`/loadProcesses?ProcessName=...` and `/loadServices?ServiceName=...` routes.

## Parameters (`Start-PoshWebGUI`)

| Parameter | Default | Notes |
|---|---|---|
| `ScriptBlock` | (mandatory) | Run per request, with `$Context` (`HttpListenerContext`) in scope. Return `[string]` for HTML, any other object becomes JSON. |
| `Port` | `8000` | Localhost port (1–65535). |
| `Title` | `PowerShell HTML GUI` | WPF window title. |
| `KillToken` | auto GUID | Required as `/kill?token=<value>`. Auto-generated per run. |
| `StartupTimeoutSec` | `30` | How long the GUI waits for the server before failing. |
| `NoGUI` | off | Run server loop only (tests/automation). Stop via `/kill?token=<KillToken>`. |

Safe query-string helper:

```powershell
$name = Get-PoshWebGUIQueryValue -Context $Context -Name "ProcessName" -MaxLength 100
$safe = [System.Net.WebUtility]::HtmlEncode($name)
```

## Security model

- Binds **localhost only** (no admin rights needed). Do not bind externally without adding authentication.
- `/kill` requires the per-run `KillToken` (else `403`). The token is generated fresh each run and only passed to the GUI runspace.
- Treat all query input as untrusted: length-cap via `Get-PoshWebGUIQueryValue` and `HtmlEncode` before reflecting into HTML.
- `/favicon.ico` returns `204` (no content).

## Project layout

- `New-PoshWebGUI.ps1` — `Start-PoshWebGUI`, `Get-PoshWebGUIQueryValue`
- `New-PoshWebGUI.psm1` / `.psd1` — module packaging (v1.0.0)
- `Examples/SimpleTaskManager.ps1` — runnable demo
- `Learning/` — original 2016 step-by-step tutorials (historical)
- `Tests/` — Pester tests; `.github/workflows/ci.yml` — PSScriptAnalyzer + Pester

## Development

```powershell
# Static analysis
Invoke-ScriptAnalyzer -Path ./New-PoshWebGUI.ps1, ./New-PoshWebGUI.psm1 -Recurse:$false
# Tests
Invoke-Pester ./Tests
```

## License

MIT — see [LICENSE](./LICENSE).
