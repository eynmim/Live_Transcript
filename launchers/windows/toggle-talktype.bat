@echo off
REM toggle-talktype.bat
REM Smart toggle: starts talktype if stopped, stops it if running.
REM Audio cue: rising tone = ON, falling tone = OFF.
REM
REM This is what the global hotkey shortcut (Ctrl+Alt+Z) points at.
REM Run install-hotkey.bat once to set up the shortcut.

powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0toggle-talktype.ps1"
exit /b 0
