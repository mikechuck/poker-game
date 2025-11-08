# Detect operating system
$OS = $PSVersionTable.OS

if ($OS -like "*Windows*") {
    Godot_v4.5.1-stable_win64_console.exe --path "./" --server --headless --port=12001
} elseif ($OS -like "*Darwin*") { # macOS
    godot --path "./" --server server_mode --headless --port=12001
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}
