@echo off
REM Double-click for the live component dashboard.

cd /d "%~dp0\..\.."
bash -c "./talktype status"
echo.
echo Press any key to close...
pause >nul
