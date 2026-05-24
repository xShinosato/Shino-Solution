# ============================================================
#  Shino-Solution -- One-line PowerShell installer
# ============================================================
#  Usage (run from any PowerShell, Admin recommended) :
#
#    powershell -c "irm https://<your-host>/install | iex"
#
#  What it does :
#    1. Verifies Windows 10/11 + PowerShell 5.1+
#    2. Picks the install dir :
#         - %LOCALAPPDATA%\Shino-Solution   (per-user, no admin)
#         - %ProgramFiles%\Shino-Solution   (machine-wide, admin)
#    3. Downloads Shino-Solution.exe from $DownloadUrl.
#    4. Writes a default Shino-Solution.settings.json next to it
#       (only if one does not already exist - preserves your
#       config on re-install / upgrade).
#    5. Creates a Start Menu + Desktop shortcut.
#    6. Adds the install dir to the user PATH.
#    7. Auto-launches the tool (unless $env:SHINO_NOLAUNCH=1).
#
#  NOTE : keep this file ASCII-only. PowerShell 5 on Windows
#  reads .ps1 files without a BOM as CP1252, so any UTF-8
#  Unicode character (box drawing, em-dash, smart quotes,
#  etc.) will be mis-decoded and break the parser when the
#  script is delivered via `irm | iex` from a server that
#  returns the bytes as raw UTF-8.
# ============================================================

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ------------------------------------------------------------
#  Edit these 3 lines for your release. The script is
#  otherwise generic - anyone can fork & re-host without code
#  changes.
# ------------------------------------------------------------
$AppName     = 'Shino-Solution'
$ExeName     = 'Shino-Solution.exe'
# Direct download URL of the latest .exe. Recommended hosts :
#   GitHub Releases (free, public, CDN-backed) :
#     https://github.com/<owner>/<repo>/releases/latest/download/Shino-Solution.exe
#   Custom CDN / R2 :
#     https://cdn.<your-domain>/Shino-Solution.exe
$DownloadUrl = 'https://github.com/Leetchy/Shino-Solution/releases/latest/download/Shino-Solution.exe'

# ------------------------------------------------------------
#  ANSI-colored output helpers (Windows Terminal renders them ;
#  legacy conhost will just show the escape codes -- harmless).
# ------------------------------------------------------------
$ESC = [char]27
function Hdr  ($t) { Write-Host ("{0}[36m{1}{0}[0m"      -f $ESC, $t) }
function Ok   ($t) { Write-Host ("{0}[32m[OK]{0}[0m   {1}"-f $ESC, $t) }
function Info ($t) { Write-Host ("{0}[34m[INFO]{0}[0m {1}"-f $ESC, $t) }
function Warn ($t) { Write-Host ("{0}[33m[WARN]{0}[0m {1}"-f $ESC, $t) }
function Err  ($t) { Write-Host ("{0}[31m[ERR ]{0}[0m {1}"-f $ESC, $t) }

Hdr  ""
Hdr  "============================================================"
Hdr  ("  {0} -- PowerShell installer" -f $AppName)
Hdr  "============================================================"
Hdr  ""

# ------------------------------------------------------------
#  Sanity checks
# ------------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Err ("PowerShell 5.1+ required. You have {0}." -f $PSVersionTable.PSVersion)
    return
}

$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    $InstallDir = Join-Path $env:ProgramFiles $AppName
    Info "Running as Administrator -> machine-wide install."
} else {
    $InstallDir = Join-Path $env:LOCALAPPDATA $AppName
    Info "Running as standard user  -> per-user install (no admin)."
}

Info ("Install dir : {0}" -f $InstallDir)
Info ("Download    : {0}" -f $DownloadUrl)

# ------------------------------------------------------------
#  Make sure the install dir exists & is writable
# ------------------------------------------------------------
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Ok ("Created {0}" -f $InstallDir)
}

$ExePath = Join-Path $InstallDir $ExeName

# ------------------------------------------------------------
#  If a previous instance is running, gracefully stop it first
#  (otherwise the .exe overwrite below would fail with file lock)
# ------------------------------------------------------------
$procName = [IO.Path]::GetFileNameWithoutExtension($ExeName)
$running  = Get-Process -Name $procName -ErrorAction SilentlyContinue
if ($running) {
    Warn ("Stopping {0} running instance(s) of {1}..." -f $running.Count, $ExeName)
    $running | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

# ------------------------------------------------------------
#  Download
# ------------------------------------------------------------
Info ("Downloading {0} ..." -f $ExeName)
try {
    # Invoke-WebRequest is slow on big files due to its default
    # progress bar -- disable it for a ~10x speed-up.
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath -UseBasicParsing
    $ProgressPreference = 'Continue'
} catch {
    Err ("Download failed : {0}" -f $_.Exception.Message)
    Err  "Check the URL, your network, and any AV blocking PowerShell."
    return
}

$sizeMb = [math]::Round((Get-Item $ExePath).Length / 1MB, 1)
Ok ("Downloaded {0} ({1} MB)." -f $ExeName, $sizeMb)

# ------------------------------------------------------------
#  Default settings.json -- written ONLY if missing
# ------------------------------------------------------------
$SettingsPath = Join-Path $InstallDir ("{0}.settings.json" -f $AppName)
if (-not (Test-Path $SettingsPath)) {
    $defaults = [ordered]@{
        '_help'           = 'ram_cap_mb: trim Roblox if RAM exceeds this MB (0 = no cap). cpu_cores: CPU cores per Roblox instance (0 = unlimited). fps/fps_cap: Roblox FPS cap. efficiency_mode: low CPU scheduling mode. roblox_path: custom Roblox player folder containing RobloxPlayerBeta.exe.'
        'cpu_cores'       = 0
        'efficiency_mode' = $true
        'fps'             = 5
        'fps_cap'         = $true
        'ram_cap_mb'      = 900
        'roblox_path'     = ''
    }
    ($defaults | ConvertTo-Json -Depth 4) | Set-Content -Path $SettingsPath -Encoding UTF8
    Ok ("Wrote default settings : {0}" -f $SettingsPath)
} else {
    Info ("Existing settings kept : {0}" -f $SettingsPath)
}

# ------------------------------------------------------------
#  Start Menu + Desktop shortcuts
# ------------------------------------------------------------
function New-Shortcut ($Target, $LnkPath, $Description) {
    try {
        $ws  = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut($LnkPath)
        $lnk.TargetPath       = $Target
        $lnk.WorkingDirectory = Split-Path $Target -Parent
        $lnk.Description      = $Description
        $lnk.IconLocation     = $Target
        $lnk.Save()
        Ok ("Shortcut : {0}" -f $LnkPath)
    } catch {
        Warn ("Shortcut failed : {0} ({1})" -f $LnkPath, $_.Exception.Message)
    }
}

$startMenu = if ($IsAdmin) {
    Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
} else {
    Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
}
New-Shortcut $ExePath (Join-Path $startMenu ("{0}.lnk" -f $AppName)) $AppName
New-Shortcut $ExePath (Join-Path ([Environment]::GetFolderPath('Desktop')) ("{0}.lnk" -f $AppName)) $AppName

# ------------------------------------------------------------
#  Add to PATH so `Shino-Solution` is callable from any shell.
#  User scope when not admin, Machine scope when admin.
# ------------------------------------------------------------
$pathScope   = if ($IsAdmin) { 'Machine' } else { 'User' }
$currentPath = [Environment]::GetEnvironmentVariable('PATH', $pathScope)
if (($currentPath -split ';') -notcontains $InstallDir) {
    [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$InstallDir", $pathScope)
    Ok ("Added to {0} PATH (restart shell to use the 'Shino-Solution' command)." -f $pathScope)
}

# ------------------------------------------------------------
#  Done -- offer to launch
# ------------------------------------------------------------
Hdr  ""
Hdr  "============================================================"
Ok   ("{0} installed at {1}" -f $AppName, $InstallDir)
Info ("Config file : {0}" -f $SettingsPath)
Info ("Launch now  : Start-Process '{0}'" -f $ExePath)
Hdr  "============================================================"
Hdr  ""

# Auto-launch unless the caller passed -NoLaunch by setting
# $env:SHINO_NOLAUNCH=1 before running (useful in CI / silent installs).
if (-not $env:SHINO_NOLAUNCH) {
    try {
        Start-Process -FilePath $ExePath -WorkingDirectory $InstallDir
        Ok ("Launched {0}." -f $ExeName)
    } catch {
        Warn ("Auto-launch failed : {0}" -f $_.Exception.Message)
    }
}
