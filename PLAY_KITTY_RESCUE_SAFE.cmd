@echo off
setlocal
set "KITTY_ENGINE=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%KITTY_ENGINE%" (
  echo Godot executable not found. Open project.godot with Godot 4.7.2.
  pause
  exit /b 1
)
rem Diagnostic mode bypasses Windows WASAPI entirely; gameplay is unchanged.
start "" "%KITTY_ENGINE%" --audio-driver Dummy --path "%~dp0."
