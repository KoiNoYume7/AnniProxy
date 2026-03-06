# --- start of guard.ps1 --- #

function Acquire-Lock {
    param([string]$LockFilePath)

    if (Test-Path $LockFilePath) {
        $lockedPid = Get-Content $LockFilePath -ErrorAction SilentlyContinue
        if ($lockedPid) {
            $proc = Get-Process -Id $lockedPid -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Log "Session already locked by PID $lockedPid. Exiting." "WARN"
                return $false
            } else {
                Write-Log "Orphan .session.lock found for PID $lockedPid. Cleaning up..." "WARN"
                Remove-Item $LockFilePath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Set-Content -Path $LockFilePath -Value $PID -NoNewline
    Write-Log "Lock acquired (PID $PID)" "INFO"
    return $true
}

function Release-Lock {
    param([string]$LockFilePath)

    if (Test-Path $LockFilePath) {
        $lockedPid = Get-Content $LockFilePath -ErrorAction SilentlyContinue
        if ($lockedPid -eq $PID) {
            Remove-Item $LockFilePath -Force -ErrorAction SilentlyContinue
            Write-Log "Lock released (PID $PID)" "INFO"
        } else {
            Write-Log "Lock file exists but owned by PID $lockedPid, not removing" "WARN"
        }
    }
}

$Global:BraveKilledPids = @()

function Kill-BraveProcesses {
    param(
        [string]$BraveDir,
        [switch]$PromptBeforeKill
    )

    if ($PromptBeforeKill) {
        $caption = "AnniProxy cleanup"
        $message = "Brave processes were detected from: $BraveDir`nKill them now?"
        $choice = $Host.UI.PromptForChoice($caption, $message, @('&Yes', '&No'), 1)
        if ($choice -ne 0) {
            Write-Log "User declined killing Brave processes" "WARN"
            return
        }
    }

    $resolved = (Resolve-Path $BraveDir -ErrorAction SilentlyContinue).ProviderPath
    if (-not $resolved) { return }
    if (-not $resolved.EndsWith("\")) { $resolved += "\" }

    $processes = Get-CimInstance Win32_Process | Where-Object {
        $_.ExecutablePath -and $_.ExecutablePath.StartsWith(
            $resolved,
            [StringComparison]::OrdinalIgnoreCase
        ) -and $_.ProcessId
    }

    foreach ($proc in $processes) {
        if ($Global:BraveKilledPids -contains $proc.ProcessId) { continue }

        try {
            Write-Log "Killing Brave PID $($proc.ProcessId)" "WARN"
            Invoke-CimMethod -InputObject $proc -MethodName Terminate | Out-Null
            $Global:BraveKilledPids += $proc.ProcessId
        } catch {
            if ($_.Exception.Message -notmatch "Not found|no such") {
                Write-Log "Failed to kill Brave PID $($proc.ProcessId): $($_.Exception.Message)" "WARN"
            }
        }
    }
}

function Test-SocksPort {
    param([int]$Port)
    try {
        $c = [Net.Sockets.TcpClient]::new("127.0.0.1",$Port)
        $c.Close()
        return $true
    } catch {
        return $false
    }
}

function Cleanup-Session {
    param(
        [string]$LockFilePath,
        [string]$BraveDir,
        [string]$BinDir
    )

    $lockExists = Test-Path $LockFilePath

    $braveBase = (Resolve-Path $BraveDir -ErrorAction SilentlyContinue).ProviderPath
    if ($braveBase -and -not $braveBase.EndsWith("\")) { $braveBase += "\" }

    $braveProcesses = @()
    if ($braveBase) {
        $braveProcesses = Get-CimInstance Win32_Process | Where-Object {
            $_.ExecutablePath -and $_.ExecutablePath.StartsWith(
                $braveBase,
                [StringComparison]::OrdinalIgnoreCase
            )
        }
    }

    if ($lockExists -or $braveProcesses.Count -gt 0) {
        Write-Log "Detected unclean shutdown (lock=$lockExists, Brave running=$($braveProcesses.Count))" "WARN"

        if ($braveProcesses.Count -gt 0) {
            Kill-BraveProcesses -BraveDir $BraveDir -PromptBeforeKill
        }

        if (Test-Path $LockFilePath) {
            Remove-Item $LockFilePath -Force -ErrorAction SilentlyContinue
            Write-Log "Removed .session.lock file" "INFO"
        }

        # Clean up only specific subdirectories, never touch the bundled 7z
        $CloudflaredDir = Join-Path $BinDir "cloudflared"
        $BravePortableDir = Join-Path $BinDir "brave-portable"
        
        if (Test-Path $CloudflaredDir) {
            Remove-Item $CloudflaredDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Cleaned up cloudflared" "INFO"
        }
        if (Test-Path $BravePortableDir) {
            Remove-Item $BravePortableDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Cleaned up brave-portable" "INFO"
        }
    } else {
        Write-Log "No leftover session detected, everything clean" "INFO"
    }
}

# --- end of guard.ps1 --- #