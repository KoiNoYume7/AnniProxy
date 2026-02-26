# --- TODO.md --- #

# AnniProxy AI-Enhanced TODO

This document is intended for an AI agent to understand and assist with the development, maintenance, and enhancement of AnniProxy. It is written in detail to encode knowledge of all modules, runtime behaviors, invariants, and configuration requirements.

# --- Project Overview --- #

* **Name**: AnniProxy
* **Purpose**: Secure Windows proxy-browser with SSH SOCKS5 tunneling (optionally using Cloudflare Access / Zero Trust as part of the SSH flow).
* **Execution Environment**: PowerShell 7+ only, Windows OS.
* **Entry Point**: `run.bat` (generates `.tmp/bootstrap.ps1` to orchestrate main.ps1)
* **Core Modules**: `main.ps1`, `logging.ps1`, `guard.ps1`, `get-binaries.ps1`, `ssh-tunnel.ps1`, `window-utils.ps1`, `log-retention.ps1`
* **Config Files**: `.config/config.json`, `.config/ssh.json` (commit-safe placeholders)
* **Secrets**: `.config/.secret/` (identity key, known_hosts), `.secret/`
* **License**: Apache 2.0

# --- AI Task Categories --- #

## 1. Setup & Bootstrap

* Ensure PowerShell 7+ detection and bootstrapping is correct.
* Verify single-instance lock mechanism (`.session.lock`) works reliably.
* Confirm download/extraction of binaries (`cloudflared`, `brave-portable`, `7zr.exe`) is robust and cache-aware.
* Monitor `$Global:AnniProxyProvisioned` state to detect new provisioning events.

## 2. SSH Tunnel Management

* Maintain SOCKS tunnel on `127.0.0.1:<socksPort>`.
* Prioritize key-based auth; fallback to interactive if necessary.
* Ensure `Start-SshSocksTunnel` enforces:

  * BatchMode=yes
  * Port forwarding correctness
  * SSH process stdout/stderr captured in `.log/ssh/`
* Implement readiness detection via `Wait-ForSocksReady`.
* Maintain lifecycle coupling: if SSH exits, terminate Brave, release lock.

## 3. Browser Launch & Monitoring

* Launch Brave Portable with `--proxy-server=socks5://127.0.0.1:<socksPort>`.
* Monitor Brave process: on exit, kill SSH tunnel, cleanup, release lock.
* Apply additional flags if needed (`--start-maximized`, `--disable-extensions`).
* Ensure no orphaned processes.

## 4. Logging

* Unified logging via `Write-Log`:

  * Session logs: `.log/session/`
  * SSH logs: `.log/ssh/`
  * Brave logs: `.log/brave/`
* Implement retention: keep newest N files, archive older files to `.log/.archive/<category>/`
* Always log errors before throwing.
* Maintain color-coded console output.
* Ensure file logs UTF-8 encoded.

## 5. Window Handling

* Use `Minimize-ProcessWindow -Action Hide` carefully.
* Hide SSH auth windows without affecting main AnniProxy console or `wt.exe`.
* Walk process tree + EnumWindows API for reliability.

## 6. Configuration & Secrets

* `.config/config.json` contains URLs, installation options, Scoop usage.
* `.config/ssh.json` contains SSH connection info; must remain placeholder-safe.
* Secret files (`identityFile`, `knownHostsFile`) must never be committed.
* Validate presence of all required binaries before launching.

## 7. Error Handling & Safety

* `$ErrorActionPreference = 'Stop'` enforced in main.ps1.
* Use try-catch-finally blocks to ensure cleanup.
* Provide detailed, actionable log messages.
* Never break AI invariants: single-instance enforcement, lifecycle coupling, secrets safety, window hiding, structured logging.

## 8. Installer & Distribution

* `.src/installer_builder.iss` must include all runtime scripts, assets, configs.
* Optionally bundle `.bin/` files for offline installation.
* Verify version number, output paths.
* Test installer on clean Windows machine.

## 9. AI Invariants & Hard Constraints

* **PowerShell 7+ only**
* **Single instance lock enforcement**
* **Coupled lifecycle: SSH and Brave**
* **Secrets never committed**
* **Window hiding must not hide main console**
* **Logging structure must remain**

## 10. Security & Access Control

* (Planned/Optional) Integrate Cloudflare Access for SSO (Google, Microsoft, GitHub, email).
* Ensure revocation works immediately via Access allow-list.
* Local SOCKS proxy should remain 127.0.0.1-only.
* Document clearly in README that the tool is provided "as-is"; developer is not responsible for misuse.

## 11. AI Enhancement Points

* Automate Cloudflared SSO login tracking (optional, for rolling access control).
* Automate detection of last active user sessions to reduce friction.
* Verify bootstrapping flow works on fresh Windows 11 VMs.
* Optionally integrate health checks (`Invoke-HealthCheck`) before tunnel launch.
* Consider extending logging with session analytics for debugging (user activity anonymized).

## 12. Testing & Validation

* Verify each module individually (`logging.ps1`, `get-binaries.ps1`, `ssh-tunnel.ps1`).
* Test full workflow via `run.bat`:

  * Lock enforcement
  * Binary download
  * SSH tunnel establishment
  * SOCKS port validation
  * Brave launch
  * Graceful shutdown
* Test log rotation and archiving.
* Test installer output on clean system.
* Validate placeholder configs for commit safety.

## 13. Documentation

* Refine README.md for clarity and accuracy, reflecting:

  * Updated workflow
  * SSO/Cloudflare Access plan
  * Secrets & configuration guidance
  * License & legal disclaimers
* Draft LICENSE.md extension if necessary to clarify "as-is" use and non-liability.
* Include detailed AI-oriented TODOs for future automation.

# --- End TODO.md --- #
