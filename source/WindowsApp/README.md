# Windows App Kiosk

**📖 Documentation Navigation:**

| [Overview](README.md) | [Description](DESCRIPTION.md) | [Implementation Guide](IMPLEMENTATION.md) | [Intune Deployment](INTUNE_DEPLOYMENT.md) |
| :--: | :--: | :--: | :--: |

---

## Overview

This repository contains a script and supporting artifacts to configure a Windows client operating system to act as a custom Windows 365 or Azure Virtual Desktop client kiosk using the [Windows App](https://learn.microsoft.com/en-us/windows-app/overview).

## Quick Links

- **[Description Guide](DESCRIPTION.md)** - Learn about the solution architecture, prerequisites, user interface modes, and sign-in flows
- **[Implementation Guide](IMPLEMENTATION.md)** - Complete parameter reference, manual installation steps, and troubleshooting
- **[Intune Deployment Guide](INTUNE_DEPLOYMENT.md)** - Deploy via Win32 apps or configuration profiles in Microsoft Intune

## What's Included

The solution provides two deployment modes:

### Multi-App Kiosk Mode

A restricted Windows interface showing only Windows App and optionally Settings, deployed via Assigned Access configuration.

### Shell Launcher Mode

Windows App completely replaces the Windows Explorer shell, providing a dedicated kiosk experience with the highest level of security.

## Key Features

- ✅ Multiple deployment options (manual, Intune Win32 app, or configuration profiles)
- ✅ AutoLogon support for true kiosk scenarios
- ✅ Configurable idle timeout behaviors (lock, logoff, sleep)
- ✅ Smart card integration for secure authentication
- ✅ Windows App auto-logoff configurations
- ✅ Shared PC mode support
- ✅ Comprehensive troubleshooting and emergency access features

## Getting Started

1. Review the [Description Guide](DESCRIPTION.md) to understand the solution architecture
2. Check the [Implementation Guide](IMPLEMENTATION.md) for detailed parameters and installation steps
3. For enterprise deployment, see the [Intune Deployment Guide](INTUNE_DEPLOYMENT.md)

## Documentation Structure

This documentation is split across four files for easier navigation:

- **README.md** (this file) - Overview and quick links
- **[DESCRIPTION.md](DESCRIPTION.md)** - Architecture, prerequisites, UI modes, and capabilities
- **[IMPLEMENTATION.md](IMPLEMENTATION.md)** - Parameters, installation procedures, and troubleshooting
- **[INTUNE_DEPLOYMENT.md](INTUNE_DEPLOYMENT.md)** - Intune-specific deployment guidance

## Additional Resources

- [Windows App Documentation](https://learn.microsoft.com/en-us/windows-app/)
- [Assigned Access Configuration](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/)
- [Shell Launcher](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/shell-launcher/)
- [Azure Virtual Desktop](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [Windows 365](https://learn.microsoft.com/en-us/windows-365/)
