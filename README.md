# AnniProxy

AnniProxy is a secure Windows proxy-browser that tunnels traffic through your own SSH server (optionally via Cloudflare Access / Zero Trust, when configured). It bundles a SOCKS5 tunnel and a portable Brave browser for minimal-dependency environments like fresh Windows installs or VMs.

> ⚠️ This software is designed for **personal use with your own server**. Do not expose or share SSH keys publicly. Security is a top priority.

## Features

- Automatic bootstrap of dependencies: PowerShell 7, cloudflared, Brave Portable.
- SSH SOCKS5 tunnel on `127.0.0.1:<port>`.
- Launches Brave with local SOCKS proxy.
- Single-instance enforcement via `.session.lock`.
- Detailed logging and automatic log retention.
- Designed for barebones Windows setups (VMs or fresh installs).

## Quick Start (Windows)

1. Run `run.bat`.
2. The script will:
   - Locate or bootstrap PowerShell 7.
   - Generate `.tmp\bootstrap.ps1` for deterministic startup.
   - Download or use cached binaries (`cloudflared`, `Brave`, 7zip).
   - Start SSH tunnel and validate SOCKS readiness.
   - Launch Brave configured to use `127.0.0.1:<port>` SOCKS proxy.
   - Monitor SSH & Brave lifecycle; shutdown coordinated on exit.

## Configuration

### `.config/config.json` (commit-safe)

- `cloudflaredUrl`, `brave7zUrl`, `7zUrl`, `pwsh7.5.4Url`
- `useScoop`: enable optional Scoop installation
- Other runtime options: `noLogo`, `logLevel`, `noTimestamp`, `offlineSSHTest`

### `.config/ssh.json` (placeholder-safe)

- `user`, `host`, `socksPort`
- `identityFile`, `knownHostsFile` (gitignored, required)
  
> You must provide your own server. Automatic key generation not yet implemented.

### Secrets

- Private keys: `.config/.secret/` (preferred)
- Also supported: `.secret/` (ignored)
- Never commit secrets or real server credentials.

## Generating Key Pair (Windows)

```powershell
mkdir .config/.secret -Force
ssh-keygen -t ed25519 -f .config/.secret/id_ed25519 -N ""
```
Install the public key on your server:

On a Linux server (recommended), run:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
# Paste id_ed25519.pub content, then press Ctrl+D
```

Alternatively, if your server supports it, you can use:

```bash
ssh-copy-id -i id_ed25519.pub <user>@<host>
```

## Logs & Troubleshooting

* `.log/session/` – session logs
* `.log/ssh/` – SSH stdout/stderr
* `.log/brave/` – Brave stdout/stderr
* Archived logs: `.log/.archive/` (never deleted)

Check `.log/bootstrap.log` if `run.bat` fails early.

## Installer (Inno Setup)

* `.src/installer_builder.iss` – build installer
* `.release/AnniProxy_Setup_v1.0.0.exe` – example output
* Requires `.bin/` files for offline build

## Security & Access Model

* Can use **Cloudflare Access** for authentication (when configured).
* Revocation is immediate via Access allow-lists.
* Localhost-only SOCKS proxy; no shared secrets in repo.

## Developer Notes

* PowerShell 7+ only; single-instance enforced.
* Logging structured; never replace `Write-Log`.
* Lifecycle coupling: SSH/Brave must shut down together.
* Window hiding: SSH auth console only; main console (`wt.exe`) safe.

## License

Licensed under Apache 2.0. See LICENSE.txt.

Last Updated
2026-02-26