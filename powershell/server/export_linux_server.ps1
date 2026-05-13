if ($IsWindows) {
    Godot_v4.5.1-stable_win64_console.exe --headless --export-release "Linux"
} elseif ($IsMacOS) {
    godot --headless --export-release "Linux"
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}