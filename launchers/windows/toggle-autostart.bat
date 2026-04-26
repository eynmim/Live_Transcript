@echo off
REM Toggle talktype auto-launch at Windows boot.
REM Click once: ENABLE auto-start. Click again: DISABLE.
REM (Adds/removes a shortcut in the user's Startup folder.)

setlocal
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "LINK=%STARTUP%\talktype.lnk"
set "TARGET=%~dp0start talktype.bat"

if exist "%LINK%" (
    del "%LINK%"
    echo.
    echo  ===========================================================
    echo    talktype auto-start: DISABLED
    echo  ===========================================================
    echo.
    echo  talktype will NOT launch on the next Windows boot.
    echo  GPU stays free for games / heavy workloads.
    echo.
    echo  To start talktype manually: double-click "start talktype.bat"
    echo  To re-enable auto-start:    run this file again.
) else (
    if not exist "%STARTUP%" mkdir "%STARTUP%"
    powershell -NoProfile -Command ^
        "$s = (New-Object -ComObject WScript.Shell).CreateShortcut('%LINK%');" ^
        "$s.TargetPath = '%TARGET%';" ^
        "$s.WorkingDirectory = (Split-Path -Parent '%TARGET%');" ^
        "$s.WindowStyle = 7;" ^
        "$s.Description = 'talktype - local dictation app';" ^
        "$s.Save()"
    echo.
    echo  ===========================================================
    echo    talktype auto-start: ENABLED
    echo  ===========================================================
    echo.
    echo  talktype will launch silently on every Windows boot.
    echo.
    echo  To stop it right now:        double-click "stop talktype.bat"
    echo  To disable auto-start later: run this file again.
)

echo.
echo  Press any key to close...
pause >nul
