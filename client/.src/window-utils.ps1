if (-not ("NativeWindow" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class NativeWindow {
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@
}

if (-not ("NativeWindowEx" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class NativeWindowEx {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);

  public static IntPtr[] GetTopLevelWindowsForProcess(int pid) {
    var results = new List<IntPtr>();
    EnumWindows(delegate (IntPtr hWnd, IntPtr lParam) {
      uint windowPid;
      GetWindowThreadProcessId(hWnd, out windowPid);
      if (windowPid == (uint)pid) {
        results.Add(hWnd);
      }
      return true;
    }, IntPtr.Zero);
    return results.ToArray();
  }
}
"@
}

function Minimize-ProcessWindow {
    param(
        [Parameter(Mandatory=$true)][System.Diagnostics.Process]$Process,
        [ValidateSet('Minimize','Hide')][string]$Action = 'Minimize'
    )

    try {
        $minimized = $false
        $cmd = if ($Action -eq 'Hide') { 0 } else { 6 }
        try { Write-Log "Window action '$Action' requested for PID $($Process.Id) ($($Process.ProcessName))" "ALL" } catch {}
        $h = [IntPtr]::Zero

        for ($i = 0; $i -lt 50; $i++) {
            try { $Process.Refresh() } catch {}
            $h = $Process.MainWindowHandle
            if ($h -and $h -ne [IntPtr]::Zero) { break }
            Start-Sleep -Milliseconds 100
        }

        if ($h -and $h -ne [IntPtr]::Zero) {
            $null = [NativeWindow]::ShowWindowAsync($h, $cmd)
            $minimized = $true
            try { Write-Log "Applied '$Action' to PID $($Process.Id) main window handle" "ALL" } catch {}
            return
        }

        try {
            $handles = [NativeWindowEx]::GetTopLevelWindowsForProcess([int]$Process.Id)
            foreach ($hwnd in $handles) {
                if ($hwnd -and $hwnd -ne [IntPtr]::Zero) {
                    $null = [NativeWindow]::ShowWindowAsync($hwnd, $cmd)
                    $minimized = $true
                    try { Write-Log "Applied '$Action' to PID $($Process.Id) via EnumWindows" "ALL" } catch {}
                }
            }
            if ($minimized) { return }
        } catch {}

        try {
            $conhostPid = $null
            $conhost = Get-CimInstance Win32_Process -Filter "Name='conhost.exe' AND ParentProcessId=$($Process.Id)" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($conhost -and $conhost.ProcessId) {
                $conhostPid = [int]$conhost.ProcessId
            }

            if ($conhostPid) {
                $conhostProc = Get-Process -Id $conhostPid -ErrorAction SilentlyContinue
                if ($conhostProc) {
                    $hh = [IntPtr]::Zero
                    for ($j = 0; $j -lt 50; $j++) {
                        try { $conhostProc.Refresh() } catch {}
                        $hh = $conhostProc.MainWindowHandle
                        if ($hh -and $hh -ne [IntPtr]::Zero) { break }
                        Start-Sleep -Milliseconds 100
                    }

                    if ($hh -and $hh -ne [IntPtr]::Zero) {
                        $null = [NativeWindow]::ShowWindowAsync($hh, $cmd)
                        $minimized = $true
                        try { Write-Log "Applied '$Action' to child conhost.exe PID $conhostPid" "ALL" } catch {}
                    }

                    if (-not $minimized) {
                        try {
                            $handles = [NativeWindowEx]::GetTopLevelWindowsForProcess([int]$conhostPid)
                            foreach ($hwnd in $handles) {
                                if ($hwnd -and $hwnd -ne [IntPtr]::Zero) {
                                    $null = [NativeWindow]::ShowWindowAsync($hwnd, $cmd)
                                    $minimized = $true
                                    try { Write-Log "Applied '$Action' to child conhost.exe PID $conhostPid via EnumWindows" "ALL" } catch {}
                                }
                            }
                        } catch {}
                    }
                }
            }
        } catch {}

        if ($minimized) { return }

        try {
            $hostNames = if ($Action -eq 'Hide') {
                @("conhost.exe", "OpenConsole.exe")
            } else {
                @("conhost.exe", "OpenConsole.exe", "wt.exe", "WindowsTerminal.exe")
            }
            $rootPid = [int]$Process.Id

            $all = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
            if ($all) {
                $childrenByParent = @{}
                foreach ($p in $all) {
                    $ppid = $null
                    try { $ppid = [int]$p.ParentProcessId } catch { continue }
                    if (-not $childrenByParent.ContainsKey($ppid)) {
                        $childrenByParent[$ppid] = New-Object System.Collections.Generic.List[object]
                    }
                    $childrenByParent[$ppid].Add($p)
                }

                $desc = New-Object System.Collections.Generic.List[object]
                $queue = New-Object System.Collections.Generic.Queue[int]
                $visited = @{}
                $queue.Enqueue($rootPid)
                $visited[$rootPid] = $true

                while ($queue.Count -gt 0) {
                    $cur = $queue.Dequeue()
                    if ($childrenByParent.ContainsKey($cur)) {
                        foreach ($ch in $childrenByParent[$cur]) {
                            $cid = $null
                            try { $cid = [int]$ch.ProcessId } catch { continue }
                            if (-not $visited.ContainsKey($cid)) {
                                $visited[$cid] = $true
                                $desc.Add($ch)
                                $queue.Enqueue($cid)
                            }
                        }
                    }
                }

                $hosts = $desc | Where-Object { $hostNames -contains $_.Name }
                if ($hosts) {
                    try { Write-Log ("Descendant console-host processes found: {0}" -f ($hosts.Count)) "ALL" } catch {}
                }

                foreach ($hproc in $hosts) {
                    $HostPid = $null
                    try { $HostPid = [int]$hproc.ProcessId } catch { continue }

                    $p2 = $null
                    try { $p2 = Get-Process -Id $HostPid -ErrorAction SilentlyContinue } catch {}
                    if (-not $p2) { continue }

                    $hh = [IntPtr]::Zero
                    for ($j = 0; $j -lt 50; $j++) {
                        try { $p2.Refresh() } catch {}
                        $hh = $p2.MainWindowHandle
                        if ($hh -and $hh -ne [IntPtr]::Zero) { break }
                        Start-Sleep -Milliseconds 100
                    }

                    if ($hh -and $hh -ne [IntPtr]::Zero) {
                        $null = [NativeWindow]::ShowWindowAsync($hh, $cmd)
                        $minimized = $true
                        try { Write-Log "Applied '$Action' to descendant host PID $HostPid ($($p2.ProcessName))" "ALL" } catch {}
                    }

                    if (-not $minimized) {
                        try {
                            $handles = [NativeWindowEx]::GetTopLevelWindowsForProcess([int]$HostPid)
                            foreach ($hwnd in $handles) {
                                if ($hwnd -and $hwnd -ne [IntPtr]::Zero) {
                                    $null = [NativeWindow]::ShowWindowAsync($hwnd, $cmd)
                                    $minimized = $true
                                    try { Write-Log "Applied '$Action' to descendant host PID $HostPid ($($p2.ProcessName)) via EnumWindows" "ALL" } catch {}
                                }
                            }
                        } catch {}
                    }
                }

                if ($minimized) { return }
            }
        } catch {}

        if ($Action -eq 'Hide') {
            Write-Log "Could not find a safe console host window to Hide for PID $($Process.Id)" "WARN"
            return
        }

        try {
            $sshStart = $null
            $sshSessionId = $null
            try { $sshStart = $Process.StartTime } catch {}
            try { $sshSessionId = $Process.SessionId } catch {}

            if (-not $sshStart -or ($null -eq $sshSessionId)) {
                Write-Log "Could not resolve SSH process StartTime/SessionId for window minimization" "WARN"
                return
            }

            $windowStart = $sshStart.AddSeconds(-5)
            $windowEnd   = $sshStart.AddSeconds(45)

            $candidates = @()
            $names = @("conhost", "OpenConsole", "wt", "WindowsTerminal")
            foreach ($n in $names) {
                try {
                    $candidates += Get-Process -Name $n -ErrorAction SilentlyContinue
                } catch {}
            }

            $candidates = $candidates | Where-Object {
                try {
                    $_.SessionId -eq $sshSessionId -and $_.StartTime -ge $windowStart -and $_.StartTime -le $windowEnd
                } catch {
                    $false
                }
            } | Sort-Object StartTime

            try { Write-Log ("Console-host candidates in window: {0}" -f ($candidates.Count)) "ALL" } catch {}

            foreach ($p in $candidates) {
                $hh = [IntPtr]::Zero
                for ($j = 0; $j -lt 30; $j++) {
                    try { $p.Refresh() } catch {}
                    $hh = $p.MainWindowHandle
                    if ($hh -and $hh -ne [IntPtr]::Zero) { break }
                    Start-Sleep -Milliseconds 100
                }

                if ($hh -and $hh -ne [IntPtr]::Zero) {
                    $null = [NativeWindow]::ShowWindowAsync($hh, $cmd)
                    $minimized = $true
                    try { Write-Log "Applied '$Action' to candidate PID $($p.Id) ($($p.ProcessName))" "ALL" } catch {}
                }
            }

            if (-not $minimized) {
                Write-Log "Could not find a console host window to $Action for PID $($Process.Id)" "WARN"
            }
        } catch {}
    } catch {}
}
