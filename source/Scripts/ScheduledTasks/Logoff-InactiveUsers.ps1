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

# P/Invoke for GetLastInputInfo
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
}
'@

try {
    Add-Type -TypeDefinition $code -Language CSharp
} catch {
    # Type might already be added if run multiple times in same session
}

function Get-IdleSeconds {
    $lii = New-Object Win32+LASTINPUTINFO
    $lii.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($lii)
    
    if ([Win32]::GetLastInputInfo([ref]$lii)) {
        $ticks = [Environment]::TickCount
        # Handle potential TickCount rollover (though unlikely to affect short idle checks)
        if ($ticks -lt $lii.dwTime) { return 0 }
        
        return ($ticks - $lii.dwTime) / 1000
    }
    return 0
}

$LimitSeconds = $IdleMinutes * 60

while ($true) {
    $currentIdle = Get-IdleSeconds
    
    if ($currentIdle -ge $LimitSeconds) {
        # Logoff the current session
        & "$env:SystemRoot\System32\logoff.exe"
        Exit
    }
    
    # Check every 10 seconds
    Start-Sleep -Seconds 30
}
3