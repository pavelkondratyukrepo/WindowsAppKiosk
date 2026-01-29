# Remote Desktop Client Deployment

This folder contains scripts and dependencies for deploying the **Remote Desktop Client for Windows** on Windows devices.

## Overview

The Remote Desktop Client for Windows enables users to connect to Azure Virtual Desktop, Remote Desktop Services, and Remote PCs. This deployment solution is designed to install the client system-wide for all users on a device, making it ideal for kiosk and shared device scenarios.

## Files in This Folder

- **Deploy-RemoteDesktopClient.ps1** - Main deployment script for installing or uninstalling Remote Desktop Client
- **Detect-RemoteDesktopClient.ps1** - Detection script to verify Remote Desktop Client installation status

## Deployment Methods

### Method 1: Automatic Download (Requires Internet Connectivity)

Run the deployment script without placing the MSI file in the folder. The script will automatically download the latest version from Microsoft:

```powershell
.\Deploy-RemoteDesktopClient.ps1
```

The script will:

1. Check for existing Remote Desktop Client installations and compare versions
2. Download the latest Remote Desktop Client MSI from Microsoft's download link
3. Install or upgrade the client if needed
4. Configure automatic updates to be disabled
5. Clean up temporary files

### Method 2: Offline Installation (No Internet Required)

For environments without internet connectivity or air-gapped systems, you can manually download and place the MSI file in this folder.

#### Step 1: Download Remote Desktop Client MSI

On a device with internet access, download the Remote Desktop Client MSI package:

1. **Option A: Direct Download Link**

   - Visit: https://go.microsoft.com/fwlink/?linkid=2068602
   - The MSI file will download automatically
   - The file will typically be named similar to `RemoteDesktop_<version>_x64.msi`

2. **Option B: Using PowerShell**

   ```powershell
   $DownloadUrl = "https://go.microsoft.com/fwlink/?linkid=2068602"
   $OutputPath = "$env:USERPROFILE\Downloads\RemoteDesktopClient.msi"
   Invoke-WebRequest -Uri $DownloadUrl -OutFile $OutputPath -UseBasicParsing
   ```

3. **Option C: Using the Microsoft Download Center**

   - Navigate to the [Remote Desktop Client download page](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/windowsdesktop)
   - Download the Windows 64-bit client MSI

#### Step 2: Transfer to Target Environment

Copy the downloaded MSI file to this folder:

```
source\RemoteDesktopClient\Apps\RemoteDesktopClient\
```

Place the `.msi` file directly in this directory alongside the `Deploy-RemoteDesktopClient.ps1` script.

#### Step 3: Run Offline Deployment

Execute the deployment script. It will detect the local MSI file and use it instead of attempting to download:

```powershell
.\Deploy-RemoteDesktopClient.ps1
```

The script will:
1. Detect the MSI file in the current directory
2. Check the version of the MSI against any installed version
3. Install or upgrade the client if needed
4. Configure automatic updates to be disabled

## Integration with Kiosk Configuration

This deployment is designed to integrate seamlessly with the Remote Desktop Client kiosk configuration script. When using the main kiosk configuration script with the `-InstallRemoteDesktopClient` parameter, it will automatically call this deployment script:

```powershell
.\Set-RemoteDesktopKioskSettings.ps1 -InstallRemoteDesktopClient [other parameters]
```

## Uninstalling

To uninstall the Remote Desktop Client:

```powershell
.\Deploy-RemoteDesktopClient.ps1 -DeploymentType "Uninstall"
```

## Logging

Installation and uninstallation activities are logged to:

```
%SystemRoot%\Logs\Software\Install-RemoteDesktop.log
%SystemRoot%\Logs\Software\UnInstall-RemoteDesktop.log
```

## Version Detection

The script includes built-in version detection. It will:

- Check if Remote Desktop Client is currently installed
- Compare the installed version with the available version (from local MSI or download)
- Only install or upgrade if:
  - The client is not installed, OR
  - A newer version is available

If the installed version is current, the script will skip installation to save time.

## Requirements

- **Operating System**: Windows 10 or later
- **Architecture**: 64-bit (x64)
- **Permissions**: Administrator rights (script must run as SYSTEM or with elevated privileges)
- **Internet**: Required only for Method 1 (automatic download)

## Air-Gapped and Disconnected Environments

For air-gapped or disconnected environments:

1. Download the MSI on a connected system
2. Scan for malware/validate the file as per your security policies
3. Transfer the MSI to the disconnected environment via approved methods
4. Place the MSI in this folder
5. Run the deployment script

The script will automatically detect and use the local MSI file, eliminating the need for internet connectivity during deployment.

## Troubleshooting

### Issue: Script says "Remote Desktop MSI package could not be downloaded"

**Solution**: 
- Check internet connectivity
- Verify the download URL is accessible
- Consider using offline installation method

### Issue: Installation fails with exit code other than 0

**Solution**:
- Check the log file for detailed error messages
- Verify administrator/SYSTEM permissions
- Ensure no other Remote Desktop Client installation is in progress
- Check available disk space

### Issue: Script detects old version but doesn't upgrade

**Solution**:
- Manually uninstall the old version first
- Run the script again
- Or use: `.\Deploy-RemoteDesktopClient.ps1 -DeploymentType "Uninstall"` then reinstall

## Related Documentation

- [Remote Desktop Client Documentation](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/windowsdesktop)
- [Azure Virtual Desktop Client Documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/users/connect-windows)
- [Remote Desktop Client URI Scheme](https://learn.microsoft.com/en-us/azure/virtual-desktop/uri-scheme)
