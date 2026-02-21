
# AnniProxy

AnniProxy is a Windows PowerShell 7+ launcher that:

- Starts a Cloudflared Access SSH proxy command
- Starts an SSH SOCKS5 tunnel on `127.0.0.1:<port>`
- Launches Brave Portable with the SOCKS proxy configured

It is designed to work on barebones Windows environments (for example Windows 11 Sandbox) by bootstrapping missing dependencies and by keeping secrets out of the repository.

## Quick start (Windows)

- Run `run.bat`

`run.bat` is the only entry point you should need.

It will:

- Find PowerShell 7 in this order:
  - Bundled: `.bin\pwsh7+\pwsh.exe`
  - System PATH: `pwsh`
  - Optional Scoop install (if enabled in config)
  - Manual bootstrap from the zip URL in `.config\config.json`
- Generate `.tmp\bootstrap.ps1` and run PowerShell via `-File` (avoids cmd.exe quoting edge cases)
- Always write a transcript to `.log\bootstrap.log`

## Configuration

### `.config/config.json`

Commit-safe configuration:

- Download URLs for:
  - `cloudflared`
  - Brave Portable archive
  - PowerShell 7 zip (optional bootstrap)
  - Portable OpenSSH zip (optional bootstrap)
- `useScoop` controls whether Scoop installation is attempted

### `.config/ssh.json`

Commit-safe SSH parameters:

- `user`, `host`, `socksPort`
- `identityFile` (path to private key)
- `knownHostsFile`

These are paths only and must point to gitignored locations.

## Secrets & SSH key authentication (recommended)

To avoid interactive SSH prompts/windows, use key-based authentication.

### Where to store keys

This repo expects secrets under:

- `.config/.secret/` (gitignored)

Also ignored:

- `.secret/`

### Generate a key pair (Windows)

In PowerShell 7:

```powershell
mkdir .config\.secret -Force | Out-Null
ssh-keygen -t ed25519 -f .config\.secret\id_ed25519 -N ""
```

This creates:

- `.config/.secret/id_ed25519` (private key)
- `.config/.secret/id_ed25519.pub` (public key)

### Install the public key on your server (Raspberry Pi)

On the Pi:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Paste the contents of `id_ed25519.pub`, then press Ctrl+D.

### Known hosts file

AnniProxy can write/use a dedicated known_hosts file:

- `.config/.secret/known_hosts`

## Logs & troubleshooting

### Bootstrap transcript

If `run.bat` fails early, check:

- `.log\bootstrap.log`

### Runtime logs

Session logs are written to:

- `.log\session-YYYYMMDD-HHMMSS.log`

SSH / Brave stdout+stderr are written to per-session files (when started non-interactively).

### Log retention

`.log` is capped to 10 files; old logs are moved to:

- `.log\.archive\`

## What gets committed

- `.config/*.json` (commit-safe)
- `.src/*.ps1` (source)
- `run.bat`

## What must never be committed

- `.config/.secret/` (private keys, known_hosts)
- `.secret/`
- `.log/`, `.tmp/`, `.bin/`

## Installer (Inno Setup)

The Inno Setup script currently lives at:

- `.src/installer_builder.iss`

The installer should include only commit-safe files. It should not ship:

- `.config/.secret/`
- `.log/`
- `.tmp/`

If you build an installer for distribution, ensure it copies `.config` and `.src` and the launcher batch file, and lets the app bootstrap binaries on first run.
