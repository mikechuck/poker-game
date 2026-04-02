param (
    [switch]$dev
)

$export_name = $dev ? "WebDev" : "WebProd"

if ($IsWindows) {
    Godot_v4.5.1-stable_win64_console.exe --headless --export-release $export_name "exports/web/index.html"
} elseif ($IsMacOS) {
    godot --headless --export-release $export_name "exports/web/index.html"
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}

Write-Host "Exported using $export_name preset"