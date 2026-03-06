# --- start of console-guard.ps1 --- #

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ConsoleGuard {
    public static bool CloseRequested = false;

    private const int CTRL_CLOSE_EVENT = 2;

    private delegate bool HandlerRoutine(int ctrlType);

    [DllImport("kernel32.dll")]
    private static extern bool SetConsoleCtrlHandler(HandlerRoutine handler, bool add);

    private static HandlerRoutine _handler = Handler;

    static ConsoleGuard() {
        SetConsoleCtrlHandler(_handler, true);
    }

    private static bool Handler(int ctrlType) {
        if (ctrlType == CTRL_CLOSE_EVENT) {
            CloseRequested = true;
        }
        return false;
    }
}
"@

function Console-CloseRequested {
    return [ConsoleGuard]::CloseRequested
}

# --- end of console-guard.ps1 --- #