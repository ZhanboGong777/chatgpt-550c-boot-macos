# Create-ChatGPTShortcut.ps1
# 在桌面创建「ChatGPT」快捷方式：指向本项目启动器，并设置 ChatGPT 图标。
# 任何人从 GitHub 下载本项目后，双击（或运行）本脚本即可生成带图标的桌面快捷方式。
# 用法:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "Create-ChatGPTShortcut.ps1"
#   powershell -NoProfile -ExecutionPolicy Bypass -File "Create-ChatGPTShortcut.ps1" -Location Taskbar

param(
  # Desktop = 桌面快捷方式（推荐、可靠）。
  # Taskbar = 往 Windows 的“已固定”目录写入 .lnk。注意：Windows 的任务栏固定状态
  #           由系统自己的固定数据库维护，只写这个文件**不会**让图标出现在任务栏上，
  #           因此该选项仅作实验性用途，脚本会给出明确提示。
  [ValidateSet("Desktop","Taskbar")][string]$Location = "Desktop"
)

$ErrorActionPreference = "Stop"

# 项目根目录：本脚本位于 <repo>\tools 下
$root = Split-Path -Parent $PSScriptRoot
$cmd  = Join-Path $root "launcher\ChatGPT.cmd"
$icon = Join-Path $root "icons\icon-chatgpt.ico"

if (-not (Test-Path -LiteralPath $cmd)) {
  Write-Host "未找到启动器: $cmd" -ForegroundColor Red
  exit 1
}
if (-not (Test-Path -LiteralPath $icon)) {
  Write-Host "未找到图标: $icon" -ForegroundColor Yellow
  $icon = "$env:SystemRoot\System32\shell32.dll"
}

# 先决定目标位置，便于统一处理错误。
if ($Location -eq "Desktop") {
  $lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "ChatGPT.lnk"
  $description = "ChatGPT 550C Boot - 播放 550C 开机动画后启动 ChatGPT"
} else {
  $taskbar = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
  if (-not (Test-Path -LiteralPath $taskbar)) {
    New-Item -ItemType Directory -Path $taskbar -Force | Out-Null
  }
  $lnkPath = Join-Path $taskbar "ChatGPT.lnk"
  $description = "ChatGPT 550C Boot"
}

$shell = $null
$exitCode = 0
try {
  $shell = New-Object -ComObject WScript.Shell
  $sc = $shell.CreateShortcut($lnkPath)
  $sc.TargetPath = $env:ComSpec
  # 外层引号交给 cmd，内层引号包住可能含空格的路径。
  $sc.Arguments = "/c `"`"$cmd`"`""
  $sc.WorkingDirectory = $root
  $sc.IconLocation = "$icon,0"
  $sc.Description = $description
  $sc.Save()

  if ($Location -eq "Desktop") {
    Write-Host "已创建桌面快捷方式: $lnkPath" -ForegroundColor Green
  } else {
    Write-Host "已写入任务栏固定目录: $lnkPath" -ForegroundColor Green
    Write-Host "注意: 仅写文件不会让图标出现在任务栏上（固定状态由系统数据库维护）。" -ForegroundColor Yellow
    Write-Host "      若确实需要固定，请手动右键任务栏上的图标选择“固定到任务栏”。" -ForegroundColor Yellow
  }
  Write-Host "完成！双击桌面「ChatGPT」即可播放 550C 动画后启动 ChatGPT。" -ForegroundColor Cyan
}
catch {
  $exitCode = 1
  Write-Host "创建快捷方式失败: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "目标路径: $lnkPath" -ForegroundColor Yellow
  Write-Host "常见原因: 桌面被 OneDrive 重定向、路径无写权限，或系统策略限制。" -ForegroundColor Yellow
  Write-Host "可参考 docs\使用说明.md 里的“手动创建”步骤。" -ForegroundColor Yellow
}
finally {
  if ($shell) {
    try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) } catch { }
  }
}

exit $exitCode
