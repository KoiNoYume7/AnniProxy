# AnniProxy TODO (AI-Optimized)

This file is the forward-looking backlog for an AI agent working on this repository.

## 0. Hard invariants (never break)
- PowerShell 7+ only
- Single-instance enforcement via `.session.lock`
- Lifecycle coupling: Brave + SSH tunnel must shut down together
- Local SOCKS bind stays `127.0.0.1` only
- Secrets never committed (`.config/.secret/`, `.secret/`)
- `.config/ssh.json` stays placeholder-safe; real values belong in `.config/ssh.local.json`
- Log retention archives (never deletes)

## 1. Packaging / Installer
- Audit `.src/installer_builder.iss` includes for new modules:
  - `.src/exe-resolvers.ps1`
  - `.src/ssh-utils.ps1`
  - `.src/window-utils.ps1`
  - `.src/log-retention.ps1`
  - `.src/ssh-tunnel.ps1`
  - `.src/ssh-provision.ps1`
  - `.src/healthcheck.ps1`
- Ensure committed config files are included:
  - `.config/config.json`
  - `.config/ssh.json`
- Ensure `.config/ssh.local.json` is never packaged as a tracked file (it is user-local).

## 2. SSH auth window hiding reliability
- Verify the current hide strategy works under:
  - `conhost.exe` (classic console)
  - `OpenConsole.exe` (new console host)
  - Windows Terminal hosting the main AnniProxy console
- If further reliability is needed:
  - add a targeted correlation strategy between `ssh.exe` and its console host window without using broad heuristics that could hide the main terminal.

## 3. Logging improvements
- Reduce `ALL`-level noise once stable (especially in window hiding / SSH PID selection).
- Ensure every early-exit path logs a clear next action.
- Consider adding a short “session summary” line at shutdown (reason + exit code).

## 4. Config UX
- Expand first-run prompt to optionally capture:
  - `socksPort`
  - `useCloudflaredAccessProxy` guidance
- Consider a `-ResetLocalConfig` mode that deletes `.config/ssh.local.json` (ask for confirmation).
- Ensure override merge is well-defined (local overrides always win).

## 5. Key provisioning enhancements
- `-ProvisionKeys` currently generates a keypair; consider:
  - generating a dedicated `known_hosts` entry via `ssh-keyscan` (optional, network-dependent)
  - printing a Windows-friendly “copy public key” instruction
  - optional `-KeyComment` support

## 6. Health check enhancements
- Ensure `-HealthCheckOnly` produces actionable output for:
  - missing `ssh.exe`
  - missing cloudflared when `useCloudflaredAccessProxy=true`
  - misconfigured identity file path
  - port conflicts on `socksPort`
- Consider an optional “attempt fixes” mode (explicitly opt-in).

## 7. Automated tests / smoke tests
- Add a minimal smoke script under `.dev/` that can:
  - run `-HealthCheckOnly`
  - run `-ProvisionKeys` in a temp sandbox directory
  - validate no secrets are created outside `.config/.secret/`

## 8. Repo hygiene
- Confirm `.gitignore` patterns cover:
  - `.config/ssh.local.json`
  - `.config/.secret/`
  - `.log/`, `.tmp/`, `.bin/`
- Ensure README does not claim features that are not implemented.