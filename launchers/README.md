# talktype launchers

> **Windows users:** see [windows/README.md](windows/README.md) — the `.command` files below are macOS only; Windows has its own `.bat` equivalents.

Double-click any of these from Finder to run.

| File | What it does |
|---|---|
| **start talktype.command** | Launches app detached (survives closing Terminal). Idempotent — does nothing extra if already running. Terminal auto-closes after ~4 s. |
| **stop talktype.command** | Stops app + kills stale Vite/Electron on dev ports. Leaves native Ollama alone. Terminal auto-closes. |
| **restart talktype.command** | Full clean restart. Use after a crash or after a patch/code update. Terminal auto-closes. |
| **status talktype.command** | Shows the live dashboard. Press any key to close. |

## How they differ from just running `./talktype start`

The raw CLI command dies if you close the terminal (SIGHUP cascade). These launchers use `nohup` + `disown` so the app **keeps running after the Terminal window closes**, exactly what you want for a daily-use app.

Log file for detached launches: `~/Library/Logs/talktype/launcher.log` — useful if something fails silently.

## Recommended setup

Drag any of these wherever a double-click is convenient:

- **Desktop** — fastest visibility
- **Dock** — right-click the file after dropping → "Keep in Dock"
- **Finder sidebar** — drag to Favorites
- **Launchpad** — copy to `/Applications/`

## First run — macOS Gatekeeper

The first time you double-click, macOS may block with "cannot be opened because it is from an unidentified developer."

Fix once: right-click the file → **Open** → confirm. macOS remembers per file.

## Custom icons

1. Get a PNG (256×256 minimum)
2. Open it in Preview → Edit → Copy (⌘+C)
3. Right-click the `.command` file → **Get Info**
4. Click the tiny icon in the top-left of the Info window to select it
5. Paste (⌘+V)

## Troubleshooting

- **App died after I closed the Terminal** — shouldn't happen with these new launchers. If it does, check `~/Library/Logs/talktype/launcher.log` for errors.
- **Terminal window didn't auto-close** — AppleScript may need Accessibility permission. Grant it to Terminal in System Settings → Privacy & Security → Accessibility. Or close manually with ⌘+W; the app is already detached so this is cosmetic.
- **"start" did nothing** — it detected an existing Electron process and skipped. Use **restart** instead if you want to force a fresh launch.
