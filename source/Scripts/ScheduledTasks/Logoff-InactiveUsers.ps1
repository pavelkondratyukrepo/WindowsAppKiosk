
# AutoLogoff-InactiveUsers.ps1
# Runs as SYSTEM. Logs off inactive users after idle timeout.

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [int]
    $IdleThresholdMinutes
)

$ErrorActionPreference = 'Stop'

# Constants
[int]$IdleThresholdSeconds = $IdleThresholdMinutes * 60
[int]$CheckIntervalMinutes = 1
[int]$CheckIntervalSeconds = $CheckIntervalMinutes * 60

# Event Log Settings
$EventLogName = "Windows-App-Kiosk"
$EventSource = "AutoLogoff"

# Ensure Event Source exists
if (-not ([System.Diagnostics.EventLog]::SourceExists($EventSource))) {
    try {
        New-EventLog -LogName $EventLogName -Source $EventSource
        Write-Host "Created Event Source: $EventSource in Log: $EventLogName"
    }
    catch {
        Write-Warning "Failed to create Event Source. Ensure script is run as Administrator/SYSTEM."
    }
}

$ExcludeSids = @('S-1-5-18') # SYSTEM

Add-Type -Language CSharp @"
using System;
using System.Runtime.InteropServices;

public static class WtsApi
{
    [DllImport("kernel32.dll")]
    public static extern uint WTSGetActiveConsoleSessionId();

    public enum WTS_CONNECTSTATE_CLASS
    {
        WTSActive,
        WTSConnected,
        WTSConnectQuery,
        WTSShadow,
        WTSDisconnected,
        WTSIdle,
        WTSListen,
        WTSReset,
        WTSDown,
        WTSInit
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WTS_SESSION_INFO
    {
        public Int32 SessionId;
        [MarshalAs(UnmanagedType.LPStr)]
        public String pWinStationName;
        public WTS_CONNECTSTATE_CLASS State;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WTSINFO
    {
        public WTS_CONNECTSTATE_CLASS State;
        public int SessionId;
        public int IncomingBytes;
        public int OutgoingBytes;
        public int IncomingFrames;
        public int OutgoingFrames;
        public int IncomingCompressedBytes;
        public int OutgoingCompressedBytes;
        public int WinStationNameLength;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string WinStationName;
        public int DomainLength;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 17)]
        public string Domain;
        public int UserNameLength;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 21)]
        public string UserName;
        public int ConnectTime;
        public int DisconnectTime;
        public int LastInputTime;   // seconds since last input
        public int LogonTime;
        public int CurrentTime;
    }

    public enum WTS_INFO_CLASS
    {
        WTSUserName = 5,
        WTSDomainName = 7,
        WTSIdleTime = 18,
        WTSSessionInfo = 24
    }

    [DllImport("wtsapi32.dll", SetLastError = true)]
    public static extern bool WTSEnumerateSessions(
        IntPtr hServer,
        [MarshalAs(UnmanagedType.U4)] Int32 Reserved,
        [MarshalAs(UnmanagedType.U4)] Int32 Version,
        ref IntPtr ppSessionInfo,
        [MarshalAs(UnmanagedType.U4)] ref Int32 pCount);

    [DllImport("wtsapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool WTSQuerySessionInformation(
        IntPtr hServer,
        int sessionId,
        WTS_INFO_CLASS wtsInfoClass,
        out IntPtr ppBuffer,
        out int pBytesReturned);

    [DllImport("wtsapi32.dll")]
    public static extern void WTSFreeMemory(IntPtr pMemory);
}
"@

function Get-ActiveSessions {
    $server = [IntPtr]::Zero
    $ppSessionInfo = [IntPtr]::Zero
    $count = 0
    
    if ([WtsApi]::WTSEnumerateSessions($server, 0, 1, [ref]$ppSessionInfo, [ref]$count)) {
        $dataSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][WtsApi+WTS_SESSION_INFO])
        $current = $ppSessionInfo
        
        for ($i = 0; $i -lt $count; $i++) {
            $sessionInfo = [System.Runtime.InteropServices.Marshal]::PtrToStructure($current, [type][WtsApi+WTS_SESSION_INFO])
            $current = [IntPtr]::Add($current, $dataSize)
            
            # Return Active and Disconnected sessions (users logged in)
            if ($sessionInfo.State -eq 'WTSActive' -or $sessionInfo.State -eq 'WTSDisconnected') {
                $sessionInfo
            }
        }
        [WtsApi]::WTSFreeMemory($ppSessionInfo)
    }
}

function Get-SessionIdleSeconds([int]$SessionId) {
    $buf = [IntPtr]::Zero; $bytes = 0

    # Try WTSSessionInfo first
    if ([WtsApi]::WTSQuerySessionInformation([IntPtr]::Zero, $SessionId, [WtsApi+WTS_INFO_CLASS]::WTSSessionInfo, [ref]$buf, [ref]$bytes)) {
        try {
            $info = [System.Runtime.InteropServices.Marshal]::PtrToStructure($buf, [type]'WtsApi+WTSINFO')
            return [int]$info.LastInputTime
        } finally {
            [WtsApi]::WTSFreeMemory($buf)
        }
    }

    # Fallback: WTSIdleTime (DWORD)
    if ([WtsApi]::WTSQuerySessionInformation([IntPtr]::Zero, $SessionId, [WtsApi+WTS_INFO_CLASS]::WTSIdleTime, [ref]$buf, [ref]$bytes)) {
        try { return [System.Runtime.InteropServices.Marshal]::ReadInt32($buf) }
        finally { [WtsApi]::WTSFreeMemory($buf) }
    }

    return $null
}

function Get-SessionUser([int]$SessionId) {
    $buf = [IntPtr]::Zero; $bytes = 0
    $user = $null; $domain = $null

    if ([WtsApi]::WTSQuerySessionInformation([IntPtr]::Zero, $SessionId, [WtsApi+WTS_INFO_CLASS]::WTSUserName, [ref]$buf, [ref]$bytes)) {
        try { $user = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($buf) } finally { [WtsApi]::WTSFreeMemory($buf) }
    }
    if ([WtsApi]::WTSQuerySessionInformation([IntPtr]::Zero, $SessionId, [WtsApi+WTS_INFO_CLASS]::WTSDomainName, [ref]$buf, [ref]$bytes)) {
        try { $domain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($buf) } finally { [WtsApi]::WTSFreeMemory($buf) }
    }

    if ([string]::IsNullOrWhiteSpace($user)) { return $null }
    if ([string]::IsNullOrWhiteSpace($domain)) { return $user }
    return "$domain\$user"
}

function Get-UserSid($Domain, $Username) {
    try {
        $acc = if ([string]::IsNullOrWhiteSpace($Domain)) { $Username } else { "$Domain\$Username" }
        $ntAccount = New-Object System.Security.Principal.NTAccount($acc)
        $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
        return $sid
    } catch {
        return $null
    }
}

Write-EventLog -EventLog $EventLog -EventSource $EventSource -EventId 100 -EntryType Information -Message "AutoLogoff Service Started. Threshold: $IdleThresholdMinutes minutes."

while ($true) {
    try {
        $sessions = Get-ActiveSessions
        foreach ($session in $sessions) {
            $sid = $session.SessionId
            $userDomainName = Get-SessionUser -SessionId $sid
            
            if (-not [string]::IsNullOrWhiteSpace($userDomainName)) {
                $userSid = $null
                if ($userDomainName -match '\\') {
                    $parts = $userDomainName -split '\\'
                    $userSid = Get-UserSid -Domain $parts[0] -Username $parts[1]
                } else {
                    $userSid = Get-UserSid -Domain $null -Username $userDomainName
                }
                
                if ($ExcludeSids -contains $userSid) {
                    # Skip excluded users
                    continue
                }

                $idle = Get-SessionIdleSeconds -SessionId $sid
                if ($null -ne $idle -and $idle -ge $IdleThresholdSeconds) {
                    Write-EventLog -EventLog $EventLog -EventSource $EventSource -Eventid 101 -EntryType Information -Message "Idle threshold exceeded for user $userDomainName (Session $sid). Idle time: $idle seconds. Initiating logoff."                    
                    & "$env:SystemRoot\System32\logoff.exe" $sid
                }
            }
        }
    } catch {
        Write-EventLog -EventLog $EventLog -EventSource $EventSource -EventId 102 -EntryType Error -Message "Error in AutoLogoff loop: $_"
    }
    Start-Sleep -Seconds $CheckIntervalSeconds
}