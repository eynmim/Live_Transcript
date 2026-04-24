@echo off
REM Double-click to start talktype.
REM Opens a minimized Git Bash window that runs ./talktype start.
REM Closing that window stops the app (equivalent to ./talktype stop).

setlocal
cd /d "%~dp0\..\.."
if not exist "%APPDATA%\talktype" mkdir "%APPDATA%\talktype"
start "talktype" /min bash -c "./talktype start"
exit /b 0
