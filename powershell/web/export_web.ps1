if ($IsWindows) {
    Godot_v4.5.1-stable_win64_console.exe --headless --export-release "Web" "exports/web/dev/index.html"
} elseif ($IsMacOS) {
    godot --headless --export-release "Web" "exports/web/dev/index.html"
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}