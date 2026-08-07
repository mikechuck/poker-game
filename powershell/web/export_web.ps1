param (
    [string]$env
)

$export_name = switch ($env) {
    "local" { "WebLocal" }
    "dev" { "WebDev" }
    "prod" { "WebProd" }
    Default { "" }
}

if ($export_name -eq "") {
    Write-Error "Invalid env parameter, please use the format '-env `"dev`"'";
    return;
}

if ($export_name -eq "WebDev") {
    $export_type = "--export-debug"
}
else {
    $export_type = "--export-release"
}

if ($IsWindows) {
    Write-Host "Export type: $export_type"
    Godot_v4.5.1-stable_win64_console.exe --headless --quiet $export_type $export_name
} elseif ($IsMacOS) {
    godot --headless --export-release $export_name
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}

Write-Host "Exported client using $export_name preset"