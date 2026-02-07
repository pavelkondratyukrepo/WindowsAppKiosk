# Windows App Kiosk - Implementation Guide

**Navigation:** [Overview](README.md) | [Solution Overview](SOLUTION_OVERVIEW.md) | Implementation Guide | [Intune Deployment](INTUNE_DEPLOYMENT.md) | [Advanced Customizations](ADVANCED_CUSTOMIZATIONS.md)

---

## Table of Contents

- [Windows App Kiosk - Implementation Guide](#windows-app-kiosk---implementation-guide)
  - [Table of Contents](#table-of-contents)
  - [Parameters](#parameters)
    - [Idle Timeout Dependencies](#idle-timeout-dependencies)
  - [Manual Installation](#manual-installation)
  - [Manual Removal](#manual-removal)
  - [Troubleshooting](#troubleshooting)
    - [Emergency Access](#emergency-access)
    - [Logging and Diagnostics](#logging-and-diagnostics)
    - [Common Issues](#common-issues)
    - [Configuration Verification](#configuration-verification)

## Parameters

The table below describes each parameter and any requirements or usage information.

**Table 1:** Set-WindowsAppKioskSettings.ps1 Parameters

| Parameter Name | Type | Description | Notes/Requirements |
| :------------- | :--: | :---------- | :----------------- |
| `AutoLogonKiosk` | Switch | Determines if autologon is enabled through the Assigned Access configuration. | When configured, Windows will automatically create a new user, 'KioskUser0', which will <u>not</u> have a password and be configured to automatically logon when Windows starts. |
| `WindowsAppShell` | Switch | Determines whether to configure shell launcher kiosk mode with Windows App as the only available application. | When not specified, multi-app kiosk mode is used with a restricted Start menu. |
| `WindowsAppAutoLogoffConfig` | String | Determines the automatic logoff configuration for the Windows App when AutoLogonKiosk is used. | Possible values: 'Disabled', 'ResetAppOnCloseOnly', 'ResetAppAfterConnection', 'ResetAppOnCloseOrIdle'. Required when AutoLogonKiosk is specified. |
| `WindowsAppAutoLogoffTimeInterval` | Int | Determines the interval in minutes at which Windows App checks for OS inactivity. | Required when WindowsAppAutoLogoffConfig is 'ResetAppOnCloseOrIdle'. |
| `InstallWindowsApp` | Switch | Determines if the latest Windows App is automatically downloaded and provisioned on the system prior to configuration. | Supports both online (automatic download) and offline installation methods. For offline/air-gapped environments, see the README file in `Apps\WindowsApp\` folder for instructions on placing the local MSIX file. When a local MSIX file is present, no internet connection is required. |
| `SharedPC` | Switch | Determines if the computer is setup as a shared PC with automatic profile cleanup after logoff. | Only valid for direct logon mode (i.e., The `AutoLogonKiosk` switch is not used). |
| `ShowSettings` | Switch | Determines if the Settings App appears in the restricted interface, limited to display and audio settings. | Only valid when `WindowsAppShell` is not specified. |
| `IdleLockTimeoutMinutes` | Int | Determines the number of minutes of idle time before the lock screen is displayed. | Only valid when `AutoLogonKiosk` is not used. Valid range: 5-60 minutes. See [Idle Timeout Dependencies](#idle-timeout-dependencies) below for ordering requirements. |
| `IdleLogoffTimeoutMinutes` | Int | Determines the number of minutes after screen lock before the user is logged off automatically. | Only valid when `AutoLogonKiosk` is not used. **Requires** `IdleLockTimeoutMinutes` to be specified. Valid range: 5-180 minutes. See [Idle Timeout Dependencies](#idle-timeout-dependencies) below for ordering requirements. |
| `SmartCardRemovalAction` | String | Determines what occurs when the smart card used for authentication is removed. | Possible values: 'Lock', 'Logoff'. Cannot be used when `AutoLogonKiosk` is true. |
| `ConfigureAutomaticMaintenance` | Switch | Determines if Windows automatic maintenance settings are configured via Local Group Policy. | When enabled, maintenance tasks will run at the specified time with optional random delay. [^1] |
| `MaintenanceActivationTime` | String | Specifies the time of day when automatic maintenance should begin in HH:mm:ss format. | Example: "02:00:00" for 2:00 AM. Default is "00:00:00" (midnight). [^1] |
| `MaintenanceRandomDelay` | Int | Specifies the maximum random delay in hours added to the maintenance activation time. | Valid values are 0-6 hours. Prevents multiple systems from running maintenance simultaneously. Default is 2 hours. [^1] |
| `SetPowerPolicies` | Switch | Determines if power management policies are configured via Local Group Policy for shared PC scenarios. | Configures power buttons, sleep settings, energy saver, disables hibernation. **Requires** `IdleSleepTimeoutMinutes` parameter. [^2] |
| `IdleSleepTimeoutMinutes` | Int | Determines the number of minutes of user inactivity before the system automatically goes to sleep. | Required when `SetPowerPolicies` is used. Valid range: 30-1440 minutes. See [Idle Timeout Dependencies](#idle-timeout-dependencies) below for ordering requirements. [^3] |
| `Reinstall` | Switch | Allows the script to be re-run on a system that has already been configured. | Triggers removal of existing kiosk settings before applying new configuration. |
| `Version` | Version | Writes this value to HKLM:\SOFTWARE\Kiosk\version registry key. | Allows tracking of the installed version using configuration management software. Default is '1.0.0'. |

### Idle Timeout Dependencies

The idle timeout parameters have specific dependencies and minimum time gaps to ensure proper escalation behavior. The following table outlines these requirements:

**Table 2:** Idle Timeout Parameter Dependencies

| Parameter | Depends On | Minimum Gap | Behavior |
|:----------|:-----------|:------------|:---------|
| `IdleLockTimeoutMinutes` | None | N/A | Locks the workstation after specified minutes of inactivity. |
| `IdleLogoffTimeoutMinutes` | **Requires** `IdleLockTimeoutMinutes` | Must be at least **15 minutes greater** than `IdleLockTimeoutMinutes` | Triggers a scheduled task when the screen locks. After the time difference (IdleLogoffTimeoutMinutes - IdleLockTimeoutMinutes) passes while the session remains locked, the user is logged off. If the user unlocks before the timer expires, logoff is canceled. |
| `IdleSleepTimeoutMinutes` | **Requires** `SetPowerPolicies` switch | Must be at least **15 minutes greater** than `IdleLogoffTimeoutMinutes` (if used), or **15 minutes greater** than `IdleLockTimeoutMinutes` (if no logoff configured) | Puts the system to sleep after specified minutes of inactivity. |

**Idle Timeout Escalation Timeline:**

The diagram below illustrates how the idle timeouts escalate over time when all three parameters are configured as follows:

- IdleLockTimeoutMinutes = 15
- IdleLockTimeoutMnutes = 30
- IdleSleepTimeoutMinutes = 60

```
User Activity Stops
        |
        v
    [Active Session]
        |
        | (IdleLockTimeoutMinutes = 15 min)
        |
        v
    [🔒 SCREEN LOCKS] (Total: 15 mins from inactivity)
        |
        | Screen remains locked for
        | (IdleLogoffTimeoutMinutes - IdleLockTimeoutMinutes = 15 min)
        | 
        | ⚠️  User can unlock anytime during this period to cancel logoff
        |
        v
    [👤 USER LOGGED OFF] (Total: 30 min from inactivity)
        |
        | System continues idle for
        | (IdleSleepTimeoutMinutes - IdleLogoffTimeoutMinutes = 30 min)
        |
        v
    [💤 SYSTEM SLEEPS] (Total: 60 min from inactivity)
```

**Key Points:**

- All timings are measured from when user activity stops
- Lock → Logoff: Scheduled task monitors for unlock events
- If user unlocks during the logoff countdown, the logoff is canceled
- Sleep timing continues regardless of logoff occurrence

**Example Valid Configurations:**

```powershell
# Lock after 10 minutes, logoff after 25 minutes total (15 minutes after lock), sleep after 45 minutes total
-IdleLockTimeoutMinutes 10 -IdleLogoffTimeoutMinutes 25 -SetPowerPolicies -IdleSleepTimeoutMinutes 45

# Lock after 15 minutes, logoff after 30 minutes total (15 minutes after lock)
-IdleLockTimeoutMinutes 15 -IdleLogoffTimeoutMinutes 30

# Lock after 10 minutes, sleep after 30 minutes total (no logoff)
-IdleLockTimeoutMinutes 10 -SetPowerPolicies -IdleSleepTimeoutMinutes 30
```

## Manual Installation

> [!Important]
> You need to run the PowerShell script with system privileges. The easiest way to do this is to download [PSExec](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec). Then extract the Zip to a folder and open an administrative command prompt.

1. Either clone the repo or download it as a zip file. If downloading the repo as a zip file, then extract it to a new folder.

2. Execute PowerShell as SYSTEM by running the following command:

    ``` cmd
    psexec64 -s -i powershell
    ```

3. In the newly opened PowerShell window, execute the following:

    ``` powershell
    Set-ExecutionPolicy Bypass -Scope Process
    ```

4. Change directories to the local 'source' directory.

5. Then execute the script using the correct parameters as exemplified below:

    - **Basic Multi-App Kiosk Configuration**

      ``` powershell
      .\Set-WindowsAppKioskSettings.ps1
      ```

    - **Multi-App Kiosk with Settings Access**

      ``` powershell
      .\Set-WindowsAppKioskSettings.ps1 -ShowSettings
      ```

    - **Windows App Shell Kiosk with AutoLogon and Idle Timeout**

      ``` powershell
      .\Set-WindowsAppKioskSettings.ps1 -WindowsAppShell -AutoLogonKiosk -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' -WindowsAppAutoLogoffTimeInterval 30
      ```

    - **Multi-App Kiosk with AutoLogon and App Reset on Close**

      ``` powershell
      .\Set-WindowsAppKioskSettings.ps1 -AutoLogonKiosk -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOnly'
      ```

    - **Shared PC Configuration with Smart Card Support**

      ``` powershell
      .\Set-WindowsAppKioskSettings.ps1 -SharedPC -SmartCardRemovalAction 'Lock' -ShowSettings
      ```

    - **Install Windows App and Configure Kiosk**

      ``` powershell
      .\Set-WindowsAppKioskSettings.ps1 -InstallWindowsApp -WindowsAppShell -AutoLogonKiosk -WindowsAppAutoLogoffConfig 'ResetAppAfterConnection'
      ```

    - **Lock Screen on Idle**

      ``` powershell
      .\Set-WindowsAppKioskSettings.ps1 -IdleLockTimeoutMinutes 15 -ShowSettings
      ```

## Manual Removal

Remove the configuration from the PowerShell prompt using:

``` powershell
.\Remove-KioskSettings.ps1
```

## Troubleshooting

### Emergency Access

**Break out of kiosk mode:** During device restart, hold **LEFT SHIFT** and repeatedly press **ENTER** until the normal login screen appears.

### Logging and Diagnostics

All configuration events are logged to: **Event Viewer > Applications and Services Logs > Windows-App-Kiosk**

### Common Issues

| Problem | Symptoms | Solution |
|---------|----------|----------|
| **Windows App missing** | Start menu shows no apps | Run: `Get-AssignedAccessConfiguration` to check kiosk settings |
| **Settings unavailable** | No Settings app visible | Verify `-ShowSettings` was used and Windows edition supports it |
| **AutoLogon fails** | Manual login required | Check if 'KioskUser0' account exists in User Management |
| **Smart card not working** | No lock/logoff on card removal | Ensure device has smart card reader and policies are applied |
| **App installation fails** | Script errors during setup | Check internet connectivity and Windows App download URL |

### Configuration Verification

**Quick Health Check:**

``` powershell
# Check kiosk configuration
Get-AssignedAccessConfiguration

# Verify installation
Get-ItemProperty "HKLM:\Software\Kiosk" -Name "version"

# Check Windows App settings
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsApp" -ErrorAction SilentlyContinue
```

[^1]: For more information see [Maintenance Start Time section of the Shared PC technical reference](https://learn.microsoft.com/en-us/windows/configuration/shared-pc/shared-pc-technical#maintenancestarttime)
[^2]: For more information see [Set Power Policies section of the Shared PC technical reference](https://learn.microsoft.com/en-us/windows/configuration/shared-pc/shared-pc-technical#setpowerpolicies)
[^3]: For more information see [Policy Customization section of the SharedPC (Windows Configuration Designer reference)](https://learn.microsoft.com/en-us/windows/configuration/wcd/wcd-sharedpc#policycustomization)
