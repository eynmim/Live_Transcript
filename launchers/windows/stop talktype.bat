@echo off
REM Double-click to stop talktype (app + Vite/Electron children).
REM Leaves the native Ollama service running.

cd /d "%~dp0\..\.."
bash -c "./talktype stop"
echo.
echo Press any key to close...
pause >nul
