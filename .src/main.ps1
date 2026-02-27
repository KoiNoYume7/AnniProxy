# --- start of main.ps1 --- #

[CmdletBinding()]
param(
    [switch]$NoLogo,
    [ValidateSet("INFO","OK","WARN","ERROR","ALL")]
    [string]$LogLevel,
    [switch]$NoTimestamp,
    [switch]$OfflineSSHTest,
    [switch]$UseScoop,
    [switch]$HealthCheckOnly,
    [switch]$ProvisionKeys
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

$finalUseCloudflaredAccessProxy = $true
try {
    if ($null -ne $appConfig.useCloudflaredAccessProxy) {
        $finalUseCloudflaredAccessProxy = [bool]$appConfig.useCloudflaredAccessProxy
    }
} catch {}

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

$SshConfigLocalPath = Join-Path $BaseDir ".config\ssh.local.json"
if (Test-Path $SshConfigLocalPath) {
    try {
        $sshLocal = Get-Content $SshConfigLocalPath -Raw | ConvertFrom-Json
        foreach ($p in $sshLocal.PSObject.Properties) {
            try { $sshConfig | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force } catch {}
        }
    } catch {
        throw "Failed to parse SSH override config: $SshConfigLocalPath ($($_.Exception.Message))"
    }
}

if (-not (Test-Path $SshConfigLocalPath) -and -not $ProvisionKeys -and -not $HealthCheckOnly) {
    $hostVal = $null
    $userVal = $null
    try { $hostVal = [string]$sshConfig.host } catch {}
    try { $userVal = [string]$sshConfig.user } catch {}

    $isPlaceholder = $false
    if ([string]::IsNullOrWhiteSpace($hostVal) -or $hostVal -match "example\.com" -or $hostVal -match "your-ssh") { $isPlaceholder = $true }
    if ([string]::IsNullOrWhiteSpace($userVal) -or $userVal -match "your-ssh") { $isPlaceholder = $true }

    if ($isPlaceholder) {
        Write-Host "" 
        Write-Host "First-time setup: .config/ssh.json is still placeholder." -ForegroundColor Yellow
        Write-Host "I'll create a gitignored .config/ssh.local.json with your real SSH target." -ForegroundColor Yellow

        $promptUser = Read-Host "SSH username"
        $promptHost = Read-Host "SSH host (e.g. yme-04.yumehana.dev)"
        $promptPort = Read-Host "SOCKS port [default: 1080]"

        if ([string]::IsNullOrWhiteSpace($promptUser) -or [string]::IsNullOrWhiteSpace($promptHost)) {
            throw "SSH username/host not provided; aborting. You can also create .config/ssh.local.json manually."
        }

        $finalPort = 1080
        if (-not [string]::IsNullOrWhiteSpace($promptPort)) {
            $p = 0
            if (-not [int]::TryParse($promptPort, [ref]$p) -or $p -le 0 -or $p -gt 65535) {
                throw "Invalid SOCKS port: $promptPort"
            }
            $finalPort = $p
        }

        $localObj = [PSCustomObject]@{
            user = $promptUser
            host = $promptHost
            socksPort = $finalPort
        }

        try {
            $json = $localObj | ConvertTo-Json -Depth 3
            Set-Content -LiteralPath $SshConfigLocalPath -Value $json -Encoding UTF8
        } catch {
            throw "Failed to write ${SshConfigLocalPath}: $($_.Exception.Message)"
        }

        foreach ($p in $localObj.PSObject.Properties) {
            try { $sshConfig | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force } catch {}
        }

        Write-Host "Wrote $SshConfigLocalPath" -ForegroundColor Green
    }
}

$SshUser   = $sshConfig.user
$SshHost   = $sshConfig.host
$SocksPort = $sshConfig.socksPort

$IdentityFile   = $sshConfig.identityFile
$KnownHostsFile = $sshConfig.knownHostsFile

# --- logging setup --- #
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$SessionLogDir = Join-Path $LogDir "session"
$SshLogDir     = Join-Path $LogDir "ssh"
$BraveLogDir   = Join-Path $LogDir "brave"

if (-not (Test-Path $SessionLogDir)) { New-Item -ItemType Directory -Path $SessionLogDir -Force | Out-Null }
if (-not (Test-Path $SshLogDir)) { New-Item -ItemType Directory -Path $SshLogDir -Force | Out-Null }
if (-not (Test-Path $BraveLogDir)) { New-Item -ItemType Directory -Path $BraveLogDir -Force | Out-Null }

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Global:LogFile = Join-Path $SessionLogDir "session-$Timestamp.log"
$Global:CurrentLogLevelPriority = @{"ALL"=0;"INFO"=1;"OK"=2;"WARN"=3;"ERROR"=4}[$finalLogLevel]

$Global:SuppressTimestamp = $finalNoTimestamp

$Global:AnniProxyProvisioned = $false

$Global:ShowExitPrompt = $true

# --- modules --- #
. "$PSScriptRoot/logging.ps1"
. "$PSScriptRoot/log-retention.ps1"
. "$PSScriptRoot/guard.ps1"
. "$PSScriptRoot/console-guard.ps1"
. "$PSScriptRoot/get-binaries.ps1"
. "$PSScriptRoot/exe-resolvers.ps1"
. "$PSScriptRoot/ssh-utils.ps1"
. "$PSScriptRoot/ssh-tunnel.ps1"
. "$PSScriptRoot/window-utils.ps1"
. "$PSScriptRoot/ssh-provision.ps1"
. "$PSScriptRoot/healthcheck.ps1"

Invoke-LogRetention -LogDirPath $LogDir -MaxFiles 10 -Categories @("session","ssh","brave")

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
    $SshExe = [string]((Resolve-SshExe -UseScoop:$finalUseScoop -OpenSshZipUrl $OpenSshZipUrl -BinDir $BinDir | Select-Object -First 1))
    $null = Write-Log ("Resolved ssh.exe: {0} (Type: {1})" -f $SshExe, $SshExe.GetType().FullName) "INFO"

    if ($ProvisionKeys) {
        Invoke-SshKeyProvision -BaseDir $BaseDir -BinDir $BinDir -UseScoop:$finalUseScoop -OpenSshZipUrl $OpenSshZipUrl -IdentityFile $IdentityFile -KnownHostsFile $KnownHostsFile -SshHost $SshHost
        $Global:ShowExitPrompt = $true
        return
    }

    if ($HealthCheckOnly) {
        $ok = Invoke-HealthCheck -BaseDir $BaseDir -BinDir $BinDir -UseScoop:$finalUseScoop -OpenSshZipUrl $OpenSshZipUrl -CloudflaredDefaultPath $Cloudflared -UseCloudflaredAccessProxy:$finalUseCloudflaredAccessProxy -SshHost $SshHost -SshUser $SshUser -SocksPort $SocksPort -IdentityFile $IdentityFile -KnownHostsFile $KnownHostsFile
        $Global:ShowExitPrompt = $false
        if ($ok) { exit 0 } else { exit 2 }
    }

    if ([string]::IsNullOrWhiteSpace($SshHost) -or [string]::IsNullOrWhiteSpace($SshUser)) {
        throw "Invalid .config/ssh.json: 'user' and 'host' must be set"
    }

    if ($SshHost -match "example\.com" -or $SshHost -match "your-ssh") {
        throw "Invalid .config/ssh.json: 'host' is still a placeholder ($SshHost). Set it to your real host (e.g. yme-04.yumehana.dev)."
    }

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
        $CloudflaredExe = Resolve-CloudflaredExe -UseScoop:$finalUseScoop -DefaultCloudflaredPath $Cloudflared
        if (-not $CloudflaredExe) {
            Get-Binary -Name "cloudflared" -TargetPath $Cloudflared -DownloadUrl $CloudflaredUrl -UseScoop:$false
            $CloudflaredExe = [string]$Cloudflared
        }

        $Cloudflared = [string]$CloudflaredExe
        $SshProcess = Start-SshSocksTunnel -SshExe $SshExe -CloudflaredExe $Cloudflared -UseCloudflaredAccessProxy:$finalUseCloudflaredAccessProxy -SocksPort $SocksPort -SshUser $SshUser -SshHost $SshHost -IdentityFile $IdentityFile -KnownHostsFile $KnownHostsFile -BaseDir $BaseDir -LogDir $SshLogDir -Timestamp $Timestamp
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
        try {
            $resolved = $null
            try { $resolved = Get-Process -Id $SshProcess.Id -ErrorAction SilentlyContinue } catch {}
            if ($resolved) { $SshProcess = $resolved }

            $target = $SshProcess
            $targetSession = $null
            try { $targetSession = $target.SessionId } catch {}

            if (-not $target -or $target.ProcessName -ne 'ssh') {
                $sid = $null
                try { $sid = (Get-Process -Id $PID -ErrorAction SilentlyContinue).SessionId } catch {}
                if ($null -eq $sid) { $sid = $targetSession }

                $sshCandidates = @()
                try {
                    $sshCandidates = Get-Process -Name ssh -ErrorAction SilentlyContinue
                } catch {}

                if ($null -ne $sid) {
                    $sshCandidates = $sshCandidates | Where-Object {
                        try { $_.SessionId -eq $sid } catch { $false }
                    }
                }

                $sshCandidates = $sshCandidates | Sort-Object StartTime -Descending
                if ($sshCandidates -and $sshCandidates.Count -gt 0) {
                    $target = $sshCandidates | Select-Object -First 1
                }
            }

            if ($target -and $target.ProcessName -eq 'ssh') {
                Write-Log "Hiding SSH auth window using PID $($target.Id) (ssh)" "INFO"
                Minimize-ProcessWindow -Process $target -Action Hide
            } else {
                $pname = $null
                $pidVal = $null
                try { $pname = $target.ProcessName } catch {}
                try { $pidVal = $target.Id } catch {}
                Write-Log "Skip Hide: could not resolve ssh.exe process (got PID $pidVal ($pname))" "WARN"
            }
        } catch {}
    }

    Write-Log "Launching Brave Portable" "INFO"
    $BraveProcess = Start-Process $Brave -ArgumentList "--proxy-server=socks5://127.0.0.1:$SocksPort" -PassThru -RedirectStandardOutput "$BraveLogDir\brave-$Timestamp.log" -RedirectStandardError "$BraveLogDir\brave-$Timestamp.err"
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