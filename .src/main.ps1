# --- start of main.ps1 --- #

[CmdletBinding()]
param(
    [switch]$NoLogo,
    [ValidateSet("INFO","OK","WARN","ERROR","ALL")]
    [string]$LogLevel,
    [switch]$NoTimestamp,
    [switch]$OfflineSSHTest,
    [switch]$UseScoop
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7+. Current: $($PSVersionTable.PSVersion)." -ForegroundColor Red
    Write-Host "Please run it with: pwsh -File \"$PSCommandPath\"" -ForegroundColor Yellow
    exit 1
}

$ErrorActionPreference = 'Stop'
$Global:StopRequested = $false

# --- paths & config --- #
$BaseDir     = Split-Path -Parent $PSScriptRoot
$LogDir      = Join-Path $BaseDir ".log"
$LockFile    = Join-Path $BaseDir ".session.lock"
$LogoScript  = Join-Path $BaseDir ".assets\LogoASCII.ps1"
$BinDir      = Join-Path $BaseDir ".bin"

# --- load main config --- #
$ConfigPath = Join-Path $BaseDir ".config\config.json"
if (-not (Test-Path $ConfigPath)) { throw "Missing config file: $ConfigPath" }

$appConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# Override config with CLI parameters if provided
$finalNoLogo = if ($PSBoundParameters.ContainsKey('NoLogo')) { $NoLogo } else { $appConfig.noLogo }
$finalLogLevel = if ($PSBoundParameters.ContainsKey('LogLevel')) { $LogLevel } else { $appConfig.logLevel }
$finalNoTimestamp = if ($PSBoundParameters.ContainsKey('NoTimestamp')) { $NoTimestamp } else { $appConfig.noTimestamp }
$finalOfflineSSHTest = if ($PSBoundParameters.ContainsKey('OfflineSSHTest')) { $OfflineSSHTest } else { $appConfig.offlineSSHTest }
$finalUseScoop = if ($PSBoundParameters.ContainsKey('UseScoop')) { $UseScoop } else { $appConfig.useScoop }

$CloudflaredUrl = $appConfig.cloudflaredUrl

$Brave7zUrl     = $appConfig.brave7zUrl

$OpenSshZipUrl  = $appConfig.openSshZipUrl

$Cloudflared    = Join-Path $BinDir "cloudflared\cloudflared.exe"
$BraveDir       = Join-Path $BinDir "brave-portable"
$Brave          = Join-Path $BraveDir "brave-portable.exe"
$Brave7zArchive = Join-Path $BinDir "brave-portable.7z"

# --- load ssh config --- #
$SshConfigPath = Join-Path $BaseDir ".config\ssh.json"
if (-not (Test-Path $SshConfigPath)) { throw "Missing SSH config: $SshConfigPath" }

$sshConfig = Get-Content $SshConfigPath -Raw | ConvertFrom-Json
$SshUser   = $sshConfig.user
$SshHost   = $sshConfig.host
$SocksPort = $sshConfig.socksPort

$IdentityFile   = $sshConfig.identityFile
$KnownHostsFile = $sshConfig.knownHostsFile

# --- logging setup --- #
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

function Invoke-LogRetention {
    param(
        [Parameter(Mandatory=$true)][string]$LogDirPath,
        [int]$MaxFiles = 10
    )

    if (-not (Test-Path $LogDirPath)) { return }

    $archiveDir = Join-Path $LogDirPath ".archive"
    if (-not (Test-Path $archiveDir)) {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    }

    $files = Get-ChildItem -Path $LogDirPath -File -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -ne $archiveDir } |
        Sort-Object LastWriteTime

    if (-not $files) { return }

    $excess = $files.Count - $MaxFiles
    if ($excess -le 0) { return }

    $toArchive = $files | Select-Object -First $excess
    foreach ($f in $toArchive) {
        $dest = Join-Path $archiveDir $f.Name
        if (Test-Path $dest) {
            $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            $ext  = [IO.Path]::GetExtension($f.Name)
            $dest = Join-Path $archiveDir ("{0}.{1:yyyyMMdd-HHmmss}{2}" -f $base, $f.LastWriteTime, $ext)
        }
        try { Move-Item -LiteralPath $f.FullName -Destination $dest -Force -ErrorAction SilentlyContinue } catch {}
    }
}

Invoke-LogRetention -LogDirPath $LogDir -MaxFiles 10

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Global:LogFile = Join-Path $LogDir "session-$Timestamp.log"

$Global:CurrentLogLevelPriority = @{"ALL"=0;"INFO"=1;"OK"=2;"WARN"=3;"ERROR"=4}[$finalLogLevel]
$Global:SuppressTimestamp = $finalNoTimestamp

$Global:AnniProxyProvisioned = $false

$Global:ShowExitPrompt = $true

# --- modules --- #
. "$PSScriptRoot/logging.ps1"
. "$PSScriptRoot/guard.ps1"
. "$PSScriptRoot/console-guard.ps1"
. "$PSScriptRoot/get-binaries.ps1"

function Resolve-SshExe {
    $resolved = $null

    try {
        $cmd = Get-Command ssh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source) {
            $resolved = [string]$cmd.Source
        }
    } catch {}

    if (-not $resolved) {
        $defaultSsh = Join-Path $env:WINDIR "System32\OpenSSH\ssh.exe"
        if (Test-Path $defaultSsh) {
            $resolved = $defaultSsh
        }
    }

    if (-not $resolved -and $finalUseScoop) {
        try {
            $scoop = Get-Command scoop -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($scoop -and $scoop.Source) {
                $null = Write-Log "ssh.exe not found; trying Scoop install: openssh" "INFO"
                $shim = Join-Path $env:USERPROFILE "scoop\shims\scoop.cmd"
                if (Test-Path $shim) {
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "`"$shim`" install openssh") -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\scoop-openssh.log" -RedirectStandardError "$env:TEMP\scoop-openssh.err"
                } else {
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "scoop install openssh") -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\scoop-openssh.log" -RedirectStandardError "$env:TEMP\scoop-openssh.err"
                }
                if ($proc.ExitCode -eq 0) {
                    $cmd = Get-Command ssh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
                        $resolved = [string]$cmd.Source
                        $null = Write-Log "Found ssh.exe after Scoop install at $resolved" "OK"
                    }
                } else {
                    $null = Write-Log "Scoop install openssh failed (exit code $($proc.ExitCode)); falling back" "WARN"
                }
            }
        } catch {
            $null = Write-Log "Scoop install openssh failed: $_; falling back" "WARN"
        }
    }

    if (-not $resolved) {
        if ([string]::IsNullOrWhiteSpace($OpenSshZipUrl)) {
            throw "ssh.exe was not found and openSshZipUrl is not set. Install the Windows 'OpenSSH Client' feature or set openSshZipUrl in .config/config.json."
        }

        $OpenSshZip = Join-Path $BinDir "openssh.zip"
        $OpenSshDir = Join-Path $BinDir "openssh"

        $null = Get-Binary -Name "OpenSSH" -TargetPath $OpenSshZip -DownloadUrl $OpenSshZipUrl -UseScoop:$finalUseScoop

        if (-not (Test-Path $OpenSshDir)) {
            New-Item -ItemType Directory -Path $OpenSshDir -Force | Out-Null
        }

        $needsExtract = $true
        if (Test-Path $OpenSshDir) {
            $existing = Get-ChildItem -Path $OpenSshDir -Recurse -Filter ssh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($existing -and (Test-Path $existing.FullName)) {
                $needsExtract = $false
            }
        }

        if (-not $needsExtract) {
            try {
                if (Test-Path $OpenSshZip) {
                    Remove-Item -LiteralPath $OpenSshZip -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }

        if ($needsExtract) {
            $null = Write-Log "Extracting OpenSSH" "INFO"
            Expand-Archive -LiteralPath $OpenSshZip -DestinationPath $OpenSshDir -Force
            try {
                if (Test-Path $OpenSshZip) {
                    Remove-Item -LiteralPath $OpenSshZip -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }

        $bundled = Get-ChildItem -Path $OpenSshDir -Recurse -Filter ssh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($bundled -and (Test-Path $bundled.FullName)) {
            $resolved = $bundled.FullName
            $null = Write-Log "Using bundled ssh.exe at $resolved" "OK"
        }
    }

    if (-not $resolved) {
        throw "ssh.exe was not found (system and bundled)."
    }

    if ($resolved -is [object[]]) {
        $resolved = [string]($resolved | Select-Object -First 1)
    }

    return [string]$resolved
}

function Resolve-CloudflaredExe {
    $resolved = $null

    try {
        $cmd = Get-Command cloudflared.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
            $resolved = [string]$cmd.Source
        }
    } catch {}

    if (-not $resolved -and $finalUseScoop) {
        try {
            $scoop = Get-Command scoop -ErrorAction SilentlyContinue | Select-Object -First 1
            $shim = Join-Path $env:USERPROFILE "scoop\shims\scoop.cmd"
            if ((Test-Path $shim) -or ($scoop -and $scoop.Source)) {
                $null = Write-Log "cloudflared.exe not found; trying Scoop install: cloudflared" "INFO"
                if (Test-Path $shim) {
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "`"$shim`" install cloudflared") -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\scoop-cloudflared.log" -RedirectStandardError "$env:TEMP\scoop-cloudflared.err"
                } else {
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "scoop install cloudflared") -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\scoop-cloudflared.log" -RedirectStandardError "$env:TEMP\scoop-cloudflared.err"
                }

                if ($proc.ExitCode -eq 0) {
                    $cmd = Get-Command cloudflared.exe -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
                        $resolved = [string]$cmd.Source
                        $null = Write-Log "Found cloudflared.exe after Scoop install at $resolved" "OK"
                    }
                } else {
                    $null = Write-Log "Scoop install cloudflared failed (exit code $($proc.ExitCode)); falling back" "WARN"
                }
            }
        } catch {
            $null = Write-Log "Scoop install cloudflared failed: $_; falling back" "WARN"
        }
    }

    if (-not $resolved) {
        if (Test-Path $Cloudflared) {
            $resolved = [string]$Cloudflared
        }
    }

    return [string]$resolved
}

if (-not ("NativeWindow" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class NativeWindow {
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@
}

function Minimize-ProcessWindow {
    param([Parameter(Mandatory=$true)][System.Diagnostics.Process]$Process)

    try {
        $h = [IntPtr]::Zero
        for ($i = 0; $i -lt 50; $i++) {
            try { $Process.Refresh() } catch {}
            $h = $Process.MainWindowHandle
            if ($h -and $h -ne [IntPtr]::Zero) { break }
            Start-Sleep -Milliseconds 100
        }

        if ($h -and $h -ne [IntPtr]::Zero) {
            $null = [NativeWindow]::ShowWindowAsync($h, 6)
        }
    } catch {}
}

# --- UI --- #
$Host.UI.RawUI.WindowTitle = "Yumehana Secure Proxy (Offline SSH Test)"

if (-not $finalNoLogo -and (Test-Path $LogoScript)) {
    try { . $LogoScript; Show-AnniArt } catch {}
}

# --- global shutdown helpers --- #
function Request-Shutdown {
    param([string]$Reason)
    if ($Global:StopRequested) { return }
    $Global:StopRequested = $true
    Write-Log "Shutdown requested: $Reason" "WARN"
}
$Global:ShutdownInvoked = $false

function Invoke-GracefulShutdown {
    if ($Global:ShutdownInvoked) { return }
    $Global:ShutdownInvoked = $true

    Write-Log "Commencing graceful shutdown" "INFO"
    try { Kill-BraveProcesses -BraveDir $BraveDir } catch {}
    try { 
        if ($SshProcess -and -not $SshProcess.HasExited) { 
            Write-Log "Stopping SSH tunnel" "INFO"
            $SshProcess.Kill()
        }
    } catch {}
}

# --- startup cleanup --- #
Cleanup-Session -LockFilePath $LockFile -BraveDir $BraveDir -BinDir $BinDir

# --- acquire lock --- #
$SshProcess   = $null
$BraveProcess = $null

if (-not (Acquire-Lock -LockFilePath $LockFile)) {
    Write-Host "Cannot acquire session lock. Exiting..." -ForegroundColor Yellow
    exit
}

try {
    Write-Log "Starting secure proxy session" "INFO"

    # --- ensure OpenSSH is available (barebones Win11 safe) --- #
    $SshExe = [string]((Resolve-SshExe | Select-Object -First 1))
    $null = Write-Log ("Resolved ssh.exe: {0} (Type: {1})" -f $SshExe, $SshExe.GetType().FullName) "INFO"

    # --- ensure Brave Portable is available --- #
    Get-Binary -Name "Brave Portable" -TargetPath $Brave7zArchive -DownloadUrl $Brave7zUrl -Is7zArchive -ExtractDir $BraveDir -UseScoop:$false
    
    # Remove the 7z archive after extraction to save space
    if (Test-Path $Brave7zArchive) {
        Remove-Item $Brave7zArchive -Force -ErrorAction SilentlyContinue
        Write-Log "Removed brave-portable.7z after extraction" "INFO"
    }

    if ($finalOfflineSSHTest) {
        $SshProcess = [PSCustomObject]@{ Id = 1234; HasExited = $false }
        Write-Log "Offline SSH test mode: simulated SSH tunnel (PID $($SshProcess.Id))" "OK"
    } else {
        $CloudflaredExe = Resolve-CloudflaredExe
        if (-not $CloudflaredExe) {
            Get-Binary -Name "cloudflared" -TargetPath $Cloudflared -DownloadUrl $CloudflaredUrl -UseScoop:$false
            $CloudflaredExe = [string]$Cloudflared
        }

        $Cloudflared = [string]$CloudflaredExe
        Write-Log "Launching SSH SOCKS tunnel on port $SocksPort" "INFO"

        $useKeyAuth = $false
        $identityPath = $null
        if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
            $identityPath = Join-Path $BaseDir $IdentityFile
            if (Test-Path $identityPath) {
                $useKeyAuth = $true
            }
        }

        $knownHostsPath = $null
        if (-not [string]::IsNullOrWhiteSpace($KnownHostsFile)) {
            $knownHostsPath = Join-Path $BaseDir $KnownHostsFile
            $knownHostsDir = Split-Path $knownHostsPath -Parent
            if ($knownHostsDir -and -not (Test-Path $knownHostsDir)) {
                New-Item -ItemType Directory -Path $knownHostsDir -Force | Out-Null
            }
        }

        $SshArgs = @(
            "-N",
            "-D", "127.0.0.1:$SocksPort",
            "-o", "ProxyCommand=`"$Cloudflared access ssh --hostname %h`"",
            "$SshUser@$SshHost"
        )

        if ($useKeyAuth) {
            $SshArgs = @(
                "-N",
                "-D", "127.0.0.1:$SocksPort",
                "-i", $identityPath,
                "-o", "BatchMode=yes",
                "-o", "IdentitiesOnly=yes",
                "-o", "StrictHostKeyChecking=accept-new",
                "-o", "ProxyCommand=`"$Cloudflared access ssh --hostname %h`""
            )

            if ($knownHostsPath) {
                $SshArgs += @("-o", "UserKnownHostsFile=$knownHostsPath")
            }
            $SshArgs += @("$SshUser@$SshHost")

            Write-Log "Starting SSH using key auth (non-interactive)" "INFO"
            $SshProcess = Start-Process -FilePath $SshExe -ArgumentList $SshArgs -PassThru -NoNewWindow -RedirectStandardOutput "$LogDir\ssh-$Timestamp.log" -RedirectStandardError "$LogDir\ssh-$Timestamp.err"
        } else {
            Write-Log "Starting SSH in a separate console window to allow credential entry" "INFO"
            $SshProcess = Start-Process -FilePath $SshExe -ArgumentList $SshArgs -PassThru
        }
    }

    if ($Global:AnniProxyProvisioned -and $env:ANNIPROXY_PROVISION_RESTARTED -ne '1') {
        $env:ANNIPROXY_PROVISION_RESTARTED = '1'
        Write-Log "Provisioning completed. Restarting in a fresh PowerShell window..." "INFO"
        Start-Process -FilePath "pwsh" -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", "$PSCommandPath"
        )

        $Global:ShowExitPrompt = $false
        exit
    }

    # --- wait for SSH readiness --- #
    if (-not $finalOfflineSSHTest) {
        $ready = $false
        for ($i=0; $i -lt 20; $i++) {
            if (Test-SocksPort -Port $SocksPort) { $ready = $true; break }
            Start-Sleep 1
        }
        if (-not $ready) { throw "SOCKS proxy failed to start" }

        try { Minimize-ProcessWindow -Process $SshProcess } catch {}
    }

    Write-Log "Launching Brave Portable" "INFO"
    $BraveProcess = Start-Process $Brave -ArgumentList "--proxy-server=socks5://127.0.0.1:$SocksPort" -PassThru -RedirectStandardOutput "$LogDir\brave-$Timestamp.log" -RedirectStandardError "$LogDir\brave-$Timestamp.err"
    Write-Log "Brave launched (PID $($BraveProcess.Id))" "OK"

    # --- monitoring loop --- #
    while ($true) {
        if ($SshProcess.HasExited) { Request-Shutdown "SSH exited"; break }
        if ($BraveProcess.HasExited) { Request-Shutdown "Browser closed"; break }
        if (Console-CloseRequested) { Request-Shutdown "Console close detected"; break }
        if ($Global:StopRequested) { Request-Shutdown "Global stop requested"; break }
        Start-Sleep 1
    }

    $Global:ShowExitPrompt = $false

} catch {
    Write-Log "FATAL: $($_.Exception.Message)" "ERROR"
} finally {
    Invoke-GracefulShutdown
    Release-Lock -LockFilePath $LockFile

    if ($Global:ShowExitPrompt) {
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        [void][Console]::ReadKey($true)
    }
}

# --- end of main.ps1 --- #