@echo off
REM Double-click to stop and re-start talktype. Use after a crash or code update.

setlocal
cd /d "%~dp0\..\.."
bash -c "./talktype stop"
start "talktype" /min bash -c "./talktype start"
exit /b 0
