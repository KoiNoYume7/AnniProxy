# AI Coding Agent Instructions for AnniProxy

## PROJECT SUMMARY
**AnniProxy** is a PowerShell 7+ Windows application that launches a portable browser whose traffic is routed through a **local SSH SOCKS5 tunnel** (localhost-only). The lifecycle—binary acquisition, tunnel management, browser launch, monitoring, and cleanup—is orchestrated by `.src/main.ps1` with supporting modules.

**Key Constraint**: PowerShell 7+ only. No PS 5.1 compatibility. Single-instance execution enforced via `.session.lock`.

**Configuration layering**:
- Base (committed): `.config/config.json`, `.config/ssh.json` (placeholder-safe)
- Override (gitignored): `.config/ssh.local.json` (real host/user, etc.)

**Log organization (current)**: logs are grouped into subfolders under `.log/`:

- **`.log/session/`**: AnniProxy session logs (`session-YYYYMMDD-HHMMSS.log`)
- **`.log/ssh/`**: SSH stdout/stderr capture (`ssh-*.log` / `ssh-*.err`)
- **`.log/brave/`**: Brave stdout/stderr capture (`brave-*.log` / `brave-*.err`)

Old logs are archived (never deleted) into **`.log/.archive/<category>/`**.

---

## SSH TUNNEL IMPLEMENTATION (AUTHORITATIVE)

### `Start-SshSocksTunnel` (`.src/ssh-tunnel.ps1`)

This function encapsulates all SSH startup logic and is the authoritative place to change SSH args.

Behavior:

- **Preferred**: key auth (non-interactive)
  - Uses `-i <identity>`
  - Uses `BatchMode=yes` to fail fast when key auth is not possible
  - Captures stdout/stderr into `.log/ssh/ssh-<timestamp>.log` and `.log/ssh/ssh-<timestamp>.err`
- **Fallback**: interactive auth
  - Launches `ssh.exe` in a separate console window so the user can type password/confirm prompts
  - Waits for SOCKS readiness up to 600s

Cloudflare Access integration:

- Optional behavior controlled by `.config/config.json` `useCloudflaredAccessProxy`.
- When enabled, SSH args include a `ProxyCommand` that routes SSH via `cloudflared access ssh ...`.
- When disabled, SSH connects directly to the SSH server (no `ProxyCommand`).

Readiness:

- Uses `Wait-ForSocksReady` which checks:
  - the SSH process is still alive
  - the SOCKS port is accepting connections (via `Test-SocksPort` in `guard.ps1`)

Invariants:

- Never change the SOCKS bind host away from `127.0.0.1`.
- Never remove the monitoring loop in `main.ps1` that ties SSH+Brave lifecycles together.

## SSH AUTH WINDOW HIDING (AUTHORITATIVE)

### Goal

After interactive SSH authentication completes (tunnel ready), hide the separate SSH auth console window so it does not remain visible/minimized for the user.

### Constraints / Safety

- **Never hide the main AnniProxy console.**
- When `-Action Hide` is used we intentionally do **not** hide `wt.exe` / `WindowsTerminal.exe` because doing so can hide the entire terminal hosting AnniProxy.

### Implementation (`.src/window-utils.ps1`)

`Minimize-ProcessWindow -Action Hide`:

- Attempts to hide the process window directly.
- Attempts child `conhost.exe` (classic console host).
- Walks the process tree from `ssh.exe` and looks for descendant console hosts.
- If `MainWindowHandle` is zero (common), it uses Win32 APIs:
  - `EnumWindows`
  - `GetWindowThreadProcessId`
  - then calls `ShowWindowAsync(hwnd, SW_HIDE)`

The combination of process-tree traversal + `EnumWindows` is required for reliability.

## LOG RETENTION / ARCHIVING (AUTHORITATIVE)

### `Invoke-LogRetention` (`.src/log-retention.ps1`)

- Keeps the newest `MaxFiles` in each active category folder:
  - `.log/session`
  - `.log/ssh`
  - `.log/brave`
- Moves older files into `.log/.archive/<category>/` (never deletes).
- Moves any legacy root-level log files in `.log/` into `.log/.archive/legacy/`.

---

## ARCHITECTURE & DATA FLOW

### Execution Flow (Entry Point to Runtime)
```
run.bat (user launches)
  ↓ Parses environment
  ├─ Searches for PowerShell 7 in this order:
  │   1) bundled: .bin\pwsh7+\pwsh.exe
  │   2) system PATH: pwsh
  │   3) if useScoop=true: install via Scoop
  │   4) if useScoop=false: manual bootstrap from .config/config.json pwsh7.5.4Url (zip) into .bin\pwsh7+\
  ├─ Generates: .tmp\bootstrap.ps1 (small wrapper)
  │   - Starts Start-Transcript to .log\bootstrap.log (append)
  │   - Invokes .src\main.ps1
  │   - Pauses on failure (prevents instant-close)
  └─ Invokes: pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .tmp\bootstrap.ps1

.src/main.ps1 (bootstrap & orchestrator)
  ├─ Enforces PowerShell 7+ (hard exit on 5.1)
  ├─ Parse CLI args (-NoLogo, -LogLevel, -NoTimestamp)
  ├─ Loads config:
  │   - .config/config.json (app settings + download URLs)
  │   - .config/ssh.json (base, placeholder-safe)
  │   - .config/ssh.local.json (optional override, gitignored)
  ├─ Dot-source modules: logging.ps1, guard.ps1, console-guard.ps1, get-binaries.ps1
  ├─ Initialize global state: $Global:LogFile, $Global:CurrentLogLevelPriority, etc.
  ├─ Write-Log "Starting AnniProxy..."
  ├─ Acquire-Lock → .session.lock (throws if already running)
  ├─ Get-Binary cloudflared → .bin/cloudflared/
  ├─ Get-Binary brave-portable → .bin/brave-portable/
  ├─ Get-7ZipExe (for extraction, prefers system 7z.exe; falls back to portable 7zr.exe)
  ├─ If provisioning occurred (download/extract), relaunch main.ps1 in a fresh pwsh window and exit current process
  ├─ Start SSH tunnel process: ssh -N -D 127.0.0.1:<socksPort> ...
  ├─ Test-Socks (wait up to 20s for tunnel readiness on 127.0.0.1:1080)
  ├─ Start Brave process with --proxy-server=socks5://127.0.0.1:1080
  ├─ Enter process lifecycle monitor loop:
  │  ├─ Check $SshProcess.HasExited every 1s
  │  ├─ Check $BraveProcess.HasExited every 1s
  │  └─ If either exits → trigger graceful shutdown of both
  └─ finally { Release-Lock } ← cleanup locked session

Result: User has Brave browser with all traffic tunneled through SSH/Cloudflare
```

### Process Lifecycle (Critical for Stability)
- **Both processes must remain alive or coordinated shutdown triggers.**
- SSH tunnel exits → Brave killed immediately → cleanup → exit
- Brave exits (user closes) → SSH tunnel killed → cleanup → exit
- **Monitoring loop detail**: `while ($True) { if ($SshProcess.HasExited -or $BraveProcess.HasExited) { break } ; Start-Sleep -Milliseconds 1000 }`
- **No orphaned processes allowed**: `finally` block in main.ps1 ensures Release-Lock runs even on exception

### Module Dependency Graph
```
main.ps1 (entry point, coordinates all)
  ├─ logging.ps1 (Write-Log, Format-LogLine, Initialize-LogFile)
  │   └─ Writes to: .log/session/session-YYYYMMDD-HHMMSS.log
  ├─ log-retention.ps1 (Invoke-LogRetention)
  │   └─ Archives old logs into: .log/.archive/<category>/
  ├─ guard.ps1 (Acquire-Lock, Release-Lock)
  │   └─ Manages: .session.lock (ephemeral PID file)
  ├─ console-guard.ps1 (Console-CloseRequested)
  └─ get-binaries.ps1 (Get-7ZipExe, Get-Binary)
      └─ Caches to: .bin/ (cloudflared/, brave-portable/, 7zip/)

Other key modules (dot-sourced by main.ps1):

- exe-resolvers.ps1 (Resolve-CloudflaredExe, Resolve-SshExe)
- ssh-utils.ps1 (Wait-ForSocksReady, Get-FileTail, etc.)
- ssh-tunnel.ps1 (Start-SshSocksTunnel + key-auth → interactive fallback)
- ssh-provision.ps1 (Invoke-SshKeyProvision)
- healthcheck.ps1 (Invoke-HealthCheck)
- window-utils.ps1 (Minimize-ProcessWindow -Action Minimize|Hide)
```

---

## MODULE SPECIFICATIONS & PATTERNS

### 1. main.ps1 (Orchestrator, ~166 lines)

**Purpose**: Bootstrap, coordinate lifecycle, enforce constraints

**Key Global Variables** (set by main.ps1, used by all modules):
```
$Global:LogFile = ".log/session/session-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Global:CurrentLogLevelPriority = @('ERROR', 'WARN', 'INFO', 'OK')  # 0-3
$Global:SuppressTimestamp = $false
```

**Critical Configuration (config-file driven):

AnniProxy reads settings from:

- `.config/config.json`
  - `noLogo`, `logLevel`, `noTimestamp`, `offlineSSHTest`, `useScoop`
  - `7zUrl` (portable extractor download)
  - `cloudflaredUrl`, `brave7zUrl`, `pwsh7.5.4Url`
  - `openSshZipUrl` (portable OpenSSH zip used when ssh.exe is missing)
- `.config/ssh.json`
  - `user`, `host`, `socksPort`
  - `identityFile` (path to private key; should be gitignored)
  - `knownHostsFile` (path to a dedicated known_hosts; should be gitignored)

Only paths and derived values are computed in `.src/main.ps1` (e.g. `.bin/`, `.log/`, `.session.lock`).

---

## SECRETS & COMMIT HYGIENE (CRITICAL)

- `.config` is intended to be committed (commit-safe JSON only)
- Secrets must be stored in gitignored locations:
  - `.config/.secret/` (preferred)
  - `.secret/` (also supported)

Never add private keys, known_hosts, tokens, etc. into committed files.

**Important**:
- `.config/ssh.json` is committed and *must remain placeholder-safe*.
- Real SSH host/user belong in `.config/ssh.local.json` (gitignored).

**Execution Parameters (CLI args)**:
- `-NoLogo` → Skip ASCII art output
- `-LogLevel {INFO|OK|WARN|ERROR|ALL}` → Filter console messages (case-insensitive)
- `-NoTimestamp` → Remove timestamps from console logs (file logs always timestamp)
- `-ProvisionKeys` → Generate SSH keypair and known_hosts skeleton under `.config/.secret/` (no normal run)
- `-HealthCheckOnly` → Run diagnostics and exit (no normal run)

**Critical Functions**:

| Function | Input | Output | Side Effects |
|----------|-------|--------|--------------|
| `Acquire-Lock` | `$LockFilePath` | `$true` or throws | Creates `.session.lock` with current PID; throws if exists with living PID |
| `Release-Lock` | `$LockFilePath` | `$null` | Removes `.session.lock`, allows next run |
| `Test-Socks` | `$Host`, `$Port`, `$Timeout` | `$true` or `$false` | Attempts TCP connection; waits up to 20s |
| `Get-Binary` | `$Url`, `$DestPath`, `$Mode` | `$DestPath` or throws | Downloads, extracts, caches; skips if exists |

**Error Handling Pattern**:
```powershell
$ErrorActionPreference = 'Stop'  # Force terminating errors
# ... code ...
try {
    # Main logic
} catch {
    Write-Log "FATAL: $_" -Level 'ERROR'
    throw
} finally {
    Release-Lock -LockFilePath $LockFile  # ALWAYS cleanup
}
```

**Process Launching Pattern** (SSH tunnel):
```powershell
$SshProcess = Start-Process -FilePath "ssh.exe" `
  -ArgumentList "-N", "-D", "127.0.0.1:1080", `-o`, "ProxyCommand=cloudflared access ssh --hostname %h", "akira@yme-04.yumehana.dev" `
  -NoNewWindow -PassThru
```

**Process Launching Pattern** (Brave):
```powershell
$BraveProcess = Start-Process -FilePath $BraveExePath `
  -ArgumentList "--proxy-server=socks5://127.0.0.1:1080" `
  -NoNewWindow -PassThru
```

---

### 2. logging.ps1 (Logging Module)

**Purpose**: Unified logging to console (color-coded, level-filtered) and file (timestamped, always-write)

**Exports**:
- `Write-Log` (primary API)
- `Format-LogLine` (internal formatter)
- `Initialize-LogFile` (setup)

**Function Signature**:
```powershell
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO',  # INFO, OK, WARN, ERROR
        [bool]$WriteFile = $true
    )
    # 1. Check if level passes filter (CurrentLogLevelPriority)
    # 2. Format console output (color + optional timestamp)
    # 3. Write to console
    # 4. If $WriteFile, append to $Global:LogFile with full timestamp
}
```

**Level Priority** (indices in `$Global:CurrentLogLevelPriority`):
- Index 0: ERROR (red)
- Index 1: WARN (yellow)
- Index 2: INFO (cyan)
- Index 3: OK (green)
- Special: 'ALL' shows all levels

**Format Pattern**:
- Console: `[LEVEL] Message` or `[HH:MM:SS] [LEVEL] Message` (if `$SuppressTimestamp` is false)
- File: `YYYY-MM-DD HH:MM:SS [LEVEL] Message` (always includes timestamp)

**File Layout**:
```
.log/
  ├─ session/
  │  ├─ session-20260209-143022.log
  │  └─ ...
  ├─ ssh/
  │  ├─ ssh-20260209-143022.log
  │  ├─ ssh-20260209-143022.err
  │  └─ ...
  ├─ brave/
  │  ├─ brave-20260209-143022.log
  │  ├─ brave-20260209-143022.err
  │  └─ ...
  └─ .archive/
     ├─ session/
     ├─ ssh/
     ├─ brave/
     └─ legacy/
```

**Color Codes** (PowerShell ConsoleColor):
- INFO → Cyan
- OK → Green
- WARN → Yellow
- ERROR → Red

**Key Implementation Detail**: Write-Log must respect `$ErrorActionPreference = 'Stop'` in main but not throw itself; use try-catch internally for file I/O failures.

---

### 3. guard.ps1 (Session Lock Module)

**Purpose**: Prevent concurrent AnniProxy instances; manage single-instance semantics

**Exports**:
- `Acquire-Lock`
- `Release-Lock`

**Lock File Format** (`.session.lock`):
```
<Process ID>
```
Simple text file containing only the PID of the running session.

**Acquire-Lock Logic**:
```
1. If .session.lock exists:
   a. Read PID from file
   b. Try: Get-Process -Id $pid (using .NET method)
   c. If process still exists → throw "Already running"
   d. If process dead (stale lock) → delete .session.lock, continue
2. Write current PID to .session.lock (New-Item or Set-Content)
3. Return $true
4. On any failure → throw with descriptive message
```

**Release-Lock Logic**:
```
1. If .session.lock exists:
   a. Remove-Item .session.lock -Force -ErrorAction SilentlyContinue
2. Return $null
```

**Usage Pattern in main.ps1**:
```powershell
try {
    Acquire-Lock -LockFilePath $LockFile
    # ... main logic ...
} finally {
    Release-Lock -LockFilePath $LockFile
}
```

**Threading Consideration**: PowerShell is single-threaded, but manual concurrent invocations of `run.bat` can race. Lock file is authoritative; TOCTOU (time-of-check to time-of-use) mitigated by immediate write after check.

---

### 4. get-binaries.ps1 (Binary Acquisition Module)

**Purpose**: Download, extract, and cache external binaries (cloudflared, Brave, 7-Zip)

**Exports**:
- `Get-7ZipExe` (resolver/downloader for an extractor)
- `Get-Binary` (main API)

**Directory Structure**:
```
.bin/
  ├─ cloudflared/
  │   ├─ cloudflared.exe
  │   └─ cert.pem (config, if needed)
  ├─ brave-portable/
  │   ├─ Brave-browser/
  │   │   └─ brave.exe
  │   └─ (other Brave files)
  └─ 7zip/
      └─ 7zr.exe (portable fallback)
```

**Get-Binary Function Signature**:
```powershell
function Get-Binary {
    param(
        [string]$Name,
        [string]$TargetPath,
        [string]$DownloadUrl,
        [switch]$Is7zArchive,
        [string]$ExtractDir,
        [switch]$UseScoop
    )
    # 1. If TargetPath (non-archive) exists → skip
    # 2. If ExtractDir (archive) exists → skip
    # 3. Otherwise download (Invoke-WebRequest)
    # 4. If Is7zArchive → extract with Get-7ZipExe
    # 5. Set $Global:AnniProxyProvisioned=$true when download/extract occurred
}
```

**7-Zip Resolution Logic**:
```
1. Try: 7z.exe (system PATH)
2. Else if useScoop=true: try installing 7zip via Scoop and re-check for 7z.exe
3. Else: download portable extractor to .bin/7zip/7zr.exe using config.json 7zUrl
3. Else: Throw "7-Zip not available"
```

**Caching Behavior**:
- If `$DestPath/` directory exists **and** contains expected binary → skip download
- "Expected binary": cloudflared.exe, brave.exe (inside brave-portable/), etc.
- Always validate before returning; if validation fails, delete and re-download

**Download Implementation**:
- Use `[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13`
- Use `Invoke-WebRequest -Uri $Url -OutFile $tempPath` with `-ErrorAction Stop`
- On download failure → throw with URL and error detail

**Extraction Implementation** (7zip):
```powershell
$sevenZipPath = Get-7ZipExe
$sevenZipArgs = "x", "-y", "-o$ExtractDir", $TargetPath
Start-Process -FilePath $sevenZipPath -ArgumentList $sevenZipArgs -Wait -PassThru -NoNewWindow
```

---

## CONFIGURATION POINTS & EXTENSION PATTERNS

### Modifiable Configuration (Level 1: Easy)

| Item | File | Key | Purpose |
|------|------|-----|---------|
| SSH Host | `.config/ssh.local.json` | `host` | Remote server hostname (override; gitignored) |
| SSH User | `.config/ssh.local.json` | `user` | Remote login username (override; gitignored) |
| SOCKS Port | `.config/ssh.json` | `socksPort` | Local tunnel port (127.0.0.1:$SocksPort) |
| Cloudflared URL | `.config/config.json` | `cloudflaredUrl` | Download URL for cloudflared binary |
| Brave URL | `.config/config.json` | `brave7zUrl` | Download URL for Brave portable 7z |
| 7zip URL | `.config/config.json` | `7zUrl` | Download URL for portable extractor (7zr.exe) |
| PowerShell 7 zip URL | `.config/config.json` | `pwsh7.5.4Url` | Download URL used by run.bat manual bootstrap |
| Use Scoop | `.config/config.json` | `useScoop` | Enables/disables Scoop usage for installing tools |
| Log Level (runtime) | CLI arg | `-LogLevel` | Filter console output during execution |
| Log Suppression (runtime) | CLI arg | `-NoTimestamp` | Skip timestamps in console logs |

### Advanced Configuration (Level 2: Requires Code Change)

| Change | File | Location | Example |
|--------|------|----------|---------|
| Add environment variables to SSH | `.src/main.ps1` | SSH tunnel `-o` flags | Add `-e` SSH_AGENT_PID or proxy settings |
| Change log file path pattern | `.src/logging.ps1` | `Initialize-LogFile` | Replace `.log/session-` with custom prefix |
| Add custom logging formatter | `.src/logging.ps1` | `Format-LogLine` | Add caller name, stack depth, or context |
| Add startup flags to Brave | `.src/main.ps1` | `Start-Process -ArgumentList` | Append `--disable-gpu`, `--start-maximized`, etc. |
| Change lock file mechanism | `.src/guard.ps1` | `Acquire-Lock` / `Release-Lock` | Use registry or global mutex instead |

### Extension Points (Level 3: New Modules)

**Adding a new module** (example: health check):
1. Create `.src/healthcheck.ps1` with exported functions
2. Add to main.ps1 dot-source block: `. "$PSScriptRoot/healthcheck.ps1"`
3. Call functions as needed in main flow
4. Ensure module uses `$Global:` config and `Write-Log` for consistency

**Example skeleton**:
```powershell
# .src/health-check.ps1
function Test-NetworkConnectivity {
    param( [string]$Host, [int]$Timeout = 10 )
    # Implementation
    Write-Log "Network check: $result" -Level 'INFO'
}

# Then in main.ps1:
. "$PSScriptRoot/health-check.ps1"
Test-NetworkConnectivity -Host $SshHost
```

---

## CRITICAL RUNTIME BEHAVIORS & STATE MANAGEMENT

### State Lifecycle
1. **Pre-launch**: No `.session.lock`, no processes running
2. **Lock Acquired**: `.session.lock` created with current PID
3. **Binaries Ready**: `.bin/` populated with cloudflared, Brave, 7z as needed
4. **Tunnel Active**: SSH process running, listening on 127.0.0.1:1080
5. **Socks Validated**: `Test-Socks` confirms TCP connection on 127.0.0.1:1080
6. **Browser Launched**: Brave.exe running, configured with `--proxy-server=socks5://127.0.0.1:1080`
7. **Monitoring**: Main loop checking both process `HasExited` flags
8. **Shutdown Initiated**: Either process exits → both killed → cleanup
9. **Lock Released**: `.session.lock` deleted, allowing next run

### Proxy Chain (Data Flow)
```
Brave Browser (127.0.0.1 local only)
  ↓
SOCKS5 Proxy (127.0.0.1:1080, SSH tunnel endpoint)
  ↓
SSH Process (cloudflared + ssh.exe)
  ↓
Cloudflared Access (Cloudflare tunneling)
  ↓
SSH Server (yme-04.yumehana.dev)
  ↓
Public Internet (from remote server IP)
```

### Process Termination Sequence (Planned Exit)
1. User closes Brave browser
2. Brave.exe process exits (detected by `HasExited`)
3. Main loop breaks
4. SSH process killed: `$SshProcess.Kill()`
5. Write-Log cleanup message
6. finally block runs: `Release-Lock`
7. Script exits with code 0

### Process Termination Sequence (Tunnel Failure)
1. SSH process dies unexpectedly
2. Main loop detects `$SshProcess.HasExited` = true
3. Brave process killed: `$BraveProcess.Kill()`
4. Write-Log error: "SSH tunnel died"
5. finally block runs: `Release-Lock`
6. Script exits with code 1

### Network Validation (`Test-Socks`)
```powershell
function Test-Socks {
    param( [string]$Host = '127.0.0.1', [int]$Port = 1080, [int]$Timeout = 20 )
    
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $tcpClient.BeginConnect($Host, $Port, $null, $null)
    
    if ($asyncResult.AsyncWaitHandle.WaitOne([timespan]::FromSeconds($Timeout))) {
        $tcpClient.EndConnect($asyncResult)
        $tcpClient.Close()
        return $true
    } else {
        return $false
    }
}
```

---

## CONVENTIONS & CODE PATTERNS

### PowerShell Style (Mandatory)
- **Version**: PowerShell 7+ (7.0 or later, modern .NET libraries)
- **Execution Policy**: Must use `-ExecutionPolicy Bypass` to run (no signed scripts)
- **Error Handling**: `$ErrorActionPreference = 'Stop'` in main.ps1; other modules inherit
- **Encoding**: UTF-8 for all file I/O (`.log` files, `.session.lock`)
- **Line Endings**: CRLF (Windows default) for `.ps1`, LF for `.log`

### Logging Convention (Mandatory)
- **Always use `Write-Log`** for operational messages; never use `Write-Host`, `Write-Output`, or console redirection
- Exception: Debug/REPL testing only—production code uses `Write-Log`
- Example: ❌ `Write-Host "Tunnel ready"` → ✅ `Write-Log "Tunnel ready" -Level 'OK'`
- All error paths must log before throwing: `Write-Log "Error: $_" -Level 'ERROR'; throw $_`

### Module Structure (Mandatory)
- Each `.ps1` module under `.src/` implements 1-3 focused functions
- Functions must accept `$Global:` variables set by main.ps1 (LogFile, CurrentLogLevelPriority, etc.)
- No module should initialize its own globals; main.ps1 is the source of truth
- Dot-source in main.ps1 at top, after parameter definition, before try block

### Error Messages (Mandatory)
- Be specific: "Could not acquire lock; another instance running with PID 1234" (not "Lock failed")
- Include context: "SSH tunnel did not respond within 20s at 127.0.0.1:1080"
- Include recovery hint if applicable: "...try deleting .session.lock if you believe it's stale"
- Use `throw` for errors that should halt execution; use `Write-Log ERROR` for warnings

### Commenting Convention
- Section headers: `# ===== Major Section ===== #` (80 chars wide)
- Subsections: `# --- Subsection --- #` (60 chars wide)
- Inline: `# Only comment non-obvious logic; code should be self-explanatory`
- Avoid: `# increment counter` (obvious from `$counter += 1`)

### Atomic Operations
- **Lock file creation**: Use `-Force` and check existence atomically; race condition acceptable (will fail on next invocation)
- **PID check**: Use `[System.Diagnostics.Process]::GetProcessById($pid)` with try-catch, not `Get-Process` (more reliable)
- **File writes**: Use `Set-Content` with `-Encoding UTF8` consistently

---

## INTEGRATION POINTS & EXTERNAL DEPENDENCIES

### Binary Dependencies

| Component | Source | Type | Purpose |
|-----------|--------|------|---------|
| **cloudflared** | cloudflare/cloudflared releases | Static release | Cloudflare tunnel authentication, initiates SSH tunnel via`cloudflared access ssh` |
| **ssh.exe** | Windows built-in / Git for Windows / Scoop | System PATH | Creates SOCKS5 tunnel with `-D`, `-N` flags |
| **7z.exe** / **7zr.exe** | System PATH / bundled in `.bin/7zip/` | Archive tool | Extracts Brave portable archive |
| **Brave Portable** | portapps/brave-portable releases | Bundled binary | Browser with SOCKS proxy configuration |
| **PowerShell 7** | Microsoft zip / system install / Scoop | Runtime | Executes `.src/main.ps1` |

### External Services

| Service | Protocol | Usage | Credential |
|---------|----------|-------|-----------|
| **Cloudflare Tunnel** | HTTPS (TLS) | Authentication for SSH access | Implicit via `cloudflared access ssh` browser-based auth |
| **SSH Server** | SSH v2 | Remote tunnel endpoint | Username `akira`, key-based or password (handled by cloudflared) |
| **GitHub (Releases)** | HTTPS | Binary downloads (cloudflared, Brave) | Unauthenticated (public releases) |

### Network Constraints

- **Localhost only**: SOCKS proxy bound to 127.0.0.1:1080 (no remote connections)
- **No authentication on SOCKS**: Proxy is local-machine-only, no credentials needed
- **SSH + Cloudflared**: SSH tunnel wrapped in Cloudflare authentication (authentication happens at Cloudflare endpoint)
- **Port**: Defined in `.config/ssh.json` `socksPort` (Brave config must match)

---

## COMMON MODIFICATION TEMPLATES

### Template 1: Update Binary Versions
```powershell
# In .config/config.json, update these URLs:
# - cloudflaredUrl
# - brave7zUrl
# - 7zUrl (portable extractor)

# Delete .bin/cloudflared/ and .bin/brave-portable/ directories to force re-download on next run
Remove-Item .bin/cloudflared -Recurse -Force
Remove-Item .bin/brave-portable -Recurse -Force
```

### Template 2: Add SSH Configuration Option
```powershell
# In .src/main.ps1, modify SSH command:
# Before:
$sshArgs = "-N", "-D", "127.0.0.1:$SocksPort", "-o", "ProxyCommand=cloudflared access ssh --hostname %h", "$SshUser@$SshHost"

# After (add StrictHostKeyChecking=no):
$sshArgs = "-N", "-D", "127.0.0.1:$SocksPort", "-o", "ProxyCommand=cloudflared access ssh --hostname %h", "-o", "StrictHostKeyChecking=no", "$SshUser@$SshHost"
```

### Template 3: Customize Brave Startup
```powershell
# In .src/main.ps1, modify Brave Start-Process call:
# Before:
$BraveProcess = Start-Process -FilePath $BraveExePath `
  -ArgumentList "--proxy-server=socks5://127.0.0.1:1080" `
  -NoNewWindow -PassThru

# After (add more flags):
$BraveProcess = Start-Process -FilePath $BraveExePath `
  -ArgumentList "--proxy-server=socks5://127.0.0.1:1080", "--start-maximized", "--disable-extensions" `
  -NoNewWindow -PassThru
```

### Template 4: Add Startup Health Check
```powershell
# Create .src/health-check.ps1:
function Invoke-HealthCheck {
    Write-Log "Running health checks..." -Level 'INFO'
    
    # Check 1: SSH binary available
    $ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
    if (-not $ssh) { throw "ssh.exe not found in PATH" }
    Write-Log "✓ ssh.exe available at $($ssh.Source)" -Level 'OK'
    
    # Check 2: Cloudflared available
    $cf = Get-Command cloudflared -ErrorAction SilentlyContinue
    if (-not $cf) { throw "cloudflared not found; will attempt download" }
    Write-Log "✓ cloudflared available at $($cf.Source)" -Level 'OK'
}

# In main.ps1, after Acquire-Lock:
Invoke-HealthCheck
```

---

## TROUBLESHOOTING & DIAGNOSIS

### Symptom: "Already running" Error
**Cause**: `.session.lock` exists with running PID
**Diagnosis**:
```powershell
Get-Content .session.lock  # Shows PID
Get-Process -Id <PID>  # Check if that PID exists
```
**Resolution**:
- If process is legitimately running: close Brave/SSH tunnel first, wait 5s, retry
- If process is zombie: delete `.session.lock` manually and retry
```powershell
Remove-Item .session.lock -Force
```

### Symptom: "SOCKS Tunnel Not Responding" (Test-Socks timeout)
**Cause**: SSH tunnel failed to start or authenticate
**Diagnosis**:
```powershell
Get-Process ssh*  # Check for ssh.exe process
Get-Content .log/session-*.log | Select-String "cloudflared\|SSH\|tunnel"  # Review logs
```
**Resolution**:
- Check Cloudflare authentication (may need browser-based reauth)
- Verify SSH host is reachable: `Test-NetConnection -ComputerName yme-04.yumehana.dev -Port 22`
- Check `.bin/cloudflared/cloudflared.exe` exists: `Test-Path .bin/cloudflared/cloudflared.exe`

### Symptom: Brave Launch Fails / Proxy Not Applied
**Cause**: Brave executable not found or version mismatch
**Diagnosis**:
```powershell
Get-ChildItem .bin/brave-portable/ -Recurse | Where-Object Name -eq "brave.exe"
```
**Resolution**:
- Delete and re-extract: `Remove-Item .bin/brave-portable -Recurse -Force`
- Re-run `run.bat`

### Symptom: Binary Download Fails (Invoke-WebRequest error)
**Cause**: Network issue, GitHub rate limiting, or invalid URL
**Diagnosis**:
```powershell
$url = "https://github.com/cloudflare/cloudflared/releases/download/2026.2.0/cloudflared-windows-amd64.exe"
Invoke-WebRequest -Uri $url -Method Head -Verbose  # Test connectivity
```
**Resolution**:
- Verify URL is correct and GitHub release exists
- Check internet connectivity: `Test-NetConnection 8.8.8.8 -Port 53`
- If behind proxy, configure: [System.Net.ServicePointManager]::DefaultProxy = ...

### Symptom: Log File Not Writing
**Cause**: Permission denied on `.log/` directory or disk full
**Diagnosis**:
```powershell
Test-Path .log/ -PathType Container
(Get-Item .log/).GetAccessControl()  # Check NTFS permissions
Get-Volume  # Check free space
```
**Resolution**:
- Ensure `.log/` directory exists: `New-Item -ItemType Directory -Path .log -Force`
- Check write permissions on parent directory
- Clear old logs if disk is full: `Remove-Item .log/session-*.log -Older than 30 days`

---

## EXAMPLE WORKFLOWS

### Workflow 1: Normal User Session
```
1. User double-clicks run.bat
2. PowerShell 7 located and started
3. .src/main.ps1 invoked with default args
4. Acquire-Lock succeeds
5. cloudflared (.bin/cloudflared/) and brave-portable (.bin/brave-portable/) verified/downloaded
6. SSH tunnel spawned, listening on 127.0.0.1:1080
7. Test-Socks validates tunnel (1-3s typically)
8. Brave browser launched with --proxy-server=socks5://127.0.0.1:1080
9. User browses; all traffic routed through tunnel
10. User closes Brave
11. SSH process killed, lock released → script exits
12. Exit code 0
```

### Workflow 2: Installer Build & Distribution
```
1. Developer opens .src/installer_builder.iss in Inno Setup compiler
2. Compiler reads AppVersion, bundles .src/, .bin/, .assets/ into EXE
3. Output: .release/AnniProxy_Setup_v1.0.0.exe
4. User runs installer
5. Installs to %LOCALAPPDATA%\Yumehana\AnniProxy
6. User can now run from Start Menu shortcut
7. Shortcut calls run.bat in installation directory
```

### Workflow 3: Module Testing (REPL)
```powershell
# Developer wants to test logging module in isolation
pwsh -File .src/logging.ps1

# In REPL:
$Global:LogFile = ".log/test-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Global:CurrentLogLevelPriority = @('ERROR', 'WARN', 'INFO', 'OK')
$Global:SuppressTimestamp = $false

. .src/logging.ps1
Initialize-LogFile -LogFilePath $Global:LogFile
Write-Log "Test message 1" -Level 'INFO'
Write-Log "Test message 2" -Level 'ERROR'

Get-Content $Global:LogFile  # Verify file was written
```

### Workflow 4: Update SSH Host
```powershell
# Change SSH target in .config/ssh.json and re-run run.bat
```

---

## DEFAULT FILES & DIRECTORIES

```
AnniProxy/
  ├─ run.bat (entry point)
  ├─ test.ps1 (optional testing script)
  ├─ README.md (user documentation)
  ├─ LICENSE.txt
  ├─ .src/
  │   ├─ main.ps1 (orchestrator)
  │   ├─ logging.ps1 (logging module)
  │   ├─ log-retention.ps1 (archive old logs)
  │   ├─ guard.ps1 (lock/session module)
  │   ├─ get-binaries.ps1 (binary acquisition)
  │   ├─ exe-resolvers.ps1 (resolve ssh/cloudflared locations)
  │   ├─ ssh-utils.ps1 (tunnel readiness helpers)
  │   ├─ ssh-tunnel.ps1 (start SSH + fallback auth)
  │   ├─ window-utils.ps1 (hide/minimize SSH auth console)
  │   └─ installer_builder.iss (Inno Setup definition)
  ├─ .assets/
  │   ├─ LogoASCII.ps1 (ASCII art)
  │   ├─ icon.ico
  │   └─ icon.png
  ├─ .bin/ (runtime-generated)
  │   ├─ cloudflared/ (downloaded & extracted)
  │   ├─ brave-portable/ (downloaded & extracted)
  │   └─ 7zip/ (bundled 7zr.exe, if needed)
  ├─ .log/ (runtime-generated)
  │   ├─ session/ (AnniProxy logs)
  │   ├─ ssh/ (ssh stdout/stderr)
  │   ├─ brave/ (brave stdout/stderr)
  │   └─ .archive/ (archived logs, never deleted)
  ├─ .session.lock (ephemeral, exists only during run)
  └─ .release/ (optional, build output)
      └─ AnniProxy_Setup_v1.0.0.exe
```

---

## IMPLEMENTATION CHECKLIST FOR AI AGENTS

Before modifying code:

- [ ] Read `.src/main.ps1` entirely to understand orchestration flow
- [ ] Identify which module(s) need change: main, logging, guard, get-binaries
- [ ] Check `$Global:` variable dependencies that your change affects
- [ ] Identify error conditions and update error logging
- [ ] Preserve `$ErrorActionPreference = 'Stop'` and `try-finally` semantics
- [ ] Never replace `Write-Log` with `Write-Host` or direct output
- [ ] Update comments if logic changes
- [ ] If adding a new module, ensure it dot-sources in main.ps1 and uses global logging
- [ ] Test via `run.bat` or `pwsh -File .src/main.ps1` to verify no regressions

## AI INVARIANTS (DO NOT BREAK THESE)

If you are an AI modifying this repository, treat these as hard requirements:

1. **PowerShell 7+ only**
   - Keep the version guard in `main.ps1`.

2. **Single instance enforcement must remain**
   - The `.session.lock` mechanism (Acquire/Release) must remain authoritative.

3. **Lifecycle coupling must remain**
   - If SSH exits, the session must shut down.
   - If Brave exits, the session must shut down.
   - Always clean up in `finally`.

4. **Secrets must never be committed**
   - `identityFile` and `knownHostsFile` must point into gitignored paths.
   - Keep `.config/ssh.json` placeholder-safe unless explicitly instructed.

5. **Window hiding must never hide the main AnniProxy console**
   - Never hide `wt.exe`/`WindowsTerminal.exe` as part of the Hide action.
   - Prefer process-tree targeting + `EnumWindows` for console host windows.

6. **Logging must remain structured**
   - Session logs must go into `.log/session/`.
   - Retention must archive into `.log/.archive/` (never delete).

For binary/dependency changes:

- [ ] Update URL in `.src/main.ps1` (e.g., `$CloudflaredUrl`, `$Brave7zUrl`)
- [ ] Verify URL points to stable, public GitHub release (not pre-release)
- [ ] Test download path manually: `Invoke-WebRequest -Uri <URL> -OutFile test.exe`
- [ ] If extraction mode changes, adjust `Get-Binary -Mode` parameter

For installer/packaging changes:

- [ ] Edit `.src/installer_builder.iss` in Inno Setup
- [ ] Update version number, file includes, output paths
- [ ] Rebuild and test installer (.exe) on clean Windows machine if possible

---

## FOLLOW-UPS / KNOWN TODOs

These are intentionally listed so a future AI can pick up work without prior chat context:

1. **Reduce `LogLevel=ALL` noise**
   - Some window-hide and SSH-start logs are currently written at `ALL` for debugging.
   - Once stable, consider demoting to `INFO` (or gating behind a dedicated debug flag) while keeping WARN/ERROR signals.

2. **Installer file list audit**
   - The refactor added new `.src/*.ps1` modules.
   - Ensure `installer_builder.iss` includes all required runtime files (`.src/*.ps1`, `.assets`, `run.bat`, `.config/*.json`).

3. **`ShowExitPrompt` semantics**
   - Confirm the intended UX:
     - when to show “Press any key to exit…”
     - how to behave after provisioning-triggered restart
   - Keep shutdown behavior deterministic.

4. **Windows Terminal edge cases**
   - `Hide` intentionally avoids hiding `wt.exe`/`WindowsTerminal.exe` for safety.
   - If future requirements demand hiding a WT tab only, it likely requires a different strategy (WT APIs), not Win32 window hiding.

5. **Config placeholder safety**
   - Keep `.config/ssh.json` placeholder-safe by default.
   - If a deployment requires real values, document that as a separate private config step.

**Last Updated**: February 2026 | **Target PowerShell**: 7.x+ | **Architecture**: Modular Orchestrator | **AI Optimization**: Comprehensive, structured for machine parsing and intent-driven modifications
