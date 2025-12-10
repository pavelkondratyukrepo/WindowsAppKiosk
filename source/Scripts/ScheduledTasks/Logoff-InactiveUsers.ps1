<#
Accurate idle detection & logoff via WTS API
-------------------------------------------------------
This PowerShell script is intended to run as SYSTEM via a Scheduled Task.
It enumerates all user sessions using the Remote Desktop Services (WTS) API,
computes each session's idle time (from LastInputTime or WTSIdleTime),
optionally warns, and logs off sessions idle >= threshold.

Logging off a session terminates all user processes; warn users first if required.

Docs (citations):
- WTSQuerySessionInformationA (query per-session info): https://learn.microsoft.com/en-us/windows/win32/api/wtsapi32/nf-wtsapi32-wtsquerysessioninformationa
- WTSINFOA (contains LastInputTime/CurrentTime timestamps): https://learn.microsoft.com/en-us/windows/win32/api/wtsapi32/ns-wtsapi32-wtsinfoa
- WTSEnumerateSessionsA (enumerate sessions): https://learn.microsoft.com/en-us/windows/win32/api/wtsapi32/nf-wtsapi32-wtsenumeratesessionsa
- WTS_INFO_CLASS enumeration (includes WTSIdleTime & WTSSessionInfo): https://learn.microsoft.com/en-us/windows/win32/api/wtsapi32/ne-wtsapi32-wts_info_class
- logoff command (by session ID; recommend warning users): https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/logoff
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [int]
    $IdleThresholdMinutes
)

$ErrorActionPreference = 'Stop'

# Constants
[int]$IdleThresholdSeconds = $IdleThresholdMinutes * 60
[int]$CheckIntervalMinutes = 1
[int]$CheckIntervalSeconds = $CheckIntervalMinutes * 60
[string[]]$ExcludeUsers = @('SYSTEM', 'LOCAL SERVICE', 'NETWORK SERVICE') # users to skip

# Event Log Settings
$EventLogName = "Windows-App-Kiosk"
$EventSource = "AutoLogoff"

function Write-Log {
    param(
        [string]$Message,
        [System.Diagnostics.EventLogEntryType]$Type = 'Information',
        [int]$EventId = 100
    )
    Write-EventLog -LogName $EventLogName -Source $EventSource -EntryType $Type -EventId $EventId -Message $Message
}

# Ensure Event Source exists
if (-not ([System.Diagnostics.EventLog]::SourceExists($EventSource))) {
    try {
        New-EventLog -LogName $EventLogName -Source $EventSource
        Write-Log -Message "Created Event Source: $EventSource in Log: $EventLogName"
    }
    catch {
        Write-Warning "Failed to create Event Source. Ensure script is run as Administrator/SYSTEM."
    }
}

# --- WTS API (C# interop) ---
Add-Type -Language CSharp @"
using System;
using System.Runtime.InteropServices;

public class WtsApi {
    public enum WTS_CONNECTSTATE_CLASS { WTSActive, WTSConnected, WTSConnectQuery, WTSShadow, WTSDisconnected, WTSIdle, WTSListen, WTSReset, WTSDown, WTSInit }
    public enum WTS_INFO_CLASS {
        WTSInitialProgram, WTSApplicationName, WTSWorkingDirectory, WTSOEMId, WTSSessionId, WTSUserName, WTSWinStationName, WTSDomainName, WTSConnectState,
        WTSClientBuildNumber, WTSClientName, WTSClientDirectory, WTSClientProductId, WTSClientHardwareId, WTSClientAddress, WTSClientDisplay,
        WTSClientProtocolType, WTSIdleTime, WTSLogonTime, WTSIncomingBytes, WTSOutgoingBytes, WTSIncomingFrames, WTSOutgoingFrames, WTSClientInfo,
        WTSSessionInfo, WTSSessionInfoEx, WTSConfigInfo, WTSValidationInfo, WTSSessionAddressV4, WTSIsRemoteSession, WTSSessionActivityId, WTSCapabilityCheck
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WTS_SESSION_INFO {
        public int SessionID;
        public IntPtr pWinStationName;
        public WTS_CONNECTSTATE_CLASS State;
    }

    // ANSI variant; includes timestamps we need (LastInputTime, CurrentTime)
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
    public struct WTSINFOA {
        public WTS_CONNECTSTATE_CLASS State;
        public uint SessionId;
        public uint IncomingBytes, OutgoingBytes, IncomingFrames, OutgoingFrames, IncomingCompressedBytes, OutgoingCompressedBy;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string WinStationName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=17)] public string Domain;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=21)] public string UserName;
        public long ConnectTime, DisconnectTime, LastInputTime, LogonTime, CurrentTime;
    }

    [DllImport("wtsapi32.dll", SetLastError=true)]
    public static extern bool WTSEnumerateSessions(IntPtr hServer, int Reserved, int Version, out IntPtr ppSessionInfo, out int pCount);

    [DllImport("wtsapi32.dll", SetLastError=true)]
    public static extern bool WTSQuerySessionInformation(IntPtr hServer, int sessionId, WTS_INFO_CLASS wtsInfoClass, out IntPtr ppBuffer, out int pBytesReturned);

    [DllImport("wtsapi32.dll")] public static extern void WTSFreeMemory(IntPtr pMemory);

    public static readonly IntPtr WTS_CURRENT_SERVER_HANDLE = IntPtr.Zero;
}
"@

# --- Helpers to read strings and typed structures from WTSQuerySessionInformation ---
function Get-WTSString {
    param([int]$SessionId, [WtsApi+WTS_INFO_CLASS]$InfoClass)
    $buf = [IntPtr]::Zero; $bytes = 0
    $ok = [WtsApi]::WTSQuerySessionInformation([WtsApi]::WTS_CURRENT_SERVER_HANDLE, $SessionId, $InfoClass, [ref]$buf, [ref]$bytes)
    if (-not $ok -or $bytes -le 0) { return $null }
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($buf)
    }
    finally { [WtsApi]::WTSFreeMemory($buf) }
}

function Get-WTSSessionInfo {
    param([int]$SessionId)
    $buf = [IntPtr]::Zero; $bytes = 0
    $ok = [WtsApi]::WTSQuerySessionInformation([WtsApi]::WTS_CURRENT_SERVER_HANDLE, $SessionId, [WtsApi+WTS_INFO_CLASS]::WTSSessionInfo, [ref]$buf, [ref]$bytes)
    if (-not $ok -or $bytes -lt [System.Runtime.InteropServices.Marshal]::SizeOf([type][WtsApi+WTSINFOA])) { return $null }
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStructure($buf, [type][WtsApi+WTSINFOA])
    }
    finally { [WtsApi]::WTSFreeMemory($buf) }
}

function Get-WTSIdleTimeMinutes {
    param(
        [int]$SessionId
    )
    # Prefer WTSIdleTime (returns seconds); fall back to WTSSessionInfo timestamps
    $buf = [IntPtr]::Zero; $bytes = 0
    $ok = [WtsApi]::WTSQuerySessionInformation([WtsApi]::WTS_CURRENT_SERVER_HANDLE, $SessionId, [WtsApi+WTS_INFO_CLASS]::WTSIdleTime, [ref]$buf, [ref]$bytes)
    if ($ok -and $bytes -ge 4) {
        try {
            $seconds = [System.Runtime.InteropServices.Marshal]::ReadInt32($buf)
            
            # Debug: Log idle time if it's significant (e.g. > 10s) to help troubleshoot false positives
            if ($seconds -ge 10) {
                Write-Log -Message "Session $SessionId idle seconds: $seconds" -Type Information -EventId 999
            }

            if ($seconds -lt 0) { $seconds = 0 }
            return [int][math]::Floor($seconds / 60.0)
        }
        finally { [WtsApi]::WTSFreeMemory($buf) }
    }

    # Fallback removed as LastInputTime is often unreliable/stuck, causing false logoffs.
    Write-Log -Message "Could not query WTSIdleTime for session $SessionId. Assuming Active." -Type Warning -EventId 998
    return 0
}

function Get-WtsSessions {
    $ptr = [IntPtr]::Zero; $count = 0
    $ok = [WtsApi]::WTSEnumerateSessions([WtsApi]::WTS_CURRENT_SERVER_HANDLE, 0, 1, [ref]$ptr, [ref]$count)
    if (-not $ok -or $count -le 0) { return @() }

    $sessions = @()
    try {
        $size = [System.Runtime.InteropServices.Marshal]::SizeOf([type][WtsApi+WTS_SESSION_INFO])
        for ($i = 0; $i -lt $count; $i++) {
            $itemPtr = [IntPtr]::Add($ptr, $i * $size)
            $si = [System.Runtime.InteropServices.Marshal]::PtrToStructure($itemPtr, [type][WtsApi+WTS_SESSION_INFO])
            $name = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($si.pWinStationName)

            # Get username & domain for this session
            $username = Get-WTSString -SessionId $si.SessionID -InfoClass ([WtsApi+WTS_INFO_CLASS]::WTSUserName)
            $domain = Get-WTSString -SessionId $si.SessionID -InfoClass ([WtsApi+WTS_INFO_CLASS]::WTSDomainName)

            $sessions += [pscustomobject]@{
                Id          = $si.SessionID
                SessionName = $name
                State       = $si.State
                Domain      = $domain
                Username    = $username
            }
        }
    }
    finally { [WtsApi]::WTSFreeMemory($ptr) }

    return $sessions
}

function Invoke-LogoffSession {
    param(
        [int]$SessionId,
        [string]$Username,
        [string]$Domain
    )
    Write-Log "Logoff: SessionId=$SessionId User=$Domain\$Username"
    # Use built-in 'logoff' by session ID (documented and reliable)
    cmd /c "logoff $SessionId" | Out-Null
}

Write-Log -Message "Logoff-InactiveUsers started. IdleThresholdMinutes=$IdleThresholdMinutes" -EventId 1000
while ($true) {
    try {
        $sessions = Get-WtsSessions

        foreach ($s in $sessions) {
            # Target only active sessions
            if ($s.State -ne 'WTSActive') { continue }

            # Exclude specified usernames
            if ($ExcludeUsers -contains $s.Username) { continue }

            $idleMins = Get-WTSIdleTimeMinutes -SessionId $s.Id
            if ($idleMins -eq $null) { Write-Log "No idle reading for session $($s.Id)"; continue }

            if ($idleMins -ge $IdleThresholdMinutes) {
                Invoke-LogoffSession -SessionId $s.Id -Username $s.Username -Domain $s.Domain
            }
        }
    }
    catch {
        Write-Log -Message "Unhandled error: $_" -Type Error -EventId 102
    }
    Start-Sleep -Seconds $CheckIntervalSeconds
}
