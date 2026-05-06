param (
    [string]$env
)

& "$PSScriptRoot\export_web.ps1" -env $env
& "$PSScriptRoot\serve_web.ps1"