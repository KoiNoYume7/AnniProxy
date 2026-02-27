function Start-SshSocksTunnel {
    param(
        [Parameter(Mandatory=$true)][string]$SshExe,
        [Parameter(Mandatory=$true)][string]$CloudflaredExe,
        [bool]$UseCloudflaredAccessProxy = $true,
        [Parameter(Mandatory=$true)][int]$SocksPort,
        [Parameter(Mandatory=$true)][string]$SshUser,
        [Parameter(Mandatory=$true)][string]$SshHost,
        [string]$IdentityFile,
        [string]$KnownHostsFile,
        [Parameter(Mandatory=$true)][string]$BaseDir,
        [Parameter(Mandatory=$true)][string]$LogDir,
        [Parameter(Mandatory=$true)][string]$Timestamp
    )

    Write-Log "Launching SSH SOCKS tunnel on port $SocksPort" "INFO"

    $useKeyAuth = $false
    $identityPath = $null
    if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
        $identityPath = Join-Path $BaseDir $IdentityFile
        if (Test-Path $identityPath) {
            $useKeyAuth = $true
        }
    }

    if ($identityPath) {
        if ($useKeyAuth) {
            Write-Log "Resolved identity file: $identityPath" "INFO"
        } else {
            Write-Log "Identity file configured but missing: $identityPath" "WARN"
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

    if ($knownHostsPath) {
        Write-Log "Resolved known_hosts file: $knownHostsPath" "INFO"
    }

    $proxyCommand = $null
    if ($UseCloudflaredAccessProxy) {
        $proxyCommand = "$CloudflaredExe access ssh --hostname %h"
        Write-Log "Using cloudflared access ssh ProxyCommand" "INFO"
    } else {
        Write-Log "Cloudflared access ssh ProxyCommand disabled; using direct SSH" "INFO"
    }

    $SshArgs = @(
        "-N",
        "-D", "127.0.0.1:$SocksPort",
        "$SshUser@$SshHost"
    )

    if ($UseCloudflaredAccessProxy -and $proxyCommand) {
        $SshArgs = @(
            "-N",
            "-D", "127.0.0.1:$SocksPort",
            "-o", "ProxyCommand=`"$proxyCommand`"",
            "$SshUser@$SshHost"
        )
    }

    $SshLogOut = Join-Path $LogDir "ssh-$Timestamp.log"
    $SshLogErr = Join-Path $LogDir "ssh-$Timestamp.err"

    if ($useKeyAuth) {
        $SshArgsKey = @(
            "-N",
            "-D", "127.0.0.1:$SocksPort",
            "-i", $identityPath,
            "-o", "BatchMode=yes",
            "-o", "IdentitiesOnly=yes",
            "-o", "StrictHostKeyChecking=accept-new"
        )

        if ($UseCloudflaredAccessProxy -and $proxyCommand) {
            $SshArgsKey += @("-o", "ProxyCommand=`"$proxyCommand`"")
        }

        if ($knownHostsPath) {
            $SshArgsKey += @("-o", "UserKnownHostsFile=$knownHostsPath")
        }
        $SshArgsKey += @("$SshUser@$SshHost")

        Write-Log "Starting SSH using key auth (non-interactive)" "INFO"
        Write-Log "SSH stdout: $SshLogOut" "INFO"
        Write-Log "SSH stderr: $SshLogErr" "INFO"
        Write-Log ("SSH args (key auth): {0}" -f ($SshArgsKey -join ' ')) "INFO"

        $sshProc = Start-Process -FilePath $SshExe -ArgumentList $SshArgsKey -PassThru -NoNewWindow -RedirectStandardOutput $SshLogOut -RedirectStandardError $SshLogErr
        try {
            $resolved = Get-Process -Id $sshProc.Id -ErrorAction SilentlyContinue
            if ($resolved) { $sshProc = $resolved }
        } catch {}
        try { Write-Log "SSH process started (key auth) PID $($sshProc.Id) ($($sshProc.ProcessName))" "ALL" } catch {}

        $readyKey = Wait-ForSocksReady -Process $sshProc -Port $SocksPort -MaxSeconds 20 -Mode "SSH (key auth)"
        if ($readyKey) {
            return $sshProc
        }

        $tail = Get-FileTail -Path $SshLogErr -Lines 120
        if ($tail) {
            Write-Log "SSH key-auth stderr tail:" "WARN"
            foreach ($line in $tail) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Log ("ssh: {0}" -f $line) "WARN"
                }
            }
        } else {
            Write-Log "No SSH stderr output captured for key-auth attempt" "WARN"
        }

        try {
            if ($sshProc -and -not $sshProc.HasExited) {
                Write-Log "Stopping failed key-auth SSH process" "WARN"
                $sshProc.Kill()
            }
        } catch {}

        $SshArgsInteractive = @(
            "-N",
            "-D", "127.0.0.1:$SocksPort",
            "-o", "StrictHostKeyChecking=accept-new"
        )

        if ($UseCloudflaredAccessProxy -and $proxyCommand) {
            $SshArgsInteractive += @("-o", "ProxyCommand=`"$proxyCommand`"")
        }

        if ($identityPath -and (Test-Path $identityPath)) {
            $SshArgsInteractive += @("-i", $identityPath)
            $SshArgsInteractive += @("-o", "IdentitiesOnly=yes")
        }

        if ($knownHostsPath) {
            $SshArgsInteractive += @("-o", "UserKnownHostsFile=$knownHostsPath")
        }

        $SshArgsInteractive += @("$SshUser@$SshHost")

        Write-Log "Falling back to interactive SSH authentication (password allowed)" "WARN"
        Write-Log ("SSH args (interactive): {0}" -f ($SshArgsInteractive -join ' ')) "INFO"

        $sshProc = Start-Process -FilePath $SshExe -ArgumentList $SshArgsInteractive -PassThru
        try {
            $resolved = Get-Process -Id $sshProc.Id -ErrorAction SilentlyContinue
            if ($resolved) { $sshProc = $resolved }
        } catch {}
        try { Write-Log "SSH process started (interactive fallback) PID $($sshProc.Id) ($($sshProc.ProcessName))" "ALL" } catch {}

        Write-Log "Waiting for tunnel readiness (interactive auth can take time)" "INFO"
        $readyInteractive = Wait-ForSocksReady -Process $sshProc -Port $SocksPort -MaxSeconds 600 -Mode "SSH (interactive)"
        if (-not $readyInteractive) {
            throw "SOCKS proxy failed to start (interactive auth timeout)"
        }

        return $sshProc
    }

    Write-Log "Starting SSH in a separate console window to allow credential entry" "INFO"
    Write-Log ("SSH args (interactive): {0}" -f ($SshArgs -join ' ')) "INFO"

    $sshProc = Start-Process -FilePath $SshExe -ArgumentList $SshArgs -PassThru
    try {
        $resolved = Get-Process -Id $sshProc.Id -ErrorAction SilentlyContinue
        if ($resolved) { $sshProc = $resolved }
    } catch {}
    try { Write-Log "SSH process started (interactive) PID $($sshProc.Id) ($($sshProc.ProcessName))" "ALL" } catch {}

    Write-Log "Waiting for tunnel readiness (interactive auth can take time)" "INFO"
    $readyInteractive = Wait-ForSocksReady -Process $sshProc -Port $SocksPort -MaxSeconds 600 -Mode "SSH (interactive)"
    if (-not $readyInteractive) {
        throw "SOCKS proxy failed to start (interactive auth timeout)"
    }

    return $sshProc
}
