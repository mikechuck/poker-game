param (
    [switch]$dev
)

if ($dev) {
    & "$PSScriptRoot\export_web.ps1" -dev
} else {
    & "$PSScriptRoot\export_web.ps1"
}
& "$PSScriptRoot\serve_exported_web.ps1"