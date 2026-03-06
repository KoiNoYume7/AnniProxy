# AnniProxy — AI Project Overview / Handoff

## 0. What this file is
This is the **single-source “AI handoff” overview** for the AnniProxy repository.

Goals:
- Explain **what the project does** and **why**.
- Provide an accurate **repo map** (what lives where).
- Document **runtime flow**, **process lifecycle coupling**, and **security constraints**.
- Document the **configuration model** and where secrets belong.
- Provide **extension points** (where to modify behavior safely).
- Provide **build/installer notes** and troubleshooting guidance.

This document is derived from the repo’s authoritative sources:
- `README.md`
- `run.bat`
- `.config/config.json`, `.config/ssh.json`
- `.src/main.ps1` and modules in `.src/*.ps1`
- `.dev/instructions.md`, `.dev/project-style.md`, `.dev/TODO.md`


## 1. Project summary
**AnniProxy** is a Windows PowerShell 7+ application that launches a **portable Brave browser** configured to proxy all traffic through a **local SOCKS5 proxy** created by `ssh.exe`.

The SSH connection can be authenticated and transported via **Cloudflare Access / Zero Trust** using:

- `cloudflared access ssh --hostname %h`

### 1.1 What the user experiences
- User runs `run.bat`.
- AnniProxy ensures required tooling exists (PowerShell 7+, OpenSSH, cloudflared, Brave portable, 7zip extractor).
- AnniProxy starts an SSH SOCKS5 tunnel on `127.0.0.1:<socksPort>`.
- AnniProxy launches Brave portable with:
  - `--proxy-server=socks5://127.0.0.1:<socksPort>`
- While the session is active, AnniProxy monitors both processes.
- If either SSH or Brave exits, AnniProxy shuts down the other one and cleans up.

### 1.2 Non-goals
- This project is **not** intended to provide a shared multi-user proxy.
- It is **not** designed to expose the SOCKS proxy beyond localhost.


## 2. Repository layout (high-signal)
Repo root:
- `run.bat`
- `README.md`
- `LICENSE.txt`
- `AnniProxy.code-workspace`

Tracked (commit-safe) folders:
- `.src/`
  - PowerShell source (entrypoint `main.ps1` + small modules)
  - Inno Setup scripts (`installer_builder.iss`, `installer_builder_full.iss`)
- `.config/`
  - Commit-safe config templates (`config.json`, `ssh.json`)
  - **No real secrets** should live here except placeholder paths
- `.assets/`
  - Icons / ASCII art scripts
- `.dev/`
  - Developer docs and AI instructions
  - `.dev/.ai/` is intended for AI-facing meta docs like this file

Runtime-generated (gitignored) folders (created/filled by the app):
- `.bin/`
  - Downloaded or extracted third-party binaries
- `.tmp/`
  - Generated bootstrap wrapper scripts (e.g. `.tmp/bootstrap.ps1`)
- `.log/`
  - Session logs + per-process stdout/stderr capture + archive

Other runtime artifacts:
- `.session.lock`
  - PID lock file for single-instance enforcement


## 3. Key invariants (do not break)
These are assumptions baked into the code and operational model.

- **PowerShell 7+ only**
  - `main.ps1` hard-exits if `$PSVersionTable.PSVersion.Major -lt 7`.
- **SOCKS must bind to `127.0.0.1`**
  - `ssh-tunnel.ps1` uses `-D 127.0.0.1:<port>`.
  - This is a core security property (no LAN exposure).
- **Single instance semantics**
  - `.session.lock` is used to prevent concurrent sessions.
- **Lifecycle coupling**
  - If **SSH exits**, Brave is shut down.
  - If **Brave exits**, SSH is shut down.
  - Prevents orphaned tunnels and confusing partial states.
- **Secrets must never be committed**
  - SSH private keys, known_hosts, tokens, etc. must be in ignored paths.


## 4. Primary entrypoints and execution flow

### 4.1 User entrypoint: `run.bat`
Responsibilities:
- Prepare `.log/bootstrap.log` and `.tmp/bootstrap.ps1` wrapper.
- Locate PowerShell 7 in this order:
  1. Bundled: `.bin\pwsh7+\pwsh.exe`
  2. System PATH: `pwsh`
  3. If enabled: install via Scoop (`useScoop=true` in `.config/config.json`)
  4. If configured: download PowerShell zip via `pwsh7.5.4Url` and unpack into `.bin\pwsh7+`
- Launches PowerShell with:
  - `-NoProfile -ExecutionPolicy Bypass -File .tmp\bootstrap.ps1`

Wrapper behavior:
- Sets `$ErrorActionPreference = 'Stop'`
- Starts `Start-Transcript` to `.log\bootstrap.log` (append)
- Executes `.src\main.ps1`
- If failure, prints a message and pauses so the console doesn’t close.


### 4.2 PowerShell entrypoint: `.src/main.ps1`
Responsibilities:
- Load config.
- Initialize logging.
- Ensure required binaries exist.
- Start SSH tunnel (or simulate it in offline mode).
- Launch Brave.
- Monitor and coordinate shutdown.

High-level flow (code-accurate):
1. Enforce PowerShell 7+
2. Compute paths: `BaseDir`, `LogDir`, `BinDir`, `.session.lock`, etc.
3. Read `.config/config.json`
4. Apply CLI overrides (`param(...)`) to config values
5. Read `.config/ssh.json`
6. Create log directories:
   - `.log/session`
   - `.log/ssh`
   - `.log/brave`
7. Initialize globals:
   - `$Global:LogFile` -> `.log/session/session-<timestamp>.log`
   - `$Global:CurrentLogLevelPriority` -> numeric threshold derived from config/CLI
   - `$Global:SuppressTimestamp`
   - `$Global:AnniProxyProvisioned` (tracks whether downloads/extracts happened)
8. Dot-source modules:
   - `logging.ps1`, `log-retention.ps1`, `guard.ps1`, `console-guard.ps1`, `get-binaries.ps1`, `exe-resolvers.ps1`, `ssh-utils.ps1`, `ssh-tunnel.ps1`, `window-utils.ps1`
9. `Invoke-LogRetention` at startup (archives older logs, keeps most recent N)
10. Startup cleanup (`Cleanup-Session`) before acquiring lock
11. Acquire lock (`Acquire-Lock`)
12. Resolve `ssh.exe` (`Resolve-SshExe`)
13. Validate `ssh.json` not placeholder
14. Ensure Brave portable exists:
    - `Get-Binary -Is7zArchive` downloads archive and extracts
    - then deletes the `.7z` archive to save space
15. If `offlineSSHTest` enabled:
    - simulate `$SshProcess` object
    - skip real tunnel
16. Else:
    - resolve `cloudflared.exe` via Scoop/system/bundled (`Resolve-CloudflaredExe`)
    - download if missing (`Get-Binary`)
    - start tunnel via `Start-SshSocksTunnel`
17. If any provisioning occurred and not yet restarted:
    - relaunches itself in a fresh `pwsh` window
18. Post-start: attempt to hide SSH auth window safely (best-effort)
19. Launch Brave with SOCKS proxy arg and stdout/stderr redirects
20. Monitoring loop:
    - breaks when SSH exits, Brave exits, console close event, or stop requested
21. `finally`:
    - `Invoke-GracefulShutdown` (kills Brave + kills SSH)
    - `Release-Lock`


## 5. Configuration model

### 5.1 `.config/config.json` (commit-safe)
This file is intended to be tracked and safe to commit.

Current keys (as in repo):
- `noLogo` (bool)
- `logLevel` (`INFO|OK|WARN|ERROR|ALL`)
- `noTimestamp` (bool)
- `offlineSSHTest` (bool)
- `useScoop` (bool)
- `7zUrl` (string URL; portable `7zr.exe`)
- `cloudflaredUrl` (string URL)
- `brave7zUrl` (string URL)
- `pwsh7.5.4Url` (string URL; used by `run.bat` manual bootstrap)
- `openSshZipUrl` (string URL; used if OpenSSH client is missing)

### 5.2 `.config/ssh.json` (commit-safe placeholder)
Also tracked, but should remain placeholder-safe.

Keys:
- `user` (string)
- `host` (string)
- `socksPort` (int)
- `identityFile` (string path, usually `.config/.secret/id_ed25519`)
- `knownHostsFile` (string path, usually `.config/.secret/known_hosts`)

`main.ps1` validates `user` and `host` and rejects placeholders like `example.com` / `your-ssh`.


## 6. Secrets: where they belong
Do not commit:
- Private keys (`id_ed25519`)
- Real `known_hosts`
- Any tokens

Preferred secret location:
- `.config/.secret/` (gitignored)

Supported alternative:
- `.secret/` (also gitignored)

The committed `.config/ssh.json` references secret files by relative path; those files should exist only locally.


## 7. Logging model
There are *two* logging concepts:

### 7.1 Bootstrap transcript
- `run.bat` generates `.tmp/bootstrap.ps1` which runs `Start-Transcript` to:
  - `.log/bootstrap.log`
- This catches early startup failures.

### 7.2 Session and process logs
Created by `main.ps1`:
- Session log:
  - `.log/session/session-<timestamp>.log`
- SSH stdout/stderr:
  - `.log/ssh/ssh-<timestamp>.log`
  - `.log/ssh/ssh-<timestamp>.err`
- Brave stdout/stderr:
  - `.log/brave/brave-<timestamp>.log`
  - `.log/brave/brave-<timestamp>.err`

### 7.3 Log retention / archiving
`Invoke-LogRetention` (`.src/log-retention.ps1`):
- Keeps newest `MaxFiles` per category directory (`session|ssh|brave`)
- Moves older logs into:
  - `.log/.archive/<category>/`
- Also archives any legacy root-level `.log/*` files into:
  - `.log/.archive/legacy/`


## 8. Process model and lifecycle coupling
AnniProxy manages (at least) these processes:
- `ssh.exe` (SOCKS tunnel)
- `cloudflared.exe` (used via ProxyCommand; invoked by ssh)
- `brave-portable.exe` (portable Brave launcher)
- `conhost.exe` / `OpenConsole.exe` / potentially `wt.exe` (console hosts)

Lifecycle coupling in `main.ps1`:
- Monitoring loop checks:
  - `$SshProcess.HasExited`
  - `$BraveProcess.HasExited`
  - `Console-CloseRequested` (from `console-guard.ps1`)
- On exit condition:
  - Calls `Invoke-GracefulShutdown` (kills Brave first, then SSH)

Important cleanup behavior:
- `Cleanup-Session` runs before lock acquisition.
  - If stale lock exists or Brave processes still exist, it prompts to kill them.
  - It also removes `.session.lock`.
  - It cleans `.bin/cloudflared` and `.bin/brave-portable` if an unclean shutdown was detected.


## 9. Modules (authoritative responsibilities)

### 9.1 `.src/logging.ps1`
Exports:
- `Write-Log` (primary logging API)
- `Message` (cyan console output; not used for structured logging)
- `Register-GlobalErrorLogging` (trap-based handler)

Implementation notes:
- Uses `$Global:CurrentLogLevelPriority` numeric threshold.
- Writes to console (colors by level) and appends to `$Global:LogFile`.

### 9.2 `.src/guard.ps1`
Exports:
- `Acquire-Lock` / `Release-Lock`
- `Cleanup-Session`
- `Kill-BraveProcesses`
- `Test-SocksPort`

Notes:
- Locking is file-based (`.session.lock`) containing the owning PID.
- Cleanup uses `Win32_Process` (CIM/WMI) filtering by `ExecutablePath` within `BraveDir`.

### 9.3 `.src/get-binaries.ps1`
Exports:
- `Get-7ZipExe`
- `Get-Binary`

Notes:
- `Get-7ZipExe` attempts:
  1. system `7z.exe`
  2. optional Scoop install (if enabled in config)
  3. download portable `7zr.exe` to `.bin/7zip/7zr.exe`
- `Get-Binary` supports:
  - direct download of an `.exe`
  - download + extraction of a `.7z` archive
- Sets `$Global:AnniProxyProvisioned = $true` when it had to download/extract.

### 9.4 `.src/exe-resolvers.ps1`
Exports:
- `Resolve-SshExe`
- `Resolve-CloudflaredExe`

Notes:
- `Resolve-SshExe` attempts:
  1. `Get-Command ssh.exe`
  2. `%WINDIR%\System32\OpenSSH\ssh.exe`
  3. optional Scoop install `openssh`
  4. download zip from `openSshZipUrl` and extract to `.bin/openssh/.../ssh.exe`

### 9.5 `.src/ssh-utils.ps1`
Exports:
- `Get-FileTail`
- `Wait-ForSocksReady`

Notes:
- `Wait-ForSocksReady` loops up to `MaxSeconds`:
  - fails if process exits
  - returns true if `Test-SocksPort` can connect to `127.0.0.1:<port>`

### 9.6 `.src/ssh-tunnel.ps1`
Exports:
- `Start-SshSocksTunnel`

Notes:
- Establishes `ProxyCommand` to route SSH through Cloudflare Access:
  - `cloudflared access ssh --hostname %h`
- Key auth path:
  - Uses `-i <key>`
  - Uses `BatchMode=yes` to fail fast
  - Uses `StrictHostKeyChecking=accept-new`
  - Optionally uses `UserKnownHostsFile=<path>`
- On key auth failure, falls back to interactive auth.
- Captures stdout/stderr for key auth mode.

### 9.7 `.src/window-utils.ps1`
Exports:
- `Minimize-ProcessWindow`

Notes:
- Uses Win32 APIs via `Add-Type`:
  - `ShowWindowAsync`
  - `EnumWindows` + `GetWindowThreadProcessId`
- Attempts (in order):
  1. process main window handle
  2. EnumWindows for top-level windows of process PID
  3. child `conhost.exe`
  4. descendant console-host processes (process tree)
  5. time-window heuristics for console host windows

Safety behavior:
- When action is `Hide`, it intentionally avoids hiding `wt.exe` / `WindowsTerminal.exe` to reduce risk of hiding the main terminal.

### 9.8 `.src/console-guard.ps1`
Exports:
- `Console-CloseRequested`

Notes:
- Registers a console control handler for `CTRL_CLOSE_EVENT`.
- Provides a boolean to allow the main loop to exit gracefully.

### 9.9 `.src/log-retention.ps1`
Exports:
- `Invoke-LogRetention`

Notes:
- Archives (moves) older logs; never deletes.


## 10. Proxy chain / data flow
Conceptual flow:

1. Brave uses local SOCKS5 proxy:
   - `socks5://127.0.0.1:<socksPort>`
2. `ssh.exe` provides SOCKS5 endpoint via dynamic forwarding:
   - `ssh -N -D 127.0.0.1:<socksPort> ...`
3. `ssh.exe` uses `ProxyCommand` to invoke Cloudflare Access:
   - `cloudflared access ssh --hostname %h`
4. SSH reaches your server, then browsed traffic egresses from that server.


## 11. How to run (developer/operator)

### 11.1 Minimal steps
1. Ensure `.config/ssh.json` has real values for `user` and `host`.
2. Ensure key + known_hosts exist at the configured locations.
3. Run `run.bat`.

### 11.2 Generate an SSH key (example)
```powershell
mkdir .config/.secret -Force
ssh-keygen -t ed25519 -f .config/.secret/id_ed25519 -N ""
```

### 11.3 Populate known_hosts (recommended)
Use `ssh-keyscan` from a trusted environment or a first interactive run to populate the file.


## 12. Installer (Inno Setup)
`installer_builder.iss`:
- Installs to: `{localappdata}\Yumehana\AnniProxy`
- Bundles:
  - `run.bat`
  - `.src/*`
  - `.config/*` (excluding `.config/.secret/*`)
  - `.assets/*`
  - `README.md`, `LICENSE.txt`
- Creates Start Menu shortcut pointing to `run.bat`.

Output:
- `.release/AnniProxy_Setup_v<version>.exe`


## 13. Common change points (safe extension strategy)

### 13.1 Add Brave flags
Where:
- `.src/main.ps1` in `Start-Process $Brave -ArgumentList ...`

Guidance:
- Keep `--proxy-server=socks5://127.0.0.1:$SocksPort`.
- Add additional flags as extra list items/strings.

### 13.2 Modify SSH arguments / behavior
Where:
- `.src/ssh-tunnel.ps1` (authoritative)

Guidance:
- Keep `-D 127.0.0.1:<port>`
- Prefer key auth first; keep `BatchMode=yes` in key-auth path.

### 13.3 Add a new capability
Pattern:
1. Add a new module under `.src/<capability>.ps1`.
2. Dot-source it in `main.ps1` near the other module imports.
3. Pass config values into the module via parameters.

### 13.4 Change binary acquisition
Where:
- `.src/get-binaries.ps1`

Guidance:
- Respect caching behavior.
- Keep `$Global:AnniProxyProvisioned` semantics so restart behavior remains correct.


## 14. Troubleshooting checklist

### 14.1 `run.bat` fails early
- Check `.log/bootstrap.log`.
- Verify PowerShell 7 exists or that `pwsh7.5.4Url` is reachable.

### 14.2 “Invalid .config/ssh.json ... placeholder”
- Set real `user` and `host`.

### 14.3 SOCKS not ready / SSH exits quickly
- Check `.log/ssh/ssh-<timestamp>.err`.
- If key auth fails, interactive fallback may open a window for password/confirmation.

### 14.4 Brave launches but traffic isn’t proxied
- Verify SOCKS port matches between:
  - `.config/ssh.json` `socksPort`
  - Brave arg: `--proxy-server=socks5://127.0.0.1:<socksPort>`

### 14.5 “Already running” / session lock
- The lock file is `.session.lock`.
- If you are sure no instance is running, delete it and retry.


## 15. AI-specific guidance for future modifications
When an AI agent is asked to change behavior, it should:
- Read `run.bat` and `.src/main.ps1` first.
- Treat `.src/ssh-tunnel.ps1` as authoritative for SSH argument changes.
- Preserve the invariants in section **3**.
- Avoid adding new secret material into tracked files.
- Prefer adding logic to new `.src/*.ps1` modules rather than bloating `main.ps1`.


## 16. Quick repo map (complete at time of writing)
```
AnniProxy/
  run.bat
  README.md
  LICENSE.txt
  AnniProxy.code-workspace

  .assets/

  .config/
    config.json
    ssh.json

  .dev/
    instructions.md
    project-style.md
    TODO.md
    .ai/
      AI_PROJECT_OVERVIEW.md

  .src/
    main.ps1
    logging.ps1
    log-retention.ps1
    guard.ps1
    console-guard.ps1
    get-binaries.ps1
    exe-resolvers.ps1
    ssh-utils.ps1
    ssh-tunnel.ps1
    window-utils.ps1
    ssh-tunnel.ps1
    ssh-utils.ps1
    installer_builder.iss
    installer_builder_full.iss
    (plus helper scripts: logging.ps1, ssh-utils.ps1, etc.)

  (runtime-generated)
  .bin/
  .tmp/
  .log/
  .session.lock
```
