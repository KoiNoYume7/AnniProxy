# Maintainer/Developer Notes (Human-Facing)

This file is for maintainers and developers who need to understand the project’s internals, conventions, and future directions. It is intentionally less formal than the AI docs and more opinionated.

## Quick refresher on the current state

- **Modular refactor done**: `.src/main.ps1` orchestrates; modules under `.src/` handle focused concerns.
- **Config layering**: `.config/ssh.json` is placeholder-safe; real values go into `.config/ssh.local.json` (gitignored).
- **New CLI modes**: `-ProvisionKeys` (keygen) and `-HealthCheckOnly` (diagnostics).
- **Optional Cloudflare Access**: controlled by `useCloudflaredAccessProxy` in `.config/config.json`.
- **Log organization**: `.log/session/`, `.log/ssh/`, `.log/brave/`; archived into `.log/.archive/<category>/` (never deleted).

## File/folder layout ideas (optional, low urgency)

If you ever want to clean up the root folder, consider these moves:

### Move runtime-generated folders deeper
- Keep `.bin/`, `.log/`, `.tmp/` at root (they’re already gitignored and well-known).
- If you want a cleaner root, you could introduce a top-level `runtime/` or `var/` folder and move them there, but this would require updating paths in `run.bat` and `main.ps1`.

### Split assets and config
- `.assets/` is fine as-is.
- `.config/` is fine as-is.
- If you ever add more “developer-only” scripts, you could create a `scripts/` folder at root for things like `build-installer.ps1`, `run-tests.ps1`, etc.

### Consolidate `.dev/`
- `.dev/` currently holds AI docs and human notes. That’s fine.
- If you add more developer tooling, you could create subfolders:
  - `.dev/ai/` (instructions.md, TODO.md, project-style.md)
  - `.dev/human/` (this file, future design docs)

### Optional: move `run.bat` to a `launcher/` folder
- Not necessary unless you want a very clean root.
- Would require updating any documentation that references `run.bat`.

None of these are urgent; the current layout works and is already documented.

## Common maintainer tasks

### Updating bundled binaries
1. Update URLs in `.config/config.json`.
2. Delete the relevant folder under `.bin/` to force re-download on next run.
3. Test with `run.bat` on a clean machine or after clearing `.bin/`.

### Adding a new module
1. Create `.src/<name>.ps1` with 1–3 focused functions.
2. Add a dot-source line in `.src/main.ps1`.
3. Use `Write-Log` for logging; respect `$Global:` variables.
4. Update `.dev/instructions.md` and `.dev/project-style.md` if the module is notable.

### Changing SSH args
- Edit `.src/ssh-tunnel.ps1`. This is the authoritative place.
- Do not edit SSH args in `main.ps1` directly.

### Installer updates
- Open `.src/installer_builder.iss` in Inno Setup.
- Ensure new `.src/*.ps1` files are included.
- Increment version numbers if needed.
- Test the resulting installer on a clean Windows machine.

## Debugging tips

- If SSH tunnel doesn’t start:
  - Run `-HealthCheckOnly` to see diagnostics.
  - Check `.log/ssh/` logs.
  - Verify `cloudflared.exe` is present when `useCloudflaredAccessProxy=true`.
- If window hiding misbehaves:
  - Check logs at `LogLevel=ALL` to see which PID is being targeted.
  - Ensure you’re not running inside Windows Terminal with complex tab layouts.
- If provisioning fails:
  - Ensure `.config/.secret/` is writable.
  - Run `-ProvisionKeys` manually and inspect output.

## Release hygiene

- Before tagging a release:
  - Ensure `.gitignore` covers all runtime artifacts.
  - Run `-HealthCheckOnly` and `-ProvisionKeys` in a clean checkout.
  - Update `README.md` if behavior changed.
  - Rebuild the installer if you added new files.

## Contact/notes

- This file lives in `.dev/` so it’s tracked but not user-facing.
- If you need to leave notes for yourself or future maintainers, put them here.
- For AI-targeted documentation, edit `.dev/instructions.md`, `.dev/TODO.md`, and `.dev/project-style.md` instead.
