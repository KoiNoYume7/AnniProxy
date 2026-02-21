@echo off
setlocal

set BASEDIR=%~dp0
set LOCAL_PWSH=%BASEDIR%.bin\pwsh7+\pwsh.exe
set SCRIPT=%BASEDIR%.src\main.ps1
set CONFIG=%BASEDIR%.config\config.json

set LOGDIR=%BASEDIR%.log
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>nul
set BOOTLOG=%LOGDIR%\bootstrap.log

set TMPDIR=%BASEDIR%.tmp
if not exist "%TMPDIR%" mkdir "%TMPDIR%" >nul 2>nul
set BOOTSTRAP=%TMPDIR%\bootstrap.ps1

>  "%BOOTSTRAP%" echo $ErrorActionPreference = 'Stop'
>> "%BOOTSTRAP%" echo $log = '%BOOTLOG%'
>> "%BOOTSTRAP%" echo $failed = $false
>> "%BOOTSTRAP%" echo try { Start-Transcript -Path $log -Append ^| Out-Null } catch {}
>> "%BOOTSTRAP%" echo try { ^& '%SCRIPT%' } catch { $failed = $true; Write-Host $_ }
>> "%BOOTSTRAP%" echo try { Stop-Transcript ^| Out-Null } catch {}
>> "%BOOTSTRAP%" echo if($failed){ Write-Host ''; Write-Host 'FAILED - see .log\bootstrap.log' -ForegroundColor Red; pause }

if not exist "%BOOTSTRAP%" (
  echo.
  echo ERROR: Failed to create "%BOOTSTRAP%"
  pause
  exit /b 1
)

REM --- read useScoop from config.json (defaults to false) --- #
set USE_SCOOP=false
if exist "%CONFIG%" (
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-Content -Raw '%CONFIG%'; try { (ConvertFrom-Json $c).useScoop } catch { $false }"`) do set USE_SCOOP=%%A
)

set PWSH_ZIP_URL=
if exist "%CONFIG%" (
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-Content -Raw '%CONFIG%'; try { (ConvertFrom-Json $c).'pwsh7.5.4Url' } catch { '' }"`) do set PWSH_ZIP_URL=%%A
)

REM --- 1. Use bundled PowerShell if present --- #
if exist "%LOCAL_PWSH%" (
    echo Using bundled PowerShell 7
    "%LOCAL_PWSH%" ^
      -NoProfile ^
      -ExecutionPolicy Bypass ^
      -File "%BOOTSTRAP%"
    exit /b %ERRORLEVEL%
)

REM --- 2. Use system-installed PowerShell 7 if available --- #
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    echo Using system-installed PowerShell 7
    pwsh ^
      -NoProfile ^
      -ExecutionPolicy Bypass ^
      -File "%BOOTSTRAP%"
    exit /b %ERRORLEVEL%
)

REM --- 3. Bootstrap PowerShell 7 manually (when Scoop is disabled) --- #
if /I not "%USE_SCOOP%"=="true" goto MANUAL_PWSH

REM --- 4. Try installing PowerShell via Scoop --- #
set "SCOOP_SHIM=%USERPROFILE%\scoop\shims\scoop.cmd"

where scoop >nul 2>nul
if %ERRORLEVEL%==0 (
    echo PowerShell 7 not found. Installing via Scoop...
    if exist "%SCOOP_SHIM%" (
        cmd.exe /c "\"%SCOOP_SHIM%\" install pwsh"
    ) else (
        scoop install pwsh
    )

    REM re-check after install
    where pwsh >nul 2>nul
    if %ERRORLEVEL%==0 (
        pwsh ^
          -NoProfile ^
          -ExecutionPolicy Bypass ^
          -File "%BOOTSTRAP%"
        exit /b %ERRORLEVEL%
    )
) else (
    REM --- 3b. Scoop not found, install it first --- #
    echo Scoop not found. Installing Scoop...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"

    REM Scoop install often updates PATH for *future* shells only. Make it available now.
    if exist "%SCOOP_SHIM%" set "PATH=%USERPROFILE%\scoop\shims;%PATH%"
    
    REM install pwsh after scoop install (prefer shim)
    if exist "%SCOOP_SHIM%" (
        echo Installing PowerShell 7 via Scoop...
        cmd.exe /c "\"%SCOOP_SHIM%\" install pwsh"
        
        REM final check for pwsh
        where pwsh >nul 2>nul
        if %ERRORLEVEL%==0 (
            pwsh ^
              -NoProfile ^
              -ExecutionPolicy Bypass ^
              -File "%BOOTSTRAP%"
            exit /b %ERRORLEVEL%
        )
    ) else (
        where scoop >nul 2>nul
        if %ERRORLEVEL%==0 (
            echo Installing PowerShell 7 via Scoop...
            scoop install pwsh

            where pwsh >nul 2>nul
            if %ERRORLEVEL%==0 (
                pwsh ^
                  -NoProfile ^
                  -ExecutionPolicy Bypass ^
                  -File "%BOOTSTRAP%"
                exit /b %ERRORLEVEL%
            )
        )
    )
)

REM If Scoop path didn't yield pwsh, fall back to manual bootstrap if configured
if not "%PWSH_ZIP_URL%"=="" goto MANUAL_PWSH

goto HARDSTOP

:MANUAL_PWSH
if "%PWSH_ZIP_URL%"=="" goto HARDSTOP

echo PowerShell 7 not found. Bootstrapping from zip (this might take a while)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $base='%BASEDIR%'; $dest=Join-Path $base '.bin\pwsh7+'; New-Item -ItemType Directory -Path $dest -Force | Out-Null; $zip=Join-Path $dest 'pwsh.zip'; Invoke-WebRequest -Uri '%PWSH_ZIP_URL%' -OutFile $zip -UseBasicParsing; Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force;"

for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=Get-ChildItem -Path '%BASEDIR%.bin\pwsh7+' -Recurse -Filter pwsh.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName; if($p){$p}"`) do set LOCAL_PWSH=%%A

if not exist "%LOCAL_PWSH%" goto HARDSTOP

echo Using bootstrapped PowerShell 7
"%LOCAL_PWSH%" ^
  -NoProfile ^
  -ExecutionPolicy Bypass ^
  -File "%BOOTSTRAP%"
exit /b %ERRORLEVEL%

REM --- 4. Hard stop with clear message --- #
:HARDSTOP
echo.
echo ERROR: PowerShell 7+ is required.
echo Install it manually from:
echo https://learn.microsoft.com/powershell
echo.
pause
exit /b 1
