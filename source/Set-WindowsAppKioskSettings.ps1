<# 
.SYNOPSIS
    This script creates a custom Windows App kiosk configuration designed to only allow the use of the Windows App.
    It uses a combination of Assigned Access policies, local group policy settings, provisioning packages, and registry edits to complete 
    the configuration. There are four major configuration scenarios:

    * Shell Launcher kiosk mode with Windows App as the dedicated application
    * Shell Launcher kiosk mode with Windows App as the dedicated application and automatic logon
    * Multi-app kiosk mode with restricted Start menu and taskbar access
    * Multi-app kiosk mode with restricted Start menu and taskbar access with automatic logon

    These options are controlled by the combination of the WindowsAppShell and AutoLogonKiosk switch parameters.
    
    When the WindowsAppShell switch parameter is not used, you can utilize the ShowSettings switch parameter to allow access to the Settings app.
    
    Additionally, you can choose to:

    * Provision the latest Windows App directly from the Microsoft download site so that it is installed for every user.
    * Configure automatic logoff behavior for the Windows App in automatic logon kiosk scenarios.
    * When not configured as an automatic logon kiosk:
        * Configure idle timeout behavior with automatic screen lock, user logoff, and system sleep escalation.
        * Monitor for smart card removals and perform lock or logoff actions.
        * Enable SharedPC mode for automatic profile cleanup.

.DESCRIPTION 
    This script completes a series of configuration tasks based on the parameters chosen. These tasks can include:

    * Assigned Access configuration for shell launcher or multi-app kiosk modes
    * Windows App provisioning from the Microsoft download site or via a local source file.
    * Automatic logoff and app reset configuration for Windows App
    * Multi-Local Group Policy configuration to limit interface elements and restrict access
    * Provisioning packages to Hide Start Menu elements and optionally enable SharedPC mode for automatic profile cleanup
    * Built-in application removal to reduce attack surface and speed logon.
    * Start menu and taskbar customization for multi-app kiosk scenarios
    * Smart card removal behavior configuration (lock or logoff)
    * Registry modifications to enforce kiosk behavior and settings

.NOTES 
    Author: Shawn Meyer, Microsoft
    Creation Date: 02/15/2023
    Last Modified: 12/1/2025
    Version: 2025.12.01.1
    
    The script will automatically remove older configurations by using -Reinstall which will run 'Remove-KioskSettings.ps1' during the install process.

.COMPONENT 
    No PowerShell modules required.

.LINK 
    https://www.github.com/azure/WindowsAppKiosk

.PARAMETER AutoLogonKiosk
This switch parameter determines If autologon is enabled through the Assigned Access configuration. The Assigned Access feature will automatically
create a new user - 'KioskUser0' - which will not have a password and be configured to automatically logon when Windows starts.

.PARAMETER WindowsAppAutoLogoffConfig
This string parameter determines the automatic logoff configuration for the Windows App when the AutoLogonKiosk switch parameter is used. The possible values are:
- Disabled - Disables automatic sign-out and app data reset for the Windows App. (Not RECOMMENDED for Kiosk scenarios)
- ResetAppOnCloseOnly - Sign all users out of Windows App and reset app data when the user closes the app.
- ResetAppAfterConnection - Sign all users out of Windows App and reset app data when a successful connection to an Azure Virtual Desktop session host or Windows 365 Cloud PC is made.
- ResetAppOnCloseOrIdle - Sign all users out of Windows App and reset app data when the operating system is idle for the specified time interval in minutes or the user closes the app.

.PARAMETER WindowsAppAutoLogoffTimeInterval
This integer value determines the interval at which Windows App checks the Windows OS for inactivity.
For example, if set to 5, the app will poll the OS for inactivity every 5 minutes and the logout process will initiate if the OS reports 5 or more minutes of inactivity. 

.PARAMETER WindowsAppShell
This switch parameter determines whether the Windows Shell is replaced by the Windows App or remains the default 'explorer.exe'.

.PARAMETER InstallWindowsApp
This switch parameter determines If the latest Remote Desktop client for Windows is automatically downloaded from the Internet and installed on the system prior to configuration.

.PARAMETER SharedPC
This switch parameter determines If the computer is setup as a shared PC. The account management process is enabled and all user profiles are automatically deleted on logoff.

.PARAMETER ShowSettings
This switch parameter determines If the Settings App appears on the start menu. The settings app and control panel are restricted to the applets/pages specified in the nonadmins-ShowSettings.txt file. If this value is not set,
then the Settings app and Control Panel are not displayed or accessible.

.PARAMETER IdleLockTimeoutMinutes
This integer value determines the number of minutes of idle time before the lock screen is displayed. This parameter is only valid when the AutoLogonKiosk switch parameter is not used. When used with other idle timeout parameters, this must be at least 15 minutes less than IdleLogoffTimeoutMinutes and IdleSleepTimeoutMinutes.

.PARAMETER SmartCardRemovalAction   
This string parameter determines what occurs when the smart card that was used to authenticate to the operating system is removed from the system. The possible values are 'Lock' or 'Logoff'.
When AutoLogon is true, this parameter cannot be used.

.PARAMETER ConfigureAutomaticMaintenance
This switch parameter determines if Windows automatic maintenance settings are configured via Local Group Policy. When enabled, maintenance tasks will run at the specified activation time with optional random delay.

.PARAMETER MaintenanceActivationTime
This string parameter specifies the time of day when automatic maintenance should begin in HH:mm:ss format (e.g., "02:00:00" for 2:00 AM). The time is converted to ISO 8601 format internally with date 2000-01-01T for policy application. Default is "00:00:00" (midnight).

.PARAMETER MaintenanceRandomDelay
This integer parameter specifies the maximum random delay in hours that can be added to the maintenance activation time to prevent multiple systems from running maintenance simultaneously. Valid values are 1-6 hours. The value is converted to ISO 8601 duration format (PT#H) internally. Default is 2 hours.

.PARAMETER SetPowerPolicies
This switch parameter determines if power management policies are configured via Local Group Policy to optimize behavior for shared PC scenarios. When enabled, configures power button, sleep button, and lid switch actions to sleep, enables energy saver settings, disables hibernation, and enables standby states while turning off hybrid sleep for both battery and plugged-in scenarios. Requires IdleSleepTimeoutMinutes parameter to be specified.

.PARAMETER IdleSleepTimeoutMinutes
This integer parameter specifies the number of minutes of user inactivity before the system automatically goes to sleep. This parameter is required when SetPowerPolicies is used and works in conjunction with it to manage power consumption in shared PC environments. When used with other idle timeout parameters, this must be at least 15 minutes greater than both IdleLockTimeoutMinutes and IdleLogoffTimeoutMinutes to ensure proper escalation sequence (lock → logoff → sleep).

.PARAMETER IdleLogoffTimeoutMinutes
This integer parameter specifies the number of minutes of user inactivity before an automatic logoff is triggered. Valid range is 1-1440 minutes (1 day). When specified, a scheduled task is created to monitor user activity and automatically log off users after the specified idle time. When used with other idle timeout parameters, this must be at least 15 minutes greater than IdleLockTimeoutMinutes and at least 15 minutes less than IdleSleepTimeoutMinutes.

.PARAMETER Reinstall
This switch parameter allows the script to be re-run on a system that has already been configured. It triggers the removal of existing kiosk settings before applying the new configuration.

.PARAMETER Version
This version parameter allows tracking of the installed version using configuration management software such as Microsoft Endpoint Manager or Microsoft Endpoint Configuration Manager by querying the value of the registry value: HKLM\Software\Kiosk\version.

#>
[CmdletBinding()]
param (
    [switch]$InstallWindowsApp,

    [Parameter(Mandatory, ParameterSetName = 'AutologonShellLauncher')]
    [Parameter(Mandatory, ParameterSetName = 'AutoLogonMultiAppKiosk')]
    [switch]$AutoLogonKiosk,

    [Parameter(Mandatory, ParameterSetName = 'AutologonShellLauncher')]
    [Parameter(Mandatory, ParameterSetName = 'AutoLogonMultiAppKiosk')]
    [ValidateSet('Disabled', 'ResetAppOnCloseOnly', 'ResetAppAfterConnection', 'ResetAppOnCloseOrIdle')]
    [string]$WindowsAppAutoLogoffConfig,

    [Parameter(Mandatory = $false, ParameterSetName = 'AutologonShellLauncher')]
    [Parameter(Mandatory = $false, ParameterSetName = 'AutoLogonMultiAppKiosk')]
    [int]$WindowsAppAutoLogoffTimeInterval,

    [Parameter(ParameterSetName = 'DirectLogonShellLauncher')]
    [Parameter(ParameterSetName = 'DirectLogonMultiAppKiosk')]
    [ValidateRange(5, 60)]    
    [int]$IdleLockTimeoutMinutes,
    
    [Parameter(ParameterSetName = 'DirectLogonShellLauncher')]
    [Parameter(ParameterSetName = 'DirectLogonMultiAppKiosk')]  
    [ValidateRange(5, 1440)]
    [int]$IdleLogoffTimeoutMinutes,

    [Parameter(ParameterSetName = 'DirectLogonShellLauncher')]
    [Parameter(ParameterSetName = 'DirectLogonMultiAppKiosk')]
    [switch]$SharedPC,

    [Parameter(ParameterSetName = 'AutoLogonMultiAppKiosk')]
    [Parameter(ParameterSetName = 'DirectLogonMultiAppKiosk')]
    [switch]$ShowSettings,

    [Parameter(Mandatory, ParameterSetName = 'AutologonShellLauncher')]
    [Parameter(Mandatory, ParameterSetName = 'DirectLogonShellLauncher')]
    [switch]$WindowsAppShell,

    [Parameter(ParameterSetName = 'DirectLogonShellLauncher')]
    [Parameter(ParameterSetName = 'DirectLogonMultiAppKiosk')]
    [ValidateSet('Lock', 'Logoff')]
    [string]$SmartCardRemovalAction,

    [Parameter()]
    [switch]$ConfigureAutomaticMaintenance,

    [Parameter()]
    [ValidateScript({
            if ($_ -match '^\d{2}:\d{2}:\d{2}$') {
                $timeSpan = [TimeSpan]::ParseExact($_, 'hh\:mm\:ss', $null)
                if ($timeSpan -ge [TimeSpan]::Zero -and $timeSpan -lt [TimeSpan]::FromHours(24)) {
                    return $true
                }
                throw "Time must be between 00:00:00 and 23:59:59"
            }
            throw "Time must be in HH:mm:ss format (e.g., 02:00:00, 14:30:00, 23:59:59)"
        })]
    [string]$MaintenanceActivationTime = '00:00:00',

    [Parameter()]
    [ValidateRange(0, 6)]
    [Int]$MaintenanceRandomDelay = 2,

    [Parameter()]
    [switch]$SetPowerPolicies,

    [Parameter()]
    [ValidateRange(30, 1440)]
    [int]$IdleSleepTimeoutMinutes,

    [Parameter()]
    [switch]$Reinstall,

    [version]$Version = '1.0.0'
)

If ($WindowsAppAutoLogoffConfig -eq 'ResetAppOnCloseOrIdle' -and $null -eq $WindowsAppAutoLogoffTimeInterval) {
    Throw "You must specify a value for 'WindowsAppAutoLogoffTimeInterval' when 'WindowsAppAutoLogoffConfig' = 'ResetAppOnCloseOrIdle'"
} 

If ($SetPowerPolicies -and $null -eq $IdleSleepTimeoutMinutes) {
    Throw "You must specify a value for 'IdleSleepTimeoutMinutes' when 'SetPowerPolicies' is used"
} 

# Validate idle timeout parameter ordering: IdleLockTimeout < IdleLogoffTimeout < IdleSleepTimeout
# Ensure minimum 15-minute gap between each timeout level
If ($IdleLockTimeoutMinutes -and $IdleLogoffTimeoutMinutes) {
    If ($IdleLogoffTimeoutMinutes -lt ($IdleLockTimeoutMinutes + 15)) {
        Throw "IdleLogoffTimeoutMinutes ($IdleLogoffTimeoutMinutes) must be at least 15 minutes greater than IdleLockTimeoutMinutes ($IdleLockTimeoutMinutes). Minimum required: $($IdleLockTimeoutMinutes + 15)"
    }
}

If ($IdleLogoffTimeoutMinutes -and $IdleSleepTimeoutMinutes) {
    If ($IdleSleepTimeoutMinutes -lt ($IdleLogoffTimeoutMinutes + 15)) {
        Throw "IdleSleepTimeoutMinutes ($IdleSleepTimeoutMinutes) must be at least 15 minutes greater than IdleLogoffTimeoutMinutes ($IdleLogoffTimeoutMinutes). Minimum required: $($IdleLogoffTimeoutMinutes + 15)"
    }
}

If ($IdleLockTimeoutMinutes -and $IdleSleepTimeoutMinutes) {
    If ($IdleSleepTimeoutMinutes -lt ($IdleLockTimeoutMinutes + 15)) {
        Throw "IdleSleepTimeoutMinutes ($IdleSleepTimeoutMinutes) must be at least 15 minutes greater than IdleLockTimeoutMinutes ($IdleLockTimeoutMinutes). Minimum required: $($IdleLockTimeoutMinutes + 15)"
    }
} 

# Restart in 64-Bit PowerShell if not already running in 64-bit mode
# primarily designed to support Microsoft Endpoint Manager application deployment
If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    $scriptArguments = $null
    Try {
        foreach ($k in $PSBoundParameters.keys) {
            switch ($PSBoundParameters[$k].GetType().Name) {
                "SwitchParameter" { If ($PSBoundParameters[$k].IsPresent) { $scriptArguments += "-$k " } }
                "String" { If ($PSBoundParameters[$k] -match '_') { $scriptArguments += "-$k `"$($PSBoundParameters[$k].Replace('_',' '))`" " } Else { $scriptArguments += "-$k `"$($PSBoundParameters[$k])`" " } }
                "String[]" { $ScriptArguments += "-$k `"$($PSBoundParameters[$k] -join '`",`"')`" " }
                "Int32" { $scriptArguments += "-$k $($PSBoundParameters[$k]) " }
                "Boolean" { $scriptArguments += "-$k `$$($PSBoundParameters[$k]) " }
                "Version" { $scriptArguments += "-$k `"$($PSBoundParameters[$k])`" " }
            }
        }
        If ($null -ne $scriptArguments) {
            $RunScript = Start-Process -FilePath "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -ArgumentList "-File `"$PSCommandPath`" $scriptArguments" -PassThru -Wait -NoNewWindow
        }
        Else {
            $RunScript = Start-Process -FilePath "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -ArgumentList "-File `"$PSCommandPath`"" -PassThru -Wait -NoNewWindow
        }
    }
    Catch {
        Throw "Failed to start 64-bit PowerShell"
    }
    Exit $RunScript.ExitCode
}

$Script:FullName = $MyInvocation.MyCommand.Path
$Script:Dir = Split-Path $Script:FullName
# Windows Event Log (.evtx)
$EventLog = 'Windows-App-Kiosk'
$EventSource = 'ConfigScript'
# Find LTSC OS (and Windows IoT Enterprise)
$OS = Get-WmiObject -Class Win32_OperatingSystem
[string]$FullOSVersion = [string]$OS.Version + '.' + (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR
# Detect Windows 11
If ($OS.Name -match 'LTSC') { $LTSC = $true }
# Source Directories and supporting files
$DirAppLocker = Join-Path -Path $Script:Dir -ChildPath "AppLocker"
$FileAppLockerClear = Join-Path -Path $DirAppLocker -ChildPath "ClearAppLockerPolicy.xml"
$DirApps = Join-Path -Path $Script:Dir -ChildPath 'Apps'
$DirAssignedAccess = Join-Path -Path $Script:Dir -ChildPath 'AssignedAccess'
$DirMultiAppSettings = Join-Path -Path $DirAssignedAccess -ChildPath 'MultiApp'
$DirProvisioningPackages = Join-Path -Path $Script:Dir -ChildPath 'ProvisioningPackages'
$DirShellLauncherSettings = Join-Path -Path $DirAssignedAccess -ChildPath 'ShellLauncher'
$DirGPO = Join-Path -Path $Script:Dir -ChildPath "GPOSettings"
$DirKiosk = Join-Path -Path $env:SystemDrive -ChildPath "KioskSettings"
$DirTools = Join-Path -Path $Script:Dir -ChildPath "Tools"
$DirUserLogos = Join-Path -Path $Script:Dir -ChildPath "UserLogos"
$DirFunctions = Join-Path -Path $Script:Dir -ChildPath "Scripts\Functions"
$DirSchedTasksScripts = Join-Path -Path $Script:Dir -ChildPath "Scripts\ScheduledTasks"


#region Parameter Conversions

# Convert MaintenanceRandomDelay integer to PT4H format
$MaintenanceRandomDelayPT = "PT$($MaintenanceRandomDelay)H"

# Convert MaintenanceActivationTime to ISO 8601 format with date 2000-01-01T
$MaintenanceActivationTimeISO = "2000-01-01T$MaintenanceActivationTime"

#endregion Parameter Conversions
    
#region Load Functions

If (Test-Path -Path $DirFunctions) {
    $Functions = Get-ChildItem -Path $DirFunctions -Filter '*.ps1'
    ForEach ($Function in $Functions) {
        Try {
            . "$($Function.FullName)"
        }
        Catch {
            Write-Error "Failed to load function from $($Function.FullName): $($_.Exception.Message)"
            Exit 1
        }
    }
}
Else {
    Write-Error "Functions directory not found at: $DirFunctions"
    Exit 1
}

#endregion Functions

#region Initialization

If (-not [System.Diagnostics.EventLog]::SourceExists($EventSource) -or -not [System.Diagnostics.EventLog]::Exists($EventLog)) {
    Write-Verbose "Creating $EventLog | $EventSource log..."
    New-EventLog -LogName $EventLog -Source $EventSource -ErrorAction SilentlyContinue
    Do {
        Start-Sleep -Seconds 1
    } Until ([System.Diagnostics.EventLog]::SourceExists($EventSource) -and [System.Diagnostics.EventLog]::Exists($EventLog))
}

$message = @"
Starting Windows App Kiosk Configuration Script
Script Full Name: $($Script:FullName)
Parameters:
    $($PSBoundParameters | Out-String)
Running on: $($OS.Caption) version $FullOSVersion
"@
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 1 -Message $message

If (Get-PendingReboot) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Warning -EventId 0 -Message "There is a reboot pending. This application cannot be installed when a reboot is pending.`nRebooting the computer in 15 seconds."
    Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r /t 15' -NoNewWindow
    Exit
}

# Copy lgpo to system32 for future use.
Copy-Item -Path "$DirTools\lgpo.exe" -Destination "$env:SystemRoot\System32" -Force

#endregion Initialization

#region Remove Previous Versions
If ($Reinstall) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 2 -Message "Reinstall switch detected. Existing kiosk settings will be removed before applying new configuration."
    & "$Script:Dir\Remove-KioskSettings.ps1" -Reinstall
}
#endregion Previous Version Removal

#region Remove Apps

# Remove Built-in Windows 11 Apps on non LTSC builds of Windows
If (-not $LTSC) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 25 -Message "Starting Remove Apps Script."
    Remove-BuiltInApps
}
# Remove OneDrive
If (Test-Path -Path "$env:SystemRoot\Syswow64\onedrivesetup.exe") {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 26 -Message "Removing Per-User installation of OneDrive."
    Start-Process -FilePath "$env:SystemRoot\Syswow64\onedrivesetup.exe" -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
    $OneDrivePresent = $true
}
ElseIf (Test-Path -Path "$env:ProgramFiles\Microsoft OneDrive") {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 26 -Message "Removing Per-Machine Installation of OneDrive."
    $OneDriveSetup = Get-ChildItem -Path "$env:ProgramFiles\Microsoft OneDrive" -Filter 'onedrivesetup.exe' -Recurse
    If ($OneDriveSetup) {
        Start-Process -FilePath $OneDriveSetup[0].FullName -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
        $OneDrivePresent = $true
    }
}

#endregion Remove Apps

#region Install Windows App

If ($InstallWindowsApp) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 31 -Message "Running Script to install or update the Windows App."
    & "$DirApps\WindowsApp\Deploy-WindowsApp.ps1"
}

#endregion Install Windows App

#region KioskSettings Directory

#Create the KioskSettings Directory
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 40 -Message "Creating KioskSettings Directory at root of system drive."
If (-not (Test-Path $DirKiosk)) {
    New-Item -Path $DirKiosk -ItemType Directory -Force | Out-Null
}

# Setting ACLs on the Kiosk Settings directory to prevent Non-Administrators from changing files. Defense in Depth.
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 41 -Message "Configuring Kiosk Directory ACLs"
$AdminsSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$Group = $AdminsSID.Translate([System.Security.Principal.NTAccount])
$ACL = Get-ACL $DirKiosk
$ACL.SetOwner($Group)
Set-ACL -Path $DirKiosk -AclObject $ACL
Update-ACL -Path $DirKiosk -Identity 'S-1-5-32-544' -FileSystemRights 'FullControl' -Type 'Allow'
Update-ACL -Path $DirKiosk -Identity 'S-1-5-32-545' -FileSystemRights 'ReadAndExecute' -Type 'Allow'
Update-ACL -Path $DirKiosk -Identity 'S-1-5-18' -FileSystemRights 'FullControl' -Type 'Allow'
Update-ACLInheritance -Path $DirKiosk -DisableInheritance $true -PreserveInheritedACEs $false

#endregion KioskSettings Directory

#region Assigned Access Configuration

Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 50 -Message "Starting Assigned Access Configuration Section."
If ($WindowsAppShell) {
    If ($AutoLogonKiosk) {
        $ConfigFile = Join-Path -Path $DirShellLauncherSettings -ChildPath "WindowsApp_AutoLogon.xml"
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 51 -Message "Enabling Windows App Shell Launcher with Autologon via WMI MDM bridge. This could take several minutes."
    }
    Else {
        $ConfigFile = Join-Path -Path $DirShellLauncherSettings -ChildPath "WindowsApp.xml"
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 51 -Message "Enabling Windows App Shell Launcher via WMI MDM bridge. This could take several minutes."
    }
    $DestFile = Join-Path -Path $DirKiosk -ChildPath "AssignedAccessShellLauncher.xml"
    Copy-Item -Path $ConfigFile -Destination $DestFile -Force
    Set-AssignedAccessShellLauncher -FilePath $DestFile
    $ShellLauncher = Get-AssignedAccessShellLauncher
    $FormattedShellLauncher = Format-OutputXml -Configuration $ShellLauncher
    If ($ShellLauncher) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 52 -Message "Shell Launcher configuration successfully applied.`n-----BEGIN CONFIGURATION-----`n$FormattedShellLauncher`n-----END CONFIGURATION-----"
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Error -EventId 53 -Message "Shell Launcher configuration failed. Computer should be restarted first."
        Exit 1618
    }
}
Else {
    If ($AutoLogonKiosk) {
        If ($ShowSettings) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 55 -Message "Configuring MultiApp Kiosk settings for Windows App with Settings and Autologon."
            $ConfigFile = Join-Path -Path $DirMultiAppSettings -ChildPath "WindowsApp_Settings_AutoLogon.xml"
        }
        Else {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 56 -Message "Configuring MultiApp Kiosk settings for Windows App and Autologon."
            $ConfigFile = Join-Path -Path $DirMultiAppSettings -ChildPath "WindowsApp_AutoLogon.xml"
        }
    }
    Else {
        If ($ShowSettings) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 56 -Message "Configuring MultiApp Kiosk settings for Windows App and Settings."
            $ConfigFile = Join-Path -Path $DirMultiAppSettings -ChildPath "WindowsApp_Settings.xml"
        }
        Else {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 56 -Message "Configuring MultiApp Kiosk settings for Windows App."
            $ConfigFile = Join-Path -Path $DirMultiAppSettings -ChildPath "WindowsApp.xml"
        }
    }  
    $DestFile = Join-Path $DirKiosk -ChildPath 'AssignedAccessConfiguration.xml'
    Copy-Item -Path $ConfigFile -Destination $DestFile -Force
    Set-AssignedAccessConfiguration -FilePath $DestFile
    $Configuration = Get-AssignedAccessConfiguration
    If ($Configuration) {
        $FormattedConfiguration = Format-OutputXml -Configuration $Configuration
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 57 -Message "Assigned Access configuration successfully applied.`n-----BEGIN CONFIGURATION-----`n$FormattedConfiguration`n-----END CONFIGURATION-----"
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Error -EventId 58 -Message "Assigned Access configuration failed. Computer should be restarted first."
        Exit 1618        
    }  
}

#endregion Assigned Access Launcher

#region Provisioning Packages

$ProvisioningPackages = @()

$ProvisioningPackages += [PSCustomObject]@{
    Name    = 'DisableWindowsSpotlight.ppkg'
    Purpose = "Disable Windows Spotlight features to prevent unwanted content on lock screen and optimize performance"
}

If ($SharedPC) {
    $ProvisioningPackages += [PSCustomObject]@{
        Name    = 'SharedPC.ppkg'
        Purpose = "Enable SharedPC mode for automatic profile cleanup and direct logon"
    }
}
Else {
    # These settings are already included in the SharedPC provisioning package, so only add it when not using SharedPC mode.
    $ProvisioningPackages += [PSCustomObject]@{
        Name    = 'DisableFirstLogonAnimation.ppkg'
        Purpose = "Disable first sign-in animation to speed up initial logon"
    }
    $ProvisioningPackages += [PSCustomObject]@{
        Name    = 'DisableAdvertisingId.ppkg'
        Purpose = "Disable advertising ID for privacy and to prevent targeted ads"
    }
}

If (!$WindowsAppShell) {
    $ProvisioningPackages += [PSCustomObject]@{
        Name    = 'HideStartMenuElements.ppkg'
        Purpose = "Hide Start Menu elements to reduce interface complexity in kiosk mode"
    }
}

New-Item -Path "$DirKiosk\ProvisioningPackages" -ItemType Directory -Force | Out-Null
ForEach ($Package in $ProvisioningPackages) {
    $SourcePath = Join-Path -Path $DirProvisioningPackages -ChildPath $Package.Name
    $DestPath = Join-Path -Path $DirKiosk -ChildPath "ProvisioningPackages\$($Package.Name)"
    Copy-Item -Path $SourcePath -Destination $DestPath -Force | Out-Null
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventID 65 -Message "Installing $($Package.Name). Purpose: $($Package.Purpose)"
    Install-ProvisioningPackage -PackagePath $DestPath -ForceInstall -QuietInstall
}

#endregion Provisioning Packages

#region Local GPO Settings

if ($WindowsAppShell) {
    $null = cmd /c lgpo.exe /t "$DirGPO\Ctrl+Alt+Del-HideTaskManager.txt" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Disabled Task Manager via Local Group Policy Non-Administrators Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    $null = cmd /c lgpo.exe /t "$DirGPO\HideAndRestrictDrives.txt" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Hid and restricted access to drives via Local Group Policy Non-Administrators Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    if ($AutoLogonKiosk) {
        $null = cmd /c lgpo.exe /t "$DirGPO\Ctrl+Alt+Del-HideLock-HideSignOut-HideSwitchUser.txt" '2>&1'
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Removed logoff, change password, lock workstation, and fast user switching entry points via Local Group Policy Non-Administrators Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    }
    If (!$SharedPC) {
        $null = cmd /c lgpo.exe /t "$DirGPO\DisablePrivacyExperience.txt" '2>&1'
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Disabled the First Logon Privacy Experience via the Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    }
}
Else {
    $null = cmd /c lgpo.exe /t "$DirGPO\HideWindowsSecurityControl.txt" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Hide Windows Security notification area control via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    If ($ShowSettings) {
        $null = cmd /c lgpo.exe /t "$DirGPO\RestrictControlPanelAndSettings.txt" '2>&1'
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Restricted Settings App and Control Panel to allow only Display Settings for kiosk user via Local Group Policy Non-Administrators Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    }
    If ($AutoLogonKiosk) {
        $null = cmd /c lgpo.exe /t "$DirGPO\Ctrl+Alt+Del-HideLock.txt" '2>&1'
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Removed Lock from the CTRL+ALT+DEL screen via Local Group Policy Non-Administrators Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    }
}

If ($AutoLogonKiosk) {
    $null = cmd /c lgpo.exe /t "$DirGPO\DisablePasswordForUnlock.txt" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Disabled password requirement for screen saver lock and wake from sleep via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    # Configure User Logos
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 70 -Message "Starting User Logo configuration."
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 71 -Message "Backing up current User Logo files to '$DirKiosk\UserLogos'."
    Copy-Item -Path "$env:ProgramData\Microsoft\User Account Pictures" -Destination "$DirKiosk\UserLogos" -Force
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 72 -Message "Copying User Logo files to '$env:ProgramData\Microsoft\User Account Pictures'."
    Get-ChildItem -Path $DirUserLogos | Copy-Item -Destination "$env:ProgramData\Microsoft\User Account Pictures" -Force
    # Configure User Logos to use default images
    $null = cmd /c lgpo.exe /t "$DirGPO\UserLogosDefault.txt" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 70 -Message "Configured User Logos to use default via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
}
Else {
    If ($SmartCardRemovalAction) {
        # Ensure Smart Card Removal Policy service is running and set to automatic
        $SCPolicyService = Get-Service -Name 'SCPolicySvc' -ErrorAction Stop
        If ($SCPolicyService.StartType -ne 'Automatic') {
            Set-Service -Name 'SCPolicySvc' -StartupType Automatic
            Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Smart Card Removal Policy service startup type set to Automatic."
        }           
    }
    If ($SmartCardRemovalAction -eq 'Lock') {
        $null = cmd /c lgpo /s "$DirGPO\SmartCardLockWorkstation.inf" '2>&1'
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Set 'Interactive logon: Smart Card Removal behavior' to 'Lock Workstation' via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    }
    ElseIf ($SmartCardRemovalAction -eq 'Logoff') {
        $null = cmd /c lgpo /s "$DirGPO\SmartCardLogOffWorkstation.inf" '2>&1'
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Set 'Interactive logon: Smart Card Removal behavior' to 'Force Logoff Workstation' via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    }
    If ($IdleLockTimeoutMinutes) {
        # Will lock the system via the inactivity timeout built-in policy which locks the screen after inactivity.
        $sourceFile = Join-Path -Path $DirGPO -ChildPath 'MachineInactivityTimeout.inf'
        $outFile = Join-Path -Path "$env:SystemRoot\SystemTemp" -ChildPath 'MachineInactivityTimeout.inf'
        (Get-Content -Path $SourceFile).Replace('<Seconds>', ($IdleLockTimeoutMinutes * 60)) | Out-File $OutFile
        $null = cmd /c lgpo /s "$outFile" '2>&1'
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Set 'Interactive logon: Machine inactivity limit' to '$($IdleLockTimeoutMinutes * 60) seconds' via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
        Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue
    }
}

If ($ConfigureAutomaticMaintenance) {
    # Configure Automatic Maintenance settings via Local Group Policy
    $sourceFile = Join-Path -Path $DirGPO -ChildPath 'AutomaticMaintenance.txt'
    $outFile = Join-Path -Path "$env:SystemRoot\SystemTemp" -ChildPath 'AutomaticMaintenance.txt'
    
    If ($MaintenanceRandomDelay -eq 0) {
        # No random delay - just replace activation boundary
        ((Get-Content -Path $SourceFile).Replace('<ActivationBoundary>', $MaintenanceActivationTimeISO)) | Out-File $OutFile
    }
    Else {
        # Include random delay - replace both values and add randomized setting
        $content = (Get-Content -Path $SourceFile).Replace('<ActivationBoundary>', $MaintenanceActivationTimeISO)
        $content += @(
            '',
            'Computer',
            'Software\Policies\Microsoft\Windows\Task Scheduler\Maintenance',
            'Randomized',
            'DWORD:1',
            '',
            'Computer',
            'Software\Policies\Microsoft\Windows\Task Scheduler\Maintenance',
            'RandomDelay',
            "SZ:$MaintenanceRandomDelayPT"
        )
        $content | Out-File $OutFile
    }    
    $null = cmd /c lgpo /s "$outFile" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Configured Automatic Maintenance settings via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue
}

If ($SetPowerPolicies) {
    # Configure Power Settings via Local Group Policy
    $sourceFile = Join-Path -Path $DirGPO -ChildPath 'PowerSettings.txt'
    $outFile = Join-Path -Path "$env:SystemRoot\SystemTemp" -ChildPath 'PowerSettings.txt'
    (Get-Content -Path $SourceFile).Replace('<SleepTimeOut>', ($IdleSleepTimeoutMinutes * 60)) | Out-File $OutFile
    $null = cmd /c lgpo /s "$outFile" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Configured Power Settings with idle sleep timeout = $IdleSleepTimeoutMinutes minutes via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue
}

#endregion Local GPO Settings

#region Registry Edits

# Import registry keys file
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 90 -Message "Setting Registry Keys."
$RegValues = @()

$RegValues += [PSCustomObject]@{
    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin'
    Name         = 'BlockAADWorkplaceJoin'
    PropertyType = 'DWord'
    Value        = 1
    Description  = 'Disable "Stay Signed in to all your apps" pop-up'
}

If ($OneDrivePresent) {
    # Remove OneDrive from starting for each user.
    $RegValues += [PSCustomObject]@{
        Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        Name         = 'OneDriveSetup'
        PropertyType = 'String'
        Value        = ''
        Description  = 'Remove OneDriveSetup from starting for each user.'
    }
}

If (!$WindowsAppShell) {
    $RegValues += [PSCustomObject]@{
        Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Name         = 'StartShownOnUpgrade'
        PropertyType = 'DWord'
        Value        = 1
        Description  = 'Disable Start Menu from opening automatically'
    }
}

if (($AutoLogonKiosk -and $WindowsAppAutoLogoffConfig -ne 'Disabled') -or $SharedPC) {
    # Streamline the user experience by disabling First Run Experience
    # https://learn.microsoft.com/en-us/windows-app/windowsautologoff#skipfre
    $RegValues += [PSCustomObject]@{
        Path         = 'HKLM:\SOFTWARE\Microsoft\Windows365'
        Name         = 'SkipFRE'
        PropertyType = 'DWord'
        Value        = 1
        Description  = 'Disable First Run Experience in Windows App'
    }
}

If ($AutoLogonKiosk) {
    #Configure AutoLogoff for the Windows App
    #https://learn.microsoft.com/en-us/windows-app/windowsautologoff
    Switch ($WindowsAppAutoLogoffConfig) {
        'ResetAppOnCloseOnly' {
            $RegValues += [PSCustomObject]@{
                Path         = 'HKLM:\SOFTWARE\Microsoft\WindowsApp'
                Name         = 'AutoLogoffEnable'
                PropertyType = 'DWORD'
                Value        = 1
                Description  = 'Sign all users out of Windows App and reset app data when the user closes the app.'
            }
        }
        'ResetAppAfterConnection' {
            $RegValues += [PSCustomObject]@{
                Path         = 'HKLM:\SOFTWARE\Microsoft\WindowsApp'
                Name         = 'AutoLogoffOnSuccessfulConnect'
                PropertyType = 'DWord'
                Value        = 1
                Description  = 'Sign all users out of Windows App and reset app data when a successful connection to an Azure Virtual Desktop session host or Windows 365 Cloud PC is made.'
            }
        }
        'ResetAppOnCloseOrIdle' {
            $RegValues += [PSCustomObject]@{
                Path         = 'HKLM:\SOFTWARE\Microsoft\WindowsApp'
                Name         = 'AutoLogoffTimeInterval'
                PropertyType = 'DWord'
                Value        = $WindowsAppAutoLogoffTimeInterval
                Description  = 'Sign all users out of Windows App and reset app data when the operating system is idle for the specified time interval in minutes or the user closes the app.'
            }     
        }
    }
}

# create the reg key restore file if it doesn't exist, else load it to compare for appending new rows.
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 97 -Message "Creating a Registry key restore file for Kiosk Mode uninstall."
$FileRestore = "$DirKiosk\RegKeyRestore.csv"
New-Item -Path $FileRestore -ItemType File -Force | Out-Null
Add-Content -Path $FileRestore -Value 'Path,Name,PropertyType,Value,Description'

# Check if any registry keys require HKCU access before loading the hive     
If ($RegValues | Where-Object { $_.Path -like 'HKCU:*' }) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 11 -EntryType Information -Message "Loading Default User Hive for HKCU registry operations."
    Start-Process -FilePath "REG.exe" -ArgumentList "LOAD", "HKLM\Default", "$env:SystemDrive\Users\default\ntuser.dat" -Wait
}

# Loop through the registry key file and perform actions.
ForEach ($Entry in $RegValues) {
    #reset from previous values
    $Path = $null
    $Name = $null
    $PropertyType = $null
    $Value = $null
    $Description = $Null
    $PathHKLM = $Null
    #set values
    $Path = $Entry.Path
    $Name = $Entry.Name
    $PropertyType = $Entry.PropertyType
    $Value = $Entry.Value
    $Description = $Entry.Description
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 99 -Message "Processing Registry Value to '$Description'."

    If ($Path -like 'HKCU:*') {
        $PathHKLM = $Path.Replace("HKCU:\", "HKLM:\Default\")
    }
    Else {
        $PathHKLM = $Path
    }
    $CurrentRegValue = $null
    If (Get-ItemProperty -Path $PathHKLM -Name $Name -ErrorAction SilentlyContinue) {
        $CurrentRegValue = Get-ItemPropertyValue -Path $PathHKLM -Name $Name
        Add-Content -Path $FileRestore -Value "$Path,$Name,$PropertyType,$CurrentRegValue"
    }
    Else {
        Add-Content -Path $FileRestore -Value "$Path,$Name,,"
    }

    If ($Value -ne '' -and $null -ne $Value) {
        # This is a set action
        Set-RegistryValue -Path $PathHKLM -Name $Name -PropertyType $PropertyType -Value $Value       
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 100 -Message "Setting '$PropertyType' Value '$Name' with Value '$Value' to '$Path'"
    }
    Elseif ($CurrentRegValue) {     
        Remove-ItemProperty -Path $PathHKLM -Name $Name -ErrorAction SilentlyContinue
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 102 -Message "Deleted Value '$Name' from '$Path'."
    }               
}    

If (Test-Path -Path 'HKLM:\Default') {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 103 -Message "Unloading Default User Hive Registry Keys via Reg.exe."
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    Start-Sleep -Seconds 5
    $null = cmd /c REG UNLOAD "HKLM\Default" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 104 -Message "Reg.exe Exit Code: [$LastExitCode]"
}

#endregion Registry Edits

#region AppLocker Configuration

If ($WindowsAppShell) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 120 -Message "Applying AppLocker Policy to disable Edge, Notepad, and Search for the Kiosk User."
    # If there is an existing applocker policy, back it up and store its XML for restore.
    # Else, copy a blank policy to the restore location.
    # Then apply the new AppLocker Policy
    $FileAppLockerKiosk = Join-Path -Path $DirAppLocker -ChildPath "ShellLauncher.xml"

    [xml]$Policy = Get-ApplockerPolicy -Local -XML
    If ($Policy.AppLockerPolicy.RuleCollection) {
        Get-ApplockerPolicy -Local -XML | out-file "$DirKiosk\ApplockerPolicy.xml" -force
    }
    Else {
        Copy-Item -Path $FileAppLockerClear -Destination "$DirKiosk\ApplockerPolicy.xml" -Force
    }
    Set-AppLockerPolicy -XmlPolicy $FileAppLockerKiosk
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 121 -Message "Enabling and Starting Application Identity Service"
    Set-Service -Name AppIDSvc -StartupType Automatic -ErrorAction SilentlyContinue
}

#endregion AppLocker Configuration

#region Keyboard Filter
$SchedTasksScriptsDir = Join-Path -Path $DirKiosk -ChildPath 'ScheduledTasksScripts'

if ($WindowsAppShell) {
    If (-not (Test-Path -Path $SchedTasksScriptsDir)) {
        New-Item -Path $SchedTasksScriptsDir -ItemType Directory -Force | Out-Null
    }
    $TaskScriptName = 'Set-KeyboardFilterConfiguration.ps1'
    Copy-Item -Path (Join-Path -Path $DirSchedTasksScripts -ChildPath $TaskScriptName) -Destination $SchedTasksScriptsDir -Force
    $TaskScriptFullName = Join-Path -Path $SchedTasksScriptsDir -ChildPath $TaskScriptName
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventID 125 -Message "Enabling Keyboard filter."
    Enable-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter -All -NoRestart
    # Configure Keyboard Filter after reboot
    $TaskName = "Windows-App-Kiosk - Configure Keyboard Filter"
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 126 -Message "Creating Scheduled Task: '$TaskName'."
    $TaskScriptEventSource = 'Keyboard Filter Configuration'
    $TaskDescription = "Configures the Keyboard Filter"
    New-EventLog -LogName $EventLog -Source $TaskScriptEventSource -ErrorAction SilentlyContinue     
    $TaskTrigger = New-ScheduledTaskTrigger -AtStartup
    $TaskScriptArgs = "-TaskName `"$TaskName`" -EventLog `"$EventLog`" -EventSource `"$TaskScriptEventSource`""
    $TaskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-executionpolicy bypass -file $TaskScriptFullName $TaskScriptArgs"
    $TaskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $TaskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $TaskAction -Settings $TaskSettings -Principal $TaskPrincipal -Trigger $TaskTrigger
    If (Get-ScheduledTask | Where-Object { $_.TaskName -eq "$TaskName" }) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 119 -Message "Scheduled Task created successfully."
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Error -EventId 120 -Message "Scheduled Task not created."
        Exit 1618
    }
}

#endregion Keyboard Filter

#region Idle Logoff User Task

# Create User-based Idle Logoff Task if IdleLogoffTimeoutMinutes is specified
If ($IdleLogoffTimeoutMinutes) {
    If (-not (Test-Path -Path $SchedTasksScriptsDir)) {
        New-Item -Path $SchedTasksScriptsDir -ItemType Directory -Force | Out-Null
    }
    $TaskScriptName = 'Logoff-InactiveUsers.ps1'
    Copy-Item -Path (Join-Path -Path $DirSchedTasksScripts -ChildPath $TaskScriptName) -Destination $SchedTasksScriptsDir -Force
    $TaskScriptFullName = Join-Path -Path $SchedTasksScriptsDir -ChildPath $TaskScriptName
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventID 125 -Message "Enabling Automatic Logoff on Idle Scheduled Task"
    $TaskName = "Windows-App-Kiosk - Logoff Idle Users"
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 126 -Message "Creating Scheduled Task: '$TaskName'."
    $TaskDescription = "Automatically Logs off any idle users after a set period"
    $TaskTrigger = New-ScheduledTaskTrigger -AtLogon
    $TaskScriptArgs = "-IdleThresholdMinutes $IdleLogoffTimeoutMinutes"
    $TaskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-executionpolicy bypass -file $TaskScriptFullName $TaskScriptArgs"
    $TaskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    # Set ExecutionTimeLimit to 0 (Infinite) so the task doesn't stop after 3 days (default)
    # Add RestartCount to ensure resilience if the script crashes
    $TaskSettings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $TaskAction -Settings $TaskSettings -Principal $TaskPrincipal -Trigger $TaskTrigger
    If (Get-ScheduledTask | Where-Object { $_.TaskName -eq "$TaskName" }) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 119 -Message "Scheduled Task created successfully."
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Error -EventId 120 -Message "Scheduled Task not created."
        Exit 1618
    }
}
#endregion Idle Logoff User Task

Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 150 -Message "Updating Group Policy"
$GPUpdate = Start-Process -FilePath 'GPUpdate' -ArgumentList '/force' -Wait -PassThru
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventID 151 -Message "GPUpdate Exit Code: [$($GPUpdate.ExitCode)]"
$null = cmd /c reg add 'HKLM\Software\Kiosk' /v Version /d "$($Version.ToString())" /t REG_SZ /f
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 199 -Message "Ending Kiosk Mode Configuration version '$($Version.ToString())' with Exit Code: 3010"
Exit 3010
