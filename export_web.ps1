# Detect operating system
$OS = $PSVersionTable.OS

if ($OS -like "*Windows*") {
    Godot_v4.5.1-stable_win64_console.exe --headless --export-release "Web" "exports/web/index.html"
} elseif ($OS -like "*Darwin*") { # macOS
    godot --headless --export-release "Web" "exports/web/index.html"
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}
