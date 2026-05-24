# Shino-Solution

Background Roblox optimization service for Windows. Hard-caps each Roblox instance's RAM, throttles CPU via EcoQoS, idles every Roblox thread, caps FPS — so you can run many instances at once without your PC catching fire.

## Download

Open Windows PowerShell (Admin recommended) and run :

```powershell
powershell -c "irm https://raw.githubusercontent.com/xShinosato/Shino-Solution/main/install.ps1 | iex"
```

The installer will :

- Download the latest `Shino-Solution.exe`.
- Place it in `%LOCALAPPDATA%\Shino-Solution` (or `%ProgramFiles%\Shino-Solution` if you ran as Admin).
- Write a default `Shino-Solution.settings.json` next to it.
- Create Start Menu + Desktop shortcuts.
- Add the install dir to your PATH.
- Launch the dashboard automatically.

## Configure

Edit `Shino-Solution.settings.json` in the install folder :

```json
{
  "_help": "ram_cap_mb: trim Roblox if RAM exceeds this MB (0 = no cap). cpu_cores: CPU cores per Roblox instance (0 = unlimited). fps/fps_cap: Roblox FPS cap. efficiency_mode: low CPU scheduling mode. roblox_path: custom Roblox player folder containing RobloxPlayerBeta.exe.",
  "cpu_cores": 0,
  "efficiency_mode": true,
  "fps": 5,
  "fps_cap": true,
  "ram_cap_mb": 300,
  "roblox_path": ""
}
```

| Key | Meaning |
| --- | ------- |
| `ram_cap_mb` | Hard ceiling per Roblox process in MB. The Windows kernel will refuse to keep more than this resident in RAM. `0` disables. |
| `cpu_cores` | If `> 0`, pins each Roblox instance round-robin to N cores. `0` = let Windows schedule freely. |
| `fps` | Frame-rate cap injected into Roblox `ClientSettings`. |
| `fps_cap` | Toggle the FPS cap on/off. |
| `efficiency_mode` | One-flag switch : enables process-priority Idle + memory-priority Very Low + EcoQoS + hard working-set cap + thread-priority Idle. |
| `roblox_path` | Optional override for the Roblox player folder. Leave empty to use the default. |

The dashboard reloads the settings every second — edit and save, no restart needed.

## What you get vs vanilla Roblox

| Layer | When | Effect |
| ----- | ---- | ------ |
| **Hard working-set cap** (kernel) | Every 60 s + on launch | Windows refuses Roblox more than `ram_cap_mb` MB resident, in real time |
| **Reactive trim w/ 5 % hysteresis** | Every 30 s if WS > cap × 1.05 | Backup eviction of cold pages |
| **MemoryPriority Very Low** | Every 60 s | Kernel evicts Roblox first under RAM pressure |
| **EcoQoS** | Every 60 s | CPU clock cap + schedule on E-cores |
| **ProcessPriority Idle** | On launch | CPU only when nothing else needs it |
| **ThreadPriority Idle** | Every 60 s | Threads scheduled last |
| **FPS cap** | Continuous | Limits GPU/CPU render |
| **Suspend minimized** *(opt-in)* | Continuous | 0 % CPU when Roblox window is minimized |

## Uninstall

```powershell
# Per-user install
Stop-Process -Name Shino-Solution -Force -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Shino-Solution"
[Environment]::SetEnvironmentVariable('PATH',
    (([Environment]::GetEnvironmentVariable('PATH','User') -split ';' |
        Where-Object { $_ -ne "$env:LOCALAPPDATA\Shino-Solution" }) -join ';'),
    'User')
```

## License

MIT.
