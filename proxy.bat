@echo off
set BASEDIR=%~dp0

start "" "%BASEDIR%.bin\pwsh7+\pwsh.exe" ^
  -NoLogo ^
  -NoProfile ^
  -ExecutionPolicy Bypass ^
  -File "%BASEDIR%.src\start-proxyV2.ps1"

exit