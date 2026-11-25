@echo off
rem Installs aSup and all its add-ons (install.ps1 beside this file, else the published one).
rem   install.bat [-Dir DIR] [-NoAddons]
setlocal
set "script=%~dp0install.ps1"
if not exist "%script%" (
  set "script=%TEMP%\asup-install.ps1"
  powershell -NoProfile -Command "Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/gagni/asup-releases/main/install.ps1 -OutFile $env:TEMP\asup-install.ps1" || exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%script%" %*
exit /b %errorlevel%
