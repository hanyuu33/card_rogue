@echo off
rem Duck Cards Rogue - double click to play
pushd "%~dp0"
if not exist "C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64.exe" (
  echo [ERROR] Godot engine not found. Please reinstall.
  pause
  popd
  exit /b 1
)
start "" "C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64.exe" --path "%CD%"
popd
