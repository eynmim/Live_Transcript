# Toggle talktype on/off. Plays an audio cue:
#   rising tone (low to high)  = talktype STARTED
#   falling tone (high to low) = talktype STOPPED
#
# Detection: looks for any process whose command line matches the talktype
# stack (OpenWhispr Electron + run-electron child + whisper-server). If one
# is running we treat the whole stack as "on" and kill it; otherwise we
# launch via the existing start launcher.

$ErrorActionPreference = 'SilentlyContinue'

$detectPattern =
    'OpenWhispr|run-electron|whisper-server-win32-x64'

$killPattern =
    'OpenWhispr|run-electron|whisper-server|qdrant|vite.*OpenWhispr|concurrently.*electron|bash\.exe.*talktype\s+dev'

$running = @(
    Get-CimInstance Win32_Process |
        Where-Object { $_.CommandLine -match $detectPattern }
)

if ($running.Count -gt 0) {
    # ── STOP ────────────────────────────────────────────────────────────
    Get-CimInstance Win32_Process |
        Where-Object { $_.CommandLine -match $killPattern } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }

    # falling tone = OFF
    [console]::Beep(700, 180)
    Start-Sleep -Milliseconds 60
    [console]::Beep(380, 220)
} else {
    # ── START ───────────────────────────────────────────────────────────
    # Use wscript.exe + a VBS launcher to spawn bash truly detached and hidden.
    # PowerShell's Start-Process doesn't reliably detach bash in this context
    # (parent-child handle inheritance kills bash within seconds). VBScript
    # via WshShell.Run with style=0, bWaitOnReturn=False is the canonical
    # Windows pattern for fully-detached background launch.
    $vbs = Join-Path $PSScriptRoot 'start-talktype-hidden.vbs'
    if (Test-Path $vbs) {
        Start-Process -FilePath 'wscript.exe' -ArgumentList @("`"$vbs`"")
    } else {
        # Last-resort fallback: the original start.bat (works for double-click)
        $launcher = Join-Path $PSScriptRoot 'start talktype.bat'
        Start-Process -FilePath $launcher -WindowStyle Minimized
    }

    # rising tone = ON
    [console]::Beep(700, 150)
    Start-Sleep -Milliseconds 50
    [console]::Beep(1100, 200)
}
