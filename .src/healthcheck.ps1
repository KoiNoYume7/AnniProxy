function Invoke-HealthCheck {
    param(
        [Parameter(Mandatory=$true)][string]$BaseDir,
        [Parameter(Mandatory=$true)][string]$BinDir,
        [Parameter(Mandatory=$true)][bool]$UseScoop,
        [string]$OpenSshZipUrl,
        [string]$CloudflaredDefaultPath,
        [bool]$UseCloudflaredAccessProxy = $true,
        [string]$SshHost,
        [string]$SshUser,
        [int]$SocksPort,
        [string]$IdentityFile,
        [string]$KnownHostsFile
    )

    Write-Log "Health check" "INFO"
    Write-Log "PowerShell: $($PSVersionTable.PSVersion)" "INFO"

    $ok = $true

    if ([string]::IsNullOrWhiteSpace($SshUser) -or [string]::IsNullOrWhiteSpace($SshHost)) {
        Write-Log "SSH config: user/host missing" "ERROR"
        $ok = $false
    } elseif ($SshHost -match "example\\.com" -or $SshHost -match "your-ssh") {
        Write-Log "SSH config: host is still placeholder ($SshHost)" "ERROR"
        $ok = $false
    } else {
        Write-Log "SSH target: $SshUser@$SshHost" "INFO"
    }

    if ($SocksPort -le 0) {
        Write-Log "SSH config: socksPort invalid ($SocksPort)" "ERROR"
        $ok = $false
    } else {
        Write-Log "SOCKS port: $SocksPort" "INFO"
    }

    try {
        $sshExe = [string](Resolve-SshExe -UseScoop:$UseScoop -OpenSshZipUrl $OpenSshZipUrl -BinDir $BinDir)
        if (Test-Path $sshExe) {
            Write-Log "Resolved ssh.exe: $sshExe" "OK"
        } else {
            Write-Log "Resolved ssh.exe but file not found: $sshExe" "ERROR"
            $ok = $false
        }
    } catch {
        Write-Log "Failed to resolve ssh.exe: $($_.Exception.Message)" "ERROR"
        $ok = $false
    }

    if ($UseCloudflaredAccessProxy) {
        try {
            $cloudflaredExe = Resolve-CloudflaredExe -UseScoop:$UseScoop -DefaultCloudflaredPath $CloudflaredDefaultPath
            if ($cloudflaredExe -and (Test-Path $cloudflaredExe)) {
                Write-Log "Resolved cloudflared.exe: $cloudflaredExe" "OK"
            } else {
                Write-Log "cloudflared.exe not found (required when UseCloudflaredAccessProxy=true)" "ERROR"
                $ok = $false
            }
        } catch {
            Write-Log "Failed to resolve cloudflared.exe: $($_.Exception.Message)" "ERROR"
            $ok = $false
        }
    } else {
        Write-Log "Cloudflared Access proxy: disabled" "INFO"
    }

    $identityPath = $null
    if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
        $identityPath = Join-Path $BaseDir $IdentityFile
        if (Test-Path $identityPath) {
            Write-Log "Identity file exists: $identityPath" "OK"
        } else {
            Write-Log "Identity file missing: $identityPath" "WARN"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($KnownHostsFile)) {
        $knownHostsPath = Join-Path $BaseDir $KnownHostsFile
        if (Test-Path $knownHostsPath) {
            Write-Log "known_hosts exists: $knownHostsPath" "OK"
        } else {
            Write-Log "known_hosts missing: $knownHostsPath" "WARN"
        }
    }

    try {
        if (-not [string]::IsNullOrWhiteSpace($SshHost) -and $SshHost -notmatch "example\\.com" -and $SshHost -notmatch "your-ssh") {
            $null = [System.Net.Dns]::GetHostEntry($SshHost)
            Write-Log "DNS resolution: OK" "OK"
        }
    } catch {
        Write-Log "DNS resolution failed for host '$SshHost'" "WARN"
    }

    if ($ok) {
        Write-Log "Health check passed" "OK"
        return $true
    }

    Write-Log "Health check failed" "ERROR"
    return $false
}
