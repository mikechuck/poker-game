if ($IsWindows) {
    wt -p "Windows PowerShell" powershell -Command "Godot_v4.5.1-stable_win64_console.exe --path './' server_mode --headless"
    Start-Sleep -Seconds 3
    wt -p "Windows PowerShell" powershell -Command "Godot_v4.5.1-stable_win64.exe --path './' "
} elseif ($IsMacOS) {
    Start-Process -FilePath "godot" -ArgumentList "--path", "./", "server_mode", "--headless"
    Start-Sleep -Seconds 3
    Start-Process -FilePath "godot" -ArgumentList "--path", "./"
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}