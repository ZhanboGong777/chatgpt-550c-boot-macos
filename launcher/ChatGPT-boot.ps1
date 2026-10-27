# ChatGPT Boot Overlay Launcher (ASCII only, UTF-8 BOM)
param(
  [ValidateSet("simple","full","off")][string]$Mode = "full",
  [ValidateRange(0,60)][double]$DelaySec = 1
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

# Temp browser-profile name prefix. Also used to sweep leftovers from runs that
# were killed before the end of this script could clean up after itself.
$script:ProfilePrefix = "chatgpt-boot-"
$script:StaleAfterHours = 1

function Get-CodexAumid {
  # AppUserModelID of the packaged ChatGPT desktop app. The store package is
  # named OpenAI.Codex but its display name is "ChatGPT"; AUMID is always
  # <PackageFamilyName>!<AppId>, and for this package the AppId is "App".
  $pkg = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($pkg) {
    $family = if ($pkg.PackageFamilyName) { $pkg.PackageFamilyName } else { $pkg.Name + "_" + $pkg.PublisherId }
    return ($family + "!App")
  }
  $sa = Get-StartApps -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "ChatGPT" -and $_.AppID -like "OpenAI.Codex_*!App" } |
        Select-Object -First 1
  if ($sa) { return $sa.AppID }
  return $null
}

function Resolve-Codex {
  # UWP/Store app (this machine ships Codex inside the ChatGPT desktop app):
  # no .exe alias exists, so resolve via InstallLocation first, then WindowsApps aliases.
  $pkg = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue | Where-Object { $_.InstallLocation } | Select-Object -First 1
  if ($pkg -and $pkg.InstallLocation) {
    $exe = Join-Path $pkg.InstallLocation "app\ChatGPT.exe"
    if (Test-Path -LiteralPath $exe) { return $exe }
    $exe = Join-Path $pkg.InstallLocation "app\resources\codex.exe"
    if (Test-Path -LiteralPath $exe) { return $exe }
  }
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\OpenAI.Codex.exe"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\ChatGPT.exe")
  )
  foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
  return $null
}

function Launch-Codex {
  # -Path is optional: AUMID launching is preferred and needs no exe path.
  param([string]$Path)
  # Prefer launching by AppUserModelID via shell:AppsFolder: the packaged app
  # keeps its correct taskbar icon and grouping. Launching the raw WindowsApps
  # exe directly makes Windows show a blank taskbar icon.
  $aumid = Get-CodexAumid
  if ($aumid) {
    try {
      Start-Process -FilePath "explorer.exe" -ArgumentList ("shell:AppsFolder\" + $aumid) | Out-Null
      return $true
    } catch { }
  }
  # Fallback: if we resolved a real exe, Start-Process it.
  if ($Path -and (Test-Path -LiteralPath $Path)) {
    Start-Process -FilePath $Path | Out-Null
    return $true
  }
  return $false
}

function Remove-BootProfile {
  # Deleting the browser profile right after Stop-Process usually fails because
  # the browser still holds handles, so retry with a short backoff instead of
  # silently leaking tens of MB into %TEMP% on every run.
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return }
  for ($i = 0; $i -lt 5; $i++) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    try { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop } catch { }
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Start-Sleep -Milliseconds 300
  }
}

function Clear-StaleBootProfiles {
  # Safety net: clean up profiles left behind by earlier runs that never reached
  # their own cleanup step (killed PowerShell, crashed overlay, reboot).
  # Only touches entries matching our prefix and older than $StaleAfterHours.
  $cutoff = (Get-Date).AddHours(-$script:StaleAfterHours)
  Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter ($script:ProfilePrefix + '*') -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    ForEach-Object { Remove-BootProfile -Path $_.FullName }
}

function Launch-Overlay {
  param([string]$Url, [string]$Profile)
  $chrome = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
  ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $chrome) { return $null }
  # Quote the profile path and the URL so spaces (e.g. in a user profile name)
  # cannot split a single argument into several.
  $browserArgs = @(
    '--new-window','--kiosk','--start-maximized','--no-first-run','--no-default-browser-check',
    ('--user-data-dir="' + $Profile + '"'),
    ('"' + $Url + '"')
  )
  return Start-Process -FilePath $chrome -ArgumentList $browserArgs -PassThru
}

# ---- sweep leftovers from earlier interrupted runs ----
Clear-StaleBootProfiles

# ---- Mode "off": no animation, just launch ChatGPT ----
# Resolve the exe fallback only on this path, so a broken AppX query cannot
# prevent the animation modes from running.
if ($Mode -eq "off") {
  $exe = $null
  try { $exe = Resolve-Codex } catch { }
  $launched = $false
  try { $launched = Launch-Codex -Path $exe } catch { }
  if (-not $launched) {
    [System.Windows.Forms.MessageBox]::Show("ChatGPT (OpenAI.Codex) not found.","ChatGPT Boot") | Out-Null
    exit 1
  }
  exit 0
}

# ---- resolve the exe fallback (used only when AUMID launching fails) ----
$exe = $null
try { $exe = Resolve-Codex } catch { }

# ---- open overlay in a clean fullscreen browser window ----
$overlay = Join-Path $PSScriptRoot '..\550c-overlay.html'
if (-not (Test-Path -LiteralPath $overlay)) {
  [System.Windows.Forms.MessageBox]::Show("Missing 550c-overlay.html.","ChatGPT Boot") | Out-Null
  try { [void](Launch-Codex -Path $exe) } catch { }
  exit 1
}
$url = ([System.Uri]$overlay).AbsoluteUri + '?mode=' + [uri]::EscapeDataString($Mode)
$profile = Join-Path $env:TEMP ('chatgpt-boot-' + [guid]::NewGuid().ToString('N'))
$p = Launch-Overlay -Url $url -Profile $profile

if (-not $p) {
  # No browser available: degrade gracefully, still open ChatGPT.
  [System.Windows.Forms.MessageBox]::Show("Chrome/Edge not found. Launching ChatGPT directly.","ChatGPT Boot") | Out-Null
  try { [void](Launch-Codex -Path $exe) } catch { }
  exit 0
}

# ---- wait for the animation to finish, then launch ChatGPT ----
Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern int GetWindowText(System.IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);' -Name U32 -Namespace W -ErrorAction SilentlyContinue

$deadline = (Get-Date).AddSeconds(150)
$done = $false
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 200
  if ($p.HasExited) { $done = $true; break }
  try {
    $w = $p.MainWindowHandle
    if ($w -ne [IntPtr]::Zero) {
      $sb = New-Object System.Text.StringBuilder 256
      [W.U32]::GetWindowText($w, $sb, 256) | Out-Null
      if ($sb.ToString() -like "*__550C_DONE__*") { $done = $true; break }
    }
  } catch { }
}

# Animation finished (done, skipped via Esc/SKIP, or browser closed).
# Close the overlay first, then bring up ChatGPT so it appears only after the animation ends.
$codexLaunched = $false
try {
  if (-not $p.HasExited) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    # Give the browser a moment to release file handles before deleting its profile.
    try { Wait-Process -Id $p.Id -Timeout 5 -ErrorAction SilentlyContinue } catch { }
  }
  Start-Sleep -Seconds $DelaySec
  try { $codexLaunched = Launch-Codex -Path $exe } catch { $codexLaunched = $false }
  if (-not $codexLaunched) {
    [System.Windows.Forms.MessageBox]::Show("ChatGPT (OpenAI.Codex) not found.","ChatGPT Boot") | Out-Null
  }
} finally {
  # Runs even if the browser closed on its own or the block above threw.
  Remove-BootProfile -Path $profile
}

if ($codexLaunched) { exit 0 } else { exit 1 }
