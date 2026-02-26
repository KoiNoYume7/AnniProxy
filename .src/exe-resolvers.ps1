function Resolve-SshExe {
    param(
        [Parameter(Mandatory=$true)][bool]$UseScoop,
        [string]$OpenSshZipUrl,
        [Parameter(Mandatory=$true)][string]$BinDir
    )

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

    if (-not $resolved -and $UseScoop) {
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

        $null = Get-Binary -Name "OpenSSH" -TargetPath $OpenSshZip -DownloadUrl $OpenSshZipUrl -UseScoop:$UseScoop

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
    param(
        [Parameter(Mandatory=$true)][bool]$UseScoop,
        [Parameter(Mandatory=$true)][string]$DefaultCloudflaredPath
    )

    $resolved = $null

    try {
        $cmd = Get-Command cloudflared.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
            $resolved = [string]$cmd.Source
        }
    } catch {}

    if (-not $resolved -and $UseScoop) {
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
        if (Test-Path $DefaultCloudflaredPath) {
            $resolved = [string]$DefaultCloudflaredPath
        }
    }

    return [string]$resolved
}
