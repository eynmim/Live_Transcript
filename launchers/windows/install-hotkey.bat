@echo off
REM One-time setup: creates a Desktop shortcut bound to Ctrl+Alt+Z that
REM toggles talktype on/off. Windows registers the hotkey globally as long
REM as the shortcut sits on the Desktop (or in Start Menu).
REM
REM Run this once. After that, press Ctrl+Alt+Z anywhere to toggle.

setlocal
set "TARGET=%~dp0toggle-talktype.bat"
set "WORKDIR=%~dp0"

REM Resolve the real Desktop folder. Handles OneDrive Desktop redirection
REM where %USERPROFILE%\Desktop may not exist as a physical folder.
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"
set "LINK=%DESKTOP%\talktype toggle.lnk"

if exist "%LINK%" del "%LINK%"

powershell -NoProfile -Command ^
    "$s = (New-Object -ComObject WScript.Shell).CreateShortcut('%LINK%');" ^
    "$s.TargetPath = '%TARGET%';" ^
    "$s.WorkingDirectory = '%WORKDIR%';" ^
    "$s.HotKey = 'CTRL+ALT+Z';" ^
    "$s.WindowStyle = 7;" ^
    "$s.Description = 'Toggle talktype on/off (Ctrl+Alt+Z)';" ^
    "$s.Save()"

if errorlevel 1 (
    echo.
    echo  ERROR creating shortcut. See PowerShell output above.
    pause
    exit /b 1
)

echo.
echo  ===========================================================
echo    Hotkey installed: Ctrl + Alt + Z
echo  ===========================================================
echo.
echo  Press Ctrl+Alt+Z anywhere to toggle talktype on/off.
echo.
echo  Audio cue:
echo    rising tone (low - high)  = talktype STARTED
echo    falling tone (high - low) = talktype STOPPED
echo.
echo  Shortcut created at:
echo    %LINK%
echo.
echo  To change the hotkey:
echo    Right-click the shortcut on Desktop - Properties -
echo    Shortcut tab - Shortcut key field.
echo.
echo  To remove the hotkey:
echo    Just delete the shortcut from Desktop.
echo.
pause
