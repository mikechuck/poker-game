@echo off
set "GODOT_EXE=index.exe"

echo Starting Godot headless server...
start ./index.exe --headless server_mode
echo Server started. Press any key to stop it gracefully.
pause

echo Stopping Godot server...
taskkill /f /im godot.exe