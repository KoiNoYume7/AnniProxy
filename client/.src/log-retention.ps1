function Invoke-LogRetention {
    param(
        [Parameter(Mandatory=$true)][string]$LogDirPath,
        [int]$MaxFiles = 10,
        [string[]]$Categories = @("session", "ssh", "brave")
    )

    if (-not (Test-Path $LogDirPath)) { return }

    $archiveDir = Join-Path $LogDirPath ".archive"
    if (-not (Test-Path $archiveDir)) {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    }

    foreach ($c in $Categories) {
        $catDir = Join-Path $LogDirPath $c
        if (-not (Test-Path $catDir)) { continue }

        $catArchive = Join-Path $archiveDir $c
        if (-not (Test-Path $catArchive)) {
            New-Item -ItemType Directory -Path $catArchive -Force | Out-Null
        }

        $files = Get-ChildItem -Path $catDir -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime

        if (-not $files) { continue }

        $excess = $files.Count - $MaxFiles
        if ($excess -le 0) { continue }

        $toArchive = $files | Select-Object -First $excess
        foreach ($f in $toArchive) {
            $dest = Join-Path $catArchive $f.Name
            if (Test-Path $dest) {
                $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
                $ext  = [IO.Path]::GetExtension($f.Name)
                $dest = Join-Path $catArchive ("{0}.{1:yyyyMMdd-HHmmss}{2}" -f $base, $f.LastWriteTime, $ext)
            }
            try { Move-Item -LiteralPath $f.FullName -Destination $dest -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    $legacyArchive = Join-Path $archiveDir "legacy"
    if (-not (Test-Path $legacyArchive)) {
        New-Item -ItemType Directory -Path $legacyArchive -Force | Out-Null
    }

    $legacyFiles = Get-ChildItem -Path $LogDirPath -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime

    if ($legacyFiles) {
        foreach ($f in $legacyFiles) {
            $dest = Join-Path $legacyArchive $f.Name
            if (Test-Path $dest) {
                $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
                $ext  = [IO.Path]::GetExtension($f.Name)
                $dest = Join-Path $legacyArchive ("{0}.{1:yyyyMMdd-HHmmss}{2}" -f $base, $f.LastWriteTime, $ext)
            }
            try { Move-Item -LiteralPath $f.FullName -Destination $dest -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
}
