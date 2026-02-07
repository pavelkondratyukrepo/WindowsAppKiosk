# Azure Virtual Desktop and Windows 365 Client Kiosk Solutions

## 📋 Introduction

This repository contains scripts and supporting artifacts to configure a Windows client operating system to act as a custom Azure Virtual Desktop (AVD) or Windows 365 client kiosk using the modern **Windows App**.

> [!NOTE]
> A legacy Remote Desktop Client solution is also available for **air-gapped government cloud environments only** until Windows App adds support for these scenarios.

## 🎯 Windows App Kiosk Solution

**📂 Location:** [`source/WindowsApp/`](source/WindowsApp/)  
**📖 Documentation:** [Windows App Kiosk README](source/WindowsApp/README.md)

The Windows App kiosk solution leverages Microsoft's latest remote desktop technology with streamlined configuration and built-in security features:

- **🚀 Modern Technology:** Uses the latest Windows App with native Microsoft features
- **⚡ Simplified Configuration:** Streamlined setup with fewer complex parameters
- **🔄 Built-in Auto Logoff:** Native Windows App automatic logoff and reset capabilities
- **📊 Easier Management:** Reduced complexity while maintaining security

**Key Features:**

✅ Windows Operating System Autologon support  
✅ Windows App Single App Kiosk or Multi-App Kiosk with restricted user experience and customized Start Menu  
✅ Native Windows App auto logoff behaviors (ResetAppOnCloseOnly, ResetAppAfterConnection, ResetAppOnCloseOrIdle)  
✅ Streamlined provisioning package deployment  
✅ Smart card integration with Windows security policies  
✅ Modern user interface with Settings app access options

## 🔒 Air-Gapped Environments Only

### Remote Desktop Client for Windows Kiosk (Legacy)

**📂 Location:** [`source/RemoteDesktopClient/`](source/RemoteDesktopClient/)  
**📖 Documentation:** [Remote Desktop Client Kiosk README](source/RemoteDesktopClient/README.md)

> [!IMPORTANT]
> **Use this solution ONLY for air-gapped government cloud environments.** The Remote Desktop Client for Windows is scheduled for deprecation in commercial environments at the end of **March 2026**. This solution will be removed from the repository once Windows App officially supports air-gapped government clouds.
> 
> **For all other scenarios, use the Windows App kiosk solution above.**

This kiosk solution can be used for numerous scenarios including secure remote access, shared workstations, and dedicated Azure Virtual Desktop endpoints.

## ✅ Prerequisites

### General Requirements

1. **💻 Operating System:** A currently [supported version of Windows](https://learn.microsoft.com/en-us/windows/release-health/supported-versions-windows-client)

2. **📀 Windows Editions:** Depending on the kiosk configuration chosen, different Windows editions are supported:
   - **Shell Launcher:** Education, Enterprise, Enterprise LTSC, IoT Enterprise, IoT Enterprise LTSC
   - **Multi-App Kiosk:** All above editions plus Pro and Pro Education

3. **🔑 Administrative Access:** The ability to run installation scripts with SYSTEM privileges (instructions provided in each solution's documentation)

4. **🔐 Device Management:** For some scenarios, devices must be [joined to Entra ID](https://learn.microsoft.com/en-us/entra/identity/devices/concept-directory-join) or [Entra ID Hybrid Joined](https://learn.microsoft.com/en-us/entra/identity/devices/concept-hybrid-join)

### Solution-Specific Requirements

- **Windows App Kiosk:** See [detailed requirements](source/WindowsApp/README.md#prerequisites)
- **Remote Desktop Client Kiosk (Air-Gapped Only):** See [detailed requirements](source/RemoteDesktopClient/README.md#prerequisites)

## 🚀 Getting Started

📖 **[View Windows App Kiosk Documentation](source/WindowsApp/README.md)**

**Quick Start:**

1. Navigate to `source/WindowsApp/`
2. Follow the installation instructions in the README  
3. Run `Set-WindowsAppKioskSettings.ps1` with your desired parameters

### Air-Gapped Environments

If you are deploying in an **air-gapped government cloud environment**, see the [Remote Desktop Client Kiosk Documentation](source/RemoteDesktopClient/README.md) for the legacy solution. This should only be used until Windows App adds support for these environments.

## 📚 Additional Resources

- [Azure Virtual Desktop Documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [Windows Assigned Access](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/)
- [Entra ID Device Management](https://learn.microsoft.com/en-us/entra/identity/devices/)

## 💬 Support

For issues, questions, or contributions:

1. Check the solution-specific README for troubleshooting guidance
2. Review the repository issues for known problems
3. Create a new issue with detailed information about your environment and problem
