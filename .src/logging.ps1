# --- start of logging.ps1 --- #

$Global:LogLevelPriority = @{
    "ALL" = 0
    "INFO" = 1
    "OK" = 2
    "WARN" = 3
    "ERROR" = 4
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "OK", "WARN", "ERROR", "ALL")]
        [string]$Level = "INFO"
    )

    if ($Global:CurrentLogLevelPriority -gt $Global:LogLevelPriority[$Level]) {
        return
    }

    $timePrefix = if (-not $Global:SuppressTimestamp) { ("[{0:HH:mm:ss}]" -f (Get-Date)) + " " } else { "" }

    $colorMap = @{
        "INFO" = "Cyan"
        "OK"   = "Green"
        "WARN" = "Yellow"
        "ERROR"= "Red"
        "ALL"  = "Gray"
    }

    $color = $colorMap[$Level]
    $consoleLine = "{0}[{1}] {2}" -f $timePrefix, $Level, $Message
    Write-Host $consoleLine -ForegroundColor $color

    if ($Global:LogFile) {
        try {
            $logLine = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
            Add-Content -Path $Global:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch {}
    }
}

function Message {
    param([string]$Text)
    Write-Host $Text -ForegroundColor Cyan
}

function Register-GlobalErrorLogging {
    trap {
        $errMsg = $_.Exception.Message
        $errStack = $_.InvocationInfo.ScriptLineNumber
        Write-Log "Unhandled error at line ${errStack}: $errMsg" "ERROR"
        continue
    }
}

# --- end of logging.ps1 --- #