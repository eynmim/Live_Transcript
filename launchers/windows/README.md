# talktype launchers (Windows)

Double-click any of these from Explorer to run. Requires **Git for Windows** installed (so `bash` resolves on PATH).

| File | What it does |
|---|---|
| **start talktype.bat** | Starts the app in a minimized Git Bash window. Closing that window stops the app. |
| **stop talktype.bat** | Stops Electron + Vite + whisper-server children. Leaves native Ollama running. |
| **restart talktype.bat** | Full clean restart — use after a crash or code update. |
| **status talktype.bat** | Live component dashboard. Press any key to close. |

## Recommended setup

- **Desktop** — drag any `.bat` to the Desktop for one-click access.
- **Start Menu** — right-click → **Pin to Start**.
- **Taskbar** — create a shortcut to the `.bat`, then right-click the shortcut → **Pin to taskbar** (pinning raw `.bat` files is blocked by Windows).

## Custom icons

Right-click the `.bat` → **Create shortcut**. Then right-click the shortcut → **Properties** → **Change Icon…** and pick an `.ico` file.

## Troubleshooting

- **"bash is not recognized"** — install [Git for Windows](https://git-scm.com/download/win). That ships Git Bash which provides `bash` on PATH.
- **Launcher window closes immediately** — run the `.bat` from a Command Prompt so you can see the error, or check `%APPDATA%\talktype\` for logs.
- **Start did nothing / app not visible** — the Electron window may be behind other windows. Check the taskbar. If no window at all, run `stop talktype.bat` then `start talktype.bat` again.
- **Antivirus flags the `.bat`** — scripts that launch minimized sometimes get false-flagged. Add the folder to your AV exclusions.
