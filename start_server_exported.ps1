# Detect operating system
$OS = $PSVersionTable.OS

if ($OS -like "*Windows*") {
    ./exports/server/windows/poker_server.exe --headless server_mode
} elseif ($OS -like "*Darwin*") { # macOS
    ./exports/server/poker_server --headless server_mode
} else {
    Write-Host "Unsupported operating system: $OS"
    exit 1
}

Read-Host -Prompt "Press enter to shutdown the server"
Get-Process -Name poker_server | Stop-Process -Force
