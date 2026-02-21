
# AnniProxy

AnniProxy is a proxy-browser with a proxy connection to my server. It works like this:

- Starts a Cloudflared Access SSH proxy command
- Starts an SSH SOCKS5 tunnel on `127.0.0.1:<port>`
- Launches Brave Portable with the SOCKS proxy configured

It is designed to work on barebones Windows environments (for example fresh win11 installations or VMs) by bootstrapping all missing dependencies.

> It is supposed to be a proxy to my server, but currently I am working on hardening security, cause I don't want to compromise on security on both client and server side.
> So until the, you gotta provide your own server.

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

SSH parameters:

- `user`, `host`, `socksPort`
- `identityFile` (path to private key)
- `knownHostsFile`

> note: I haven't implemented a way to automatically generate these files, so you'll need to create them manually and therefore use your own server.
> But I am working on implementing a way to find a good authentication method.
> This is as of alpha version 2.0, in case I forget to update this readme (again).

These are paths only and must point to gitignored locations.

## Credentials & access model (no shared secrets)

The plan to integrate better authentication methods is to use Cloudflare Access with SSO (Google, Microsoft, etc.).

- Access is controlled via **Cloudflare Access** (the `cloudflared access ssh` proxy flow).
- Users authenticate with Access policy (email/IdP group).
- Revocation is immediate: remove the user from the Access allow-list/group.

> **Important**: To implement this might take a while, because I don't want to compromise on security on both client and server side.

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

On the Pi (or any machine you want to use as the proxy server):

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

## Installer (Inno Setup)

The Inno Setup script currently lives at:

- `.src/installer_builder.iss`
and there is another version called `installer_builder_full.iss` which bundles all the `.bin` files into the installer for offline installation.

> Note: you need to have the .bin files already downloaded to package it with the .iss script. 
> I might implement the builded version with everything in the github release, but I need to research some more about if I am even allowed to do that.

### Last updated

Last updated: 2026-02-21