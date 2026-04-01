if ($IsWindows) {
    Godot_v4.5.1-stable_win64_console.exe --headless --export-release "Windows Desktop" "exports/server/windows/poker_server.exe"
} elseif ($IsMacOS) {
    godot --headless --export-release "Windows Desktop" "exports/server/windows/poker_server.exe"
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}