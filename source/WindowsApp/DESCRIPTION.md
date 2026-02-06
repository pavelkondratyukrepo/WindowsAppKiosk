# Windows App Kiosk - Description

**Navigation:** [Overview](README.md) | Description | [Implementation Guide](IMPLEMENTATION.md) | [Intune Deployment](INTUNE_DEPLOYMENT.md)

---

## Introduction

This repository contains a script and supporting artifacts to configure a Windows client operating system to act as a custom Windows 365 or Azure Virtual Desktop client kiosk using the [Windows App](https://learn.microsoft.com/en-us/windows-app/overview).

The solution consists of two main parts: User interface customizations and Windows App configurations.

The user interface customizations are configured using:

- An Assigned Access configuration for multi-app kiosk mode or shell launcher applied via the WMI Bridge CSP.
- A multi-user local group policy object for non-administrative users.
- Applocker policy policy applied in the WindowsAppShell scenario.
- Provisioning packages that remove pinned items from the start menu, disable Windows Spotlight, and optionally enable Shared PC mode.

The Windows App configurations are designed to enforce security of the client and access to the Azure Virtual Desktop and  Windows 365 services. The options include automatic logoff behaviors, first-run experience configuration, and integration with Windows security features such as smart card removal actions.

This custom kiosk could be used for numerous scenarios including secure remote access, shared workstations, and dedicated Azure Virtual Desktop and Windows 365 endpoints.

## Prerequisites

1. A currently [supported version of Windows](https://learn.microsoft.com/en-us/windows/release-health/supported-versions-windows-client) with the choice of the following editions and versions based on the `WindowsAppShell` parameter.

   1. When the `WindowsAppShell` parameter is specified, then the following editions are supported [^1]:
      - Windows 11 Education
      - Windows 11 Enterprise
      - Windows 10/11 Enterprise LTSC
      - Windows 11 IoT Enterprise
      - Windows 10/11 IoT Enterprise LTSC

   2. When the `WindowsAppShell` parameter is <u>not</u> specified, then the following editions of <b>Windows 11</b> are supported [^2]:
      - Education
      - Enterprise
      - Enterprise LTSC
      - IoT Enterprise
      - IoT Enterprise LTSC
      - Pro
      - Pro Education

2. The ability to run the installation script as SYSTEM. The instructions are provided in the [Implementation Guide](IMPLEMENTATION.md#manual-installation).

3. For most scenarios, you should [join the client device to Entra ID](https://learn.microsoft.com/en-us/entra/identity/devices/concept-directory-join) or [Entra ID Hybrid Join the device](https://learn.microsoft.com/en-us/entra/identity/devices/concept-hybrid-join).

## Sign-In Flow and User Interface

### Summary

The user interface experience is determined by several factors and parameters. The parameters are all documented in the [Implementation Guide](IMPLEMENTATION.md#parameters), but the following table outlines the resulting user interface based on the parameter values.

**Table 1:** Windows App User Interface and Sign-In Flow Summary

| AutoLogonKiosk | WindowsAppShell | User Interface |
|:--------------:|:---------------:|----------------|
| False          | False           | *This is the default configuration if no parameters are specified.* A Multi-App Kiosk configuration is applied via Assigned Access which locks down the explorer interface to only show the Windows App and optionally Settings. The user will sign-in to the device using Entra ID credentials and will be automatically presented with a restricted interface showing only approved applications. |
| True           | False           | A Multi-App Kiosk configuration is applied via Assigned Access which locks down the explorer interface to only show the Windows App and optionally Settings. Windows 11 will automatically logon with the 'KioskUser0' account. The user will be presented with a restricted Start menu containing only the Windows App. |
| True           | True            | The Windows App replaces the explorer shell via Shell Launcher kiosk mode. Windows will automatically logon with the 'KioskUser0' account. The user will be presented with the Windows App interface to connect to their Azure Virtual Desktop resources. |
| False          | True            | The Windows App replaces the explorer shell via Shell Launcher kiosk mode. The user will sign-in to the device using Entra ID credentials and will be automatically presented with the Windows App. |

### Sign-In Flow Details

As documented in the Table 1, The `AutologonKiosk` parameter controls the user sign-in flow. This difference is depicted by Figure 1 below.

**Figure 1:** User Sign-In Flow Scenarios

![Sign-in Flows](../../docs/media/KioskTypes.png)

### User Interface Details

#### Multi-App Kiosk

When the `WindowsAppShell` switch parameter is <u>not</u> specified, the device is configured using the [Multi-App Kiosk Assigned Access](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/overview).

The user interface experience provides a restricted Start menu with only the Windows App and optionally the Settings app. Users can easily switch between multiple Azure Virtual Desktop or Windows 365 connections while maintaining security restrictions.

**Figure 2:** Multi-App Kiosk showing Windows App interface

![Windows App Multi-App](../../docs/media/WindowsApp-MultiApp.png)

The figure below illustrates the Settings applet restricted to allow the user to adjust display and audio settings. This would primarily be used in a multi-monitor scenario or when audio configuration is needed.

**Figure 3:** Multi-App Showing Display Settings

![Restricted Settings App](../../docs/media/Settings.png)

#### Windows App Shell Laucher Kiosk

When the `WindowsAppShell` parameter is selected, the Windows App replaces the default Windows 'Explorer.exe' shell using [Shell Launcher](https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/).

The user interface experience provides only the Windows App with no access to other system functions, providing the highest level of security and focus.

The figure below illustrates the display of an Autologon Windows App Shell Launcher kiosk.

**Figure 4:** Windows App Shell Kiosk before Sign-in

![Windows App Shell Launcher Sign In](../../docs/media/ShellLauncher-SignIn.png)

The figure below illustrates the Windows App Shell kiosk after a user signs in to the Windows App.

**Figure 5:** Windows App Shell Kiosk showing Windows App only

![Windows App Shell Launcher](../../docs/media/WindowsApp-SingleApp.png)

## Windows App Auto Logoff Behaviors

The table below outlines the automatic logoff behaviors available for Windows App in kiosk scenarios. For more information see [Configure auto logoff on Windows](https://learn.microsoft.com/en-us/windows-app/windowsautologoff).

**Table 2:** Windows App Auto Logoff Configuration Summary

| AutoLogoffConfig | Behavior | Use Case |
| :--------------: | :------- | :------- |
| Disabled | No automatic sign-out or app data reset | Recommended if users logon to the client desktop so that the Windows operating system controls Lock and Logoff behaviors. Not recommended for the AutoLogon Kiosk scenarios |
| ResetAppOnCloseOnly | Sign out users and reset app data when the Windows App is closed | Suitable when users manually close the app |
| ResetAppAfterConnection | Sign out users and reset app data when a successful connection is made to a session host or Cloud PC. | Provides comprehensive cleanup after establishing connections. Suitable when users have only one resource assigned. |
| ResetAppOnCloseOrIdle | Sign out users and reset app data when the app is closed OR the system is idle for the specified interval | Enforces idle time restrictions to help prevent credential theft. |

## Additional Resources

- [Windows App Documentation](https://learn.microsoft.com/en-us/windows-app/)
- [Assigned Access Configuration](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/)
- [Shell Launcher](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/shell-launcher/)
- [Shared PC Configuration](https://learn.microsoft.com/en-us/windows/configuration/shared-pc/)
- [Azure Virtual Desktop](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [Windows 365](https://learn.microsoft.com/en-us/windows-365/)

[^1]: For more information see [Shell Launcher Windows Edition Requirements](https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/#windows-edition-requirements)
[^2]: For more information see [Assigned Access Windows Edition Requirements](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/overview?tabs=ps#windows-edition-requirements)
