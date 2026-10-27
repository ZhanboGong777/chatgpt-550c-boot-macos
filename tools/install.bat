@echo off
setlocal
chcp 65001 >nul
title ChatGPT 550C Boot - Installer
cd /d "%~dp0.."

echo ============================================
echo   ChatGPT 550C Boot - 1-Click Installer
echo ============================================
echo.
echo This creates a desktop shortcut (with ChatGPT icon),
echo which plays the 550C boot animation then launches ChatGPT.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\Create-ChatGPTShortcut.ps1"
if errorlevel 1 (
  echo.
  echo [FAILED] Could not create shortcut. See docs\使用说明.md for manual steps.
  pause
  exit /b 1
)
echo.
echo ============================================
echo   Done! Double-click ChatGPT on your desktop.
echo ============================================
echo.
pause
exit /b 0
