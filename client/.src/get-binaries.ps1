# --- start of get-binaries.ps1 --- #

function Get-7ZipExe {
    # Load config.json
    $configPath = Join-Path (Split-Path -Parent $PSScriptRoot) ".config\config.json"
    if (-not (Test-Path $configPath)) {
        throw "config.json not found at $configPath"
    }
    $config = Get-Content $configPath | ConvertFrom-Json

    $useScoop = $config.useScoop
    $downloadUrl = $config.'7zUrl'

    # Try system 7z.exe first
    $sys7z = where.exe 7z.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sys7z -and (Test-Path $sys7z)) {
        Write-Log "Found system 7z.exe at $sys7z" "OK"
        return $sys7z
    }

    # If Scoop installation is enabled
    if ($useScoop) {
        Write-Log "Installing 7zip via Scoop..." "INFO"
        try {
            $shim = Join-Path $env:USERPROFILE "scoop\shims\scoop.cmd"
            if (Test-Path $shim) {
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "`"$shim`" install 7zip") -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\scoop-7zip.log" -RedirectStandardError "$env:TEMP\scoop-7zip.err"
            } else {
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "scoop install 7zip") -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\scoop-7zip.log" -RedirectStandardError "$env:TEMP\scoop-7zip.err"
            }
            if ($proc.ExitCode -eq 0) {
                $scoopPath = "$env:USERPROFILE\scoop\apps\7zip\current\7z.exe"
                if (Test-Path $scoopPath) {
                    Write-Log "7zip installed via Scoop at $scoopPath" "OK"
                    return $scoopPath
                } else {
                    Write-Log "7zip installed via Scoop but exe not found, falling back to download" "WARN"
                }
            } else {
                Write-Log "Scoop installation failed with exit code $($proc.ExitCode), falling back to direct download" "WARN"
            }
        } catch {
            Write-Log "Scoop installation failed: $_, falling back to direct download" "WARN"
        }
    }

    # Fall back to direct download and bundled 7zr.exe (portable)
    $SevenZip = Join-Path (Split-Path -Parent $PSScriptRoot) ".bin\7zip\7zr.exe"
    if (-not (Test-Path $SevenZip)) {
        Write-Log "Downloading 7zip from $downloadUrl..." "INFO"
        $SevenZipDir = Split-Path $SevenZip -Parent
        if (-not (Test-Path $SevenZipDir)) { New-Item -ItemType Directory -Path $SevenZipDir -Force | Out-Null }
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $SevenZip -UseBasicParsing
            Write-Log "7zip downloaded successfully to $SevenZip" "OK"
        }
        catch {
            Write-Log "Failed to download 7zip: $_" "ERROR"
            throw
        }
    } else {
        Write-Log "Using existing bundled 7zr.exe at $SevenZip" "OK"
    }

    return $SevenZip
}

function Get-Binary {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$TargetPath,
        [Parameter(Mandatory=$true)]
        [string]$DownloadUrl,
        [switch]$Is7zArchive,
        [string]$ExtractDir,
        [switch]$UseScoop
    )

    if ([string]::IsNullOrWhiteSpace($DownloadUrl)) {
        throw "DownloadUrl is empty for '$Name'. Check .config/config.json and make sure the corresponding URL setting is present and non-empty."
    }

    function Invoke-ScoopInstallIfNeeded {
        param(
            [Parameter(Mandatory=$true)][string]$PackageName,
            [Parameter(Mandatory=$true)][string]$ExpectedExeName
        )

        try {
            $shim = Join-Path $env:USERPROFILE "scoop\shims\scoop.cmd"
            $hasShim = Test-Path $shim

            $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $hasShim -and -not $scoopCmd) { return $null }

            Write-Log "Trying Scoop install for $PackageName" "INFO"

            if ($hasShim) {
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "`"$shim`" install $PackageName") -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\scoop-$PackageName.log" -RedirectStandardError "$env:TEMP\scoop-$PackageName.err"
            } else {
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "scoop install $PackageName") -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\scoop-$PackageName.log" -RedirectStandardError "$env:TEMP\scoop-$PackageName.err"
            }
            if ($proc.ExitCode -ne 0) {
                Write-Log "Scoop install for $PackageName failed (exit code $($proc.ExitCode)); falling back" "WARN"
                return $null
            }

            $appExe = Join-Path $env:USERPROFILE "scoop\apps\$PackageName\current\$ExpectedExeName"
            if (Test-Path $appExe) { return $appExe }

            $shimExe = Join-Path $env:USERPROFILE "scoop\shims\$ExpectedExeName"
            if (Test-Path $shimExe) { return $shimExe }

            $cmd = Get-Command $ExpectedExeName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) { return [string]$cmd.Source }

            return $null
        } catch {
            Write-Log "Scoop install for $PackageName failed: $_; falling back" "WARN"
            return $null
        }
    }

    if ($UseScoop -and -not $Is7zArchive) {
        $targetExt = [IO.Path]::GetExtension($TargetPath)
        if ($targetExt -ieq '.exe') {
            $pkg = $null
            $exe = $null
            switch -Regex ($Name) {
                '^cloudflared$' { $pkg = 'cloudflared'; $exe = 'cloudflared.exe'; break }
            }

            if ($pkg -and $exe) {
                $installedExe = Invoke-ScoopInstallIfNeeded -PackageName $pkg -ExpectedExeName $exe
                if ($installedExe -and (Test-Path $installedExe)) {
                    $targetDir = Split-Path $TargetPath -Parent
                    if ($targetDir -and -not (Test-Path $targetDir)) {
                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    }

                    try {
                        Copy-Item -LiteralPath $installedExe -Destination $TargetPath -Force
                        $Global:AnniProxyProvisioned = $true
                        Write-Log "Installed $Name via Scoop to $TargetPath" "OK"
                        return $TargetPath
                    } catch {
                        Write-Log "Scoop provided $installedExe but copying to $TargetPath failed: $_; falling back" "WARN"
                    }
                }
            }
        }
    }

    if (-not $Is7zArchive) {
        if (Test-Path $TargetPath) {
            Write-Log "$Name already present at $TargetPath" "OK"
            return $TargetPath
        }

        $targetDir = Split-Path $TargetPath -Parent
        if ($targetDir -and -not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        Write-Log "Downloading $Name from $DownloadUrl" "INFO"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TargetPath -UseBasicParsing
        $Global:AnniProxyProvisioned = $true
        Write-Log "Downloaded $Name to $TargetPath" "OK"
        return $TargetPath
    }

    if (-not $ExtractDir) {
        throw "ExtractDir is required when Is7zArchive is set"
    }

    if (Test-Path $ExtractDir) {
        Write-Log "$Name already extracted at $ExtractDir" "OK"
        return $ExtractDir
    }

    $archiveDir = Split-Path $TargetPath -Parent
    if ($archiveDir -and -not (Test-Path $archiveDir)) {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    }

    if (-not (Test-Path $TargetPath)) {
        Write-Log "Downloading $Name archive from $DownloadUrl" "INFO"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TargetPath -UseBasicParsing
        $Global:AnniProxyProvisioned = $true
        Write-Log "Downloaded $Name archive to $TargetPath" "OK"
    }

    $sevenZip = Get-7ZipExe
    $extractParent = Split-Path $ExtractDir -Parent
    if ($extractParent -and -not (Test-Path $extractParent)) {
        New-Item -ItemType Directory -Path $extractParent -Force | Out-Null
    }

    Write-Log "Extracting $Name archive" "INFO"
    $sevenZipArgs = @(
        "x",
        "-y",
        "-o$ExtractDir",
        $TargetPath
    )
    $proc = Start-Process -FilePath $sevenZip -ArgumentList $sevenZipArgs -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) {
        throw "7zip extraction failed for $Name (exit code $($proc.ExitCode))"
    }

    $Global:AnniProxyProvisioned = $true
    Write-Log "Extracted $Name to $ExtractDir" "OK"
    return $ExtractDir
}

# --- end of get-binaries.ps1 --- #