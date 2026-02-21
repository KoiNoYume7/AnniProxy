# Repository Organization & PowerShell House Style (based on AnniProxy)

## Purpose
This is a **how-to-structure** guide: where files go, how folders are sorted, how things are named, and what PowerShell code should look like to match this repo’s style.

It’s written as a **general template** (usable for similar PowerShell launchers), with concrete examples taken from this project.

## “Source of truth” files (read order)
- `run.bat` (the only user-facing entry point)
- `.src/main.ps1` (the orchestrator)
- `.src/*.ps1` (small focused modules)
- `.config/*.json` (commit-safe config)
- `.gitignore` (what must never be committed)

## Folder taxonomy (what goes where)
### Commit-safe folders (tracked)
- `.src/`
  - **All PowerShell source**.
  - Rule: keep files small and single-purpose; `main.ps1` coordinates.
- `.config/`
  - **Commit-safe JSON only**.
  - Rule: no secrets, only URLs, toggles, and paths.
- `.assets/`
  - Static resources used by the app (icons, ASCII art scripts, etc.).
- `.dev/`
  - Developer notes and AI instruction documents.

### Runtime-generated folders (gitignored)
- `.bin/`
  - Downloaded/extracted third-party binaries.
- `.tmp/`
  - Generated wrapper scripts or intermediate files.
- `.log/`
  - Session logs and transcripts.

### Single-instance marker (gitignored)
- `.session.lock`
  - Session PID lock file.

## Naming conventions
### Folder names
- Prefer **short, dot-prefixed operational folders** for app-managed data:
  - `.bin`, `.tmp`, `.log`, `.release`, `.dev`, `.assets`, `.config`
- Keep “source” in `.src` (not `src/`) to visually separate it from runtime folders.

### File names
- **Entry**:
  - `run.bat` for Windows double-click entry.
  - `.src/main.ps1` for the PowerShell entry.
- **Modules**:
  - Use **kebab-case** for module scripts: `get-binaries.ps1`, `console-guard.ps1`.
  - Name matches responsibility (verb-noun or noun-noun) and stays stable.
- **Config**:
  - Lowercase JSON names: `.config/config.json`, `.config/ssh.json`.

### Function names (PowerShell)
- Use approved PowerShell verb-noun style where practical:
  - `Get-Binary`, `Resolve-SshExe`, `Test-SocksPort`, `Request-Shutdown`.
- Prefer:
  - `Resolve-*` for “find the best executable/path”.
  - `Test-*` for boolean checks.
  - `Invoke-*` for actions with side effects.
  - `Get-*` for retrieval / acquisition.

### Variables
- Locals:
  - `PascalCase` for meaningful “constants-ish” locals: `BaseDir`, `LogDir`, `SocksPort`.
- Globals:
  - Use `$Global:*` sparingly and only for cross-module runtime state (logging config, provisioning flag, shutdown flags).
  - Keep global initialization in `main.ps1`.

## File structure patterns
### `run.bat` pattern
- Responsibility: find/boot PowerShell 7, generate `.tmp/bootstrap.ps1`, start transcript to `.log/bootstrap.log`, then run `.src/main.ps1`.
- Rule: avoid doing app logic in batch; batch is a launcher only.

### `.src/main.ps1` pattern (the orchestrator)
Keep these sections in this order:
- **Parameters**: CLI overrides (`[CmdletBinding()]`, `param(...)`).
- **Hard prerequisites**: PowerShell version enforcement.
- **Paths**: compute `BaseDir`, `.log`, `.bin`, `.assets`, `.config`.
- **Config load**:
  - Load JSON using `Get-Content -Raw | ConvertFrom-Json`.
  - Apply CLI overrides (use `$PSBoundParameters.ContainsKey(...)`).
- **Global state init**: log file path, log level threshold, provisioning flags.
- **Dot-source modules**: `. "$PSScriptRoot/<module>.ps1"`.
- **Lock + cleanup**:
  - Startup cleanup (stale session) if needed.
  - Acquire lock.
- **Main `try/catch/finally`**:
  - Start dependencies.
  - Start SSH.
  - Wait for readiness.
  - Start browser.
  - Monitoring loop.
  - Always cleanup in `finally`.

### `.src/<module>.ps1` pattern (small focused modules)
- Each module should have:
  - A small number of exported functions.
  - No “app-level” decisions; accept parameters.
  - Logging through `Write-Log` (don’t invent new logging).

## Coding style (PowerShell)
### General
- Target PowerShell **7+** features.
- Prefer explicit `param(...)` blocks.
- Prefer arrays for argument lists (`$args = @(...)`) rather than long strings.
- Prefer `Join-Path` and avoid hardcoding path separators.

### Error style
- `main.ps1` sets `$ErrorActionPreference = 'Stop'`.
- Use `throw` for hard failure states.
- Wrap top-level flow in `try/catch/finally` and do cleanup in `finally`.

### Logging style
- Use `Write-Log <message> <level>` where level is one of `INFO`, `OK`, `WARN`, `ERROR`.
- Keep logs descriptive and action-oriented.

## Config & secrets layout (project-wide rule)
- `.config/*.json` must remain commit-safe.
- Secrets are **files** referenced by path, stored in gitignored folders:
  - `.config/.secret/` (preferred)
  - `.secret/` (also ignored)

## What to create when adding new features
### Adding a new capability (new module)
- Create: `.src/<capability>.ps1`
- Add dot-source line in `main.ps1` next to other modules
- Keep module API surface small (1–3 functions)

### Adding a new config key
- Add the key to the relevant `.config/*.json` file
- Read it once in `main.ps1` into `PascalCase` local
- Validate early (null/empty/range)
- Pass it to modules as parameters (don’t have modules re-read JSON)

### Adding a new runtime folder
- Use a dot-prefixed folder at repo root if it’s app-managed:
  - `.cache/`, `.state/`, `.data/` (if ever needed)
- Add it to `.gitignore`
- Ensure `main.ps1` creates it with `New-Item -ItemType Directory -Force`

## Copy-paste templates
### New module skeleton
```powershell
# .src/example-module.ps1

function Invoke-ExampleAction {
    param(
        [Parameter(Mandatory=$true)][string]$ExampleParam
    )

    Write-Log "Example action: $ExampleParam" "INFO"
}
```

### Reading config with CLI override (pattern)
```powershell
$appConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$finalUseScoop = if ($PSBoundParameters.ContainsKey('UseScoop')) { $UseScoop } else { $appConfig.useScoop }
```

## Commit hygiene (style rule, not optional)
- Never commit:
  - `.bin/`, `.tmp/`, `.log/`, `.release/`, `.session.lock`
  - `.config/.secret/`, `.secret/`
  - `*.exe`

## Quick checklist (when creating files/folders)
- Put new PowerShell code in `.src/`.
- Keep `main.ps1` as the coordinator; put “leaf” logic in modules.
- Use kebab-case for module filenames.
- Use verb-noun for functions.
- Keep config in `.config/*.json` and secrets in gitignored folders.
- Ensure runtime folders are dot-prefixed and gitignored.
