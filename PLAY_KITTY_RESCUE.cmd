@echo off
setlocal
set "KITTY_ENGINE=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%KITTY_ENGINE%" (
  echo Open project.godot with Godot 4.6 or newer, then press F6 or F5.
  pause
  exit /b 1
)
start "" "%KITTY_ENGINE%" --path "%~dp0."
