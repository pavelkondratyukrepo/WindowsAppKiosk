<#
.SYNOPSIS
    Logs off the current user after a specified period of inactivity.
    Intended to be run in the user's session (e.g. via Logon Script or Scheduled Task as User).

.PARAMETER IdleMinutes
    Number of minutes of inactivity before logoff. Default is 15.
#>
param (
    [int]$IdleMinutes = 15
)

$ErrorActionPreference = 'SilentlyContinue'

# P/Invoke for GetLastInputInfo and GetTickCount
$code = @'
using System;
using System.Runtime.InteropServices;

public static class Win32 {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [DllImport("kernel32.dll")]
    public static extern uint GetTickCount();
}
'@

try {
    Add-Type -TypeDefinition $code -Language CSharp
} catch {
    # Type might already be added if run multiple times in same session
}

# Setup Event Log for debugging
$EventLogName = "Windows-App-Kiosk"
$EventSource = "AutoLogoff-User"
if (-not ([System.Diagnostics.EventLog]::SourceExists($EventSource))) {
    try {
        New-EventLog -LogName $EventLogName -Source $EventSource -ErrorAction SilentlyContinue
    } catch {}
}

function Write-Log {
    param([string]$Msg, [int]$Id=100, [System.Diagnostics.EventLogEntryType]$Type='Information')
    try {
        Write-EventLog -LogName $EventLogName -Source $EventSource -EventId $Id -EntryType $Type -Message $Msg -ErrorAction SilentlyContinue
    } catch {}
}

function Get-IdleSeconds {
    $lii = New-Object Win32+LASTINPUTINFO
    $lii.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($lii)
    
    if ([Win32]::GetLastInputInfo([ref]$lii)) {
        $ticks = [Win32]::GetTickCount()
        
        # Unsigned subtraction handles rollover correctly as long as idle time < 49.7 days
        # e.g. Current=10, Last=5 -> 5
        # e.g. Current=5, Last=4294967290 (near max) -> 5 - (-6) = 11? No.
        # In UInt32: 5 - 4294967290 = 11.
        
        $diff = $ticks - $lii.dwTime
        return $diff / 1000
    }
    return 0
}

$LimitSeconds = $IdleMinutes * 60
Write-Log "Starting User Idle Monitor. Threshold: $IdleMinutes minutes ($LimitSeconds seconds)."

while ($true) {
    $currentIdle = Get-IdleSeconds
    
    # Debug logging every minute (approx)
    # if ($currentIdle -gt 60) { Write-Log "Current Idle: $currentIdle seconds" -Id 900 }

    if ($currentIdle -ge $LimitSeconds) {
        Write-Log "Idle threshold reached ($currentIdle >= $LimitSeconds). Logging off." -Id 101
        & "$env:SystemRoot\System32\logoff.exe"
        Exit
    }
    
    Start-Sleep -Seconds 10
}