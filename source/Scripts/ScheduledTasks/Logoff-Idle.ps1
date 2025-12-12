param(
    [int]$IdleWaitTimeoutSeconds,
    [string]$EventLog = 'Windows-App-Kiosk',
    [string]$EventSource = 'AutoLogoff'
)

# Add type for checking session lock state
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class SessionChecker {
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [DllImport("user32.dll")]
    public static extern IntPtr OpenInputDesktop(int dwFlags, bool fInherit, int dwDesiredAccess);

    [DllImport("user32.dll")]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    public static bool IsSessionLocked() {
        IntPtr hDesktop = OpenInputDesktop(0, false, 0);
        if (hDesktop == IntPtr.Zero) {
            return true; // Desktop is locked
        }
        CloseDesktop(hDesktop);
        return false; // Desktop is accessible
    }
}
"@

Write-EventLog -LogName $EventLog -Source $EventSource -EventId 1000 -EntryType Information -Message "Screen locked. Waiting $IdleWaitTimeoutSeconds seconds before logoff."

# Sleep in intervals and check if session is still locked
$CheckInterval = 30 # Check every 30 seconds
$ElapsedSeconds = 0

while ($ElapsedSeconds -lt $IdleWaitTimeoutSeconds) {
    $SleepTime = [Math]::Min($CheckInterval, ($IdleWaitTimeoutSeconds - $ElapsedSeconds))
    Start-Sleep -Seconds $SleepTime
    $ElapsedSeconds += $SleepTime

    # Check if session is still locked
    if (-not [SessionChecker]::IsSessionLocked()) {
        Write-EventLog -LogName $EventLog -Source $EventSource -EventId 1002 -EntryType Information -Message "Session unlocked. Canceling logoff."
        exit 0
    }
}

Write-EventLog -LogName $EventLog -Source $EventSource -EventId 1001 -EntryType Information -Message "Logoff initiated due to inactivity."

& logoff.exe