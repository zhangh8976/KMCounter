@echo off
cd /d "%~dp0"
if exist "KMCounter.exe" (
  start "" "KMCounter.exe" --demo
) else (
  start "" "tools\AutoHotkey\AutoHotkeyU64.exe" "KMCounter.ahk" --demo
)
