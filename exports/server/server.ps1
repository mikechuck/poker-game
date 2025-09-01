./poker_server.exe --headless server_mode

Read-Host -Prompt "Press enter to shutdown the server"

Get-Process -Name poker_server | Stop-Process -Force