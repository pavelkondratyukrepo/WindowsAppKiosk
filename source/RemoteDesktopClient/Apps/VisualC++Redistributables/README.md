# Visual C++ Redistributables Deployment

This folder contains the deployment script for the **Microsoft Visual C++ Redistributables** required by the Remote Desktop Client for Windows.

## Overview

The Visual C++ Redistributables are runtime libraries required by applications developed with Microsoft Visual C++. The Remote Desktop Client for Windows depends on these libraries to function properly.

## Files in This Folder

- **Deploy-VisualC++Redistributables.ps1** - Deployment script for installing Visual C++ Redistributables

## Deployment Methods

### Method 1: Automatic Download (Requires Internet Connectivity)

Run the deployment script without placing the EXE file in the folder. The script will automatically download the latest version from Microsoft:

```powershell
.\Deploy-VisualC++Redistributables.ps1
```

The script will:

1. Download the latest Visual C++ Redistributables (x64) from Microsoft
2. Install the redistributables silently
3. Clean up temporary files

### Method 2: Offline Installation (No Internet Required)

For environments without internet connectivity or air-gapped systems, you can manually download and place the EXE file in this folder.

#### Step 1: Download Visual C++ Redistributables

On a device with internet access, download the Visual C++ Redistributables installer:

1. **Option A: Direct Download Link**

   - Visit: https://aka.ms/vs/17/release/vc_redist.x64.exe
   - The EXE file will download automatically

2. **Option B: Using PowerShell**

   ```powershell
   $DownloadUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
   $OutputPath = "$env:USERPROFILE\Downloads\vc_redist.x64.exe"
   Invoke-WebRequest -Uri $DownloadUrl -OutFile $OutputPath -UseBasicParsing
   ```

3. **Option C: Using the Microsoft Download Center**

   - Navigate to the [Latest supported Visual C++ Redistributable downloads](https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)
   - Download the x64 version

#### Step 2: Transfer to Target Environment

Copy the downloaded EXE file to this folder:

```
source\RemoteDesktopClient\Apps\VisualC++Redistributables\
```

Place the `.exe` file directly in this directory alongside the `Deploy-VisualC++Redistributables.ps1` script.

#### Step 3: Run Offline Deployment

Execute the deployment script. It will detect the local EXE file and use it instead of attempting to download:

```powershell
.\Deploy-VisualC++Redistributables.ps1
```

The script will:
1. Detect the EXE file in the current directory
2. Install the Visual C++ Redistributables silently
3. Handle reboot requirements if needed

## Integration with Kiosk Configuration

This deployment is designed to integrate seamlessly with the Remote Desktop Client kiosk configuration script. When using the main kiosk configuration script with the `-InstallRemoteDesktopClient` parameter, it will automatically call this deployment script before installing the Remote Desktop Client:

```powershell
.\Set-RemoteDesktopKioskSettings.ps1 -InstallRemoteDesktopClient [other parameters]
```

The deployment order is:
1. Visual C++ Redistributables (this script)
2. Remote Desktop Client

## Installation Arguments

The script uses the following silent installation arguments:

```
/install /quiet /norestart
```

- `/install` - Performs installation
- `/quiet` - Suppresses user interface
- `/norestart` - Prevents automatic restart

## Exit Codes

- **0** - Installation successful
- **3010** - Installation successful, reboot required
- **Other** - Installation failed (check logs)

## Logging

Installation activities are logged to:

```
%SystemRoot%\Logs\Software\Microsoft_VisualC++Redistributables_Install.log
```

## Requirements

- **Operating System**: Windows 10 or later
- **Architecture**: 64-bit (x64)
- **Permissions**: Administrator rights (script must run as SYSTEM or with elevated privileges)
- **Internet**: Required only for Method 1 (automatic download)
- **Disk Space**: Approximately 50 MB

## Air-Gapped and Disconnected Environments

For air-gapped or disconnected environments:

1. Download the EXE on a connected system
2. Scan for malware/validate the file as per your security policies
3. Transfer the EXE to the disconnected environment via approved methods
4. Place the EXE in this folder
5. Run the deployment script

The script will automatically detect and use the local EXE file, eliminating the need for internet connectivity during deployment.

## Troubleshooting

### Issue: Script says "Visual C++ Redistributables EXE package could not be downloaded"

**Solution**: 
- Check internet connectivity
- Verify the download URL is accessible
- Consider using offline installation method

### Issue: Installation fails with non-zero exit code

**Solution**:
- Check the log file for detailed error messages
- Verify administrator/SYSTEM permissions
- Ensure Visual C++ Redistributables are not already installed or being upgraded
- Check available disk space

### Issue: Exit code 3010 (reboot required)

**Solution**:
- This is normal for some installations
- Schedule a reboot at an appropriate time
- The Remote Desktop Client installation may proceed but may not function until reboot

## Version Information

This deployment installs the latest Visual C++ Redistributables for Visual Studio 2015-2022. This includes:

- Visual C++ 2015 Redistributable
- Visual C++ 2017 Redistributable  
- Visual C++ 2019 Redistributable
- Visual C++ 2022 Redistributable

These versions share the same redistributable files, so only one installation is needed.

## Related Documentation

- [Latest supported Visual C++ Redistributable downloads](https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)
- [Redistributing Visual C++ Files](https://docs.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files)
- [C runtime (CRT) reference](https://docs.microsoft.com/en-us/cpp/c-runtime-library/crt-library-features)
