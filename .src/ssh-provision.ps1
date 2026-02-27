function Invoke-SshKeyProvision {
    param(
        [Parameter(Mandatory=$true)][string]$BaseDir,
        [Parameter(Mandatory=$true)][string]$BinDir,
        [Parameter(Mandatory=$true)][bool]$UseScoop,
        [string]$OpenSshZipUrl,
        [string]$IdentityFile,
        [string]$KnownHostsFile,
        [string]$SshHost
    )

    $secretDir = Join-Path $BaseDir ".config\.secret"
    if (-not (Test-Path $secretDir)) {
        New-Item -ItemType Directory -Path $secretDir -Force | Out-Null
    }

    $identityRel = if ([string]::IsNullOrWhiteSpace($IdentityFile)) { ".config/.secret/id_ed25519" } else { $IdentityFile }
    $knownHostsRel = if ([string]::IsNullOrWhiteSpace($KnownHostsFile)) { ".config/.secret/known_hosts" } else { $KnownHostsFile }

    $identityPath = Join-Path $BaseDir $identityRel
    $pubPath = "$identityPath.pub"
    $knownHostsPath = Join-Path $BaseDir $knownHostsRel

    $sshExe = [string](Resolve-SshExe -UseScoop:$UseScoop -OpenSshZipUrl $OpenSshZipUrl -BinDir $BinDir)

    $sshKeygenExe = $null
    try {
        $cmd = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source) { $sshKeygenExe = [string]$cmd.Source }
    } catch {}

    if (-not $sshKeygenExe) {
        try {
            $candidate = Join-Path (Split-Path $sshExe -Parent) "ssh-keygen.exe"
            if (Test-Path $candidate) { $sshKeygenExe = $candidate }
        } catch {}
    }

    if (-not $sshKeygenExe) {
        throw "ssh-keygen.exe not found. Ensure OpenSSH is installed or set openSshZipUrl in .config/config.json."
    }

    Write-Log "SSH key provisioning" "INFO"
    Write-Log "Identity target: $identityPath" "INFO"

    if (-not (Test-Path $identityPath)) {
        $identityDir = Split-Path $identityPath -Parent
        if ($identityDir -and -not (Test-Path $identityDir)) {
            New-Item -ItemType Directory -Path $identityDir -Force | Out-Null
        }

        $argLine = "-t ed25519 -f `"$identityPath`" -N `"`""
        Write-Log "Generating new ed25519 keypair" "INFO"
        $proc = Start-Process -FilePath $sshKeygenExe -ArgumentList $argLine -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            throw "ssh-keygen failed with exit code $($proc.ExitCode)"
        }
    } else {
        Write-Log "Private key already exists, skipping generation" "OK"
    }

    if (Test-Path $pubPath) {
        Write-Log "Public key:" "INFO"
        try {
            $pub = Get-Content -LiteralPath $pubPath -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($pub)) {
                Write-Host $pub
            }
        } catch {}
    }

    Write-Log "Next step: add the public key to your server's ~/.ssh/authorized_keys" "INFO"

    $sshKeyscanExe = $null
    try {
        $cmd = Get-Command ssh-keyscan.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source) { $sshKeyscanExe = [string]$cmd.Source }
    } catch {}

    if ($sshKeyscanExe -and -not [string]::IsNullOrWhiteSpace($SshHost) -and $SshHost -notmatch "example\\.com" -and $SshHost -notmatch "your-ssh") {
        $knownHostsDir = Split-Path $knownHostsPath -Parent
        if ($knownHostsDir -and -not (Test-Path $knownHostsDir)) {
            New-Item -ItemType Directory -Path $knownHostsDir -Force | Out-Null
        }

        Write-Log "Updating known_hosts using ssh-keyscan for host: $SshHost" "INFO"
        try {
            $output = & $sshKeyscanExe $SshHost 2>$null
            if ($output) {
                Set-Content -LiteralPath $knownHostsPath -Value $output -Encoding ASCII
                Write-Log "Wrote known_hosts: $knownHostsPath" "OK"
            } else {
                Write-Log "ssh-keyscan returned no output; known_hosts not updated" "WARN"
            }
        } catch {
            Write-Log "ssh-keyscan failed; known_hosts not updated" "WARN"
        }
    } else {
        Write-Log "Skipping known_hosts update (ssh-keyscan not available or host is placeholder/missing)" "WARN"
        Write-Log "If you want a dedicated known_hosts file, create it at: $knownHostsPath" "INFO"
    }

    Write-Log "Provisioning complete" "OK"
}
