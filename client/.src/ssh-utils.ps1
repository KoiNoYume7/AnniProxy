function Get-FileTail {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [int]$Lines = 120
    )

    try {
        if (-not (Test-Path $Path)) { return $null }
        return (Get-Content -LiteralPath $Path -Tail $Lines -ErrorAction SilentlyContinue)
    } catch {
        return $null
    }
}

function Wait-ForSocksReady {
    param(
        [Parameter(Mandatory=$true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory=$true)][int]$Port,
        [int]$MaxSeconds = 20,
        [string]$Mode = "SSH"
    )

    $ready = $false
    for ($i = 0; $i -lt $MaxSeconds; $i++) {
        try {
            if ($Process.HasExited) {
                $exitCode = $null
                try { $exitCode = $Process.ExitCode } catch {}
                if ($null -ne $exitCode) {
                    Write-Log "$Mode process exited while waiting for SOCKS readiness (ExitCode=$exitCode)" "WARN"
                } else {
                    Write-Log "$Mode process exited while waiting for SOCKS readiness" "WARN"
                }
                break
            }
        } catch {}

        if (Test-SocksPort -Port $Port) { $ready = $true; break }
        Start-Sleep 1
    }

    return $ready
}
