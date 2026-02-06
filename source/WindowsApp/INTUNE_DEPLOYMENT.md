# Windows App Kiosk - Intune Deployment

**Navigation:** [Overview](README.md) | [Description](DESCRIPTION.md) | [Implementation Guide](IMPLEMENTATION.md) | Intune Deployment

---

## Table of Contents

- [Win32 App Deployment](#win32-app-deployment)
- [Configuration Profiles Approach](#configuration-profiles-approach)
  - [Shell Launcher](#shell-launcher)
  - [MultiApp Kiosk](#multiapp-kiosk)
  - [Common Settings](#common-settings)

## Win32 App Deployment

You can deploy this solution to multiple devices using [Microsoft Intune Win32 apps](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management).

### Recommended Intune Command Lines

**For Standard Deployments:**

``` cmd
powershell.exe -ExecutionPolicy Bypass -File Set-WindowsAppKioskSettings.ps1 -ShowSettings
```

*Use this for most corporate environments where users sign in with their own credentials*

**For Dedicated Kiosk Devices:**

``` cmd
powershell.exe -ExecutionPolicy Bypass -File Set-WindowsAppKioskSettings.ps1 -AutoLogonKiosk -WindowsAppAutoLogoffConfig "ResetAppOnCloseOrIdle" -WindowsAppAutoLogoffTimeInterval 15
```

*Perfect for lobby kiosks, conference rooms, or shared access points*

**For New Device Deployments:**

``` cmd
powershell.exe -ExecutionPolicy Bypass -File Set-WindowsAppKioskSettings.ps1 -InstallWindowsApp -SharedPC -ShowSettings
```

*Automatically installs Windows App and configures shared PC features*

### Detection Method

You can utilize a custom detection script in Intune or use a Registry detection method to read the value of `HKEY_LOCAL_MACHINE\Software\Kiosk\version` which should be equal to the value of the version parameter used in the deployment script.

## Configuration Profiles Approach

As an alternative to Win32 app deployment, you can use a mixture of Intune configuration profiles to deploy the kiosk settings.

### Shell Launcher

1. Create a custom configuration profile and specify the **OMA-URI** as './Vendor/MSFT/AssignedAccess/ShellLauncher' with the **Data type** as 'string (XML file)'. Then select the appropriate ShellLauncher XML file from the 'source\AssignedAccess\ShellLauncher' directory. Deploy to devices. [^1]

   **Figure 1:** Intune Shell Launcher configuration

   ![Intune Shell Launcher Profile](../../docs/media/OMA-URI-ShellLauncher.png)

2. Disable Task Manager in the lock screen by creating a new Settings Catalog profile and setting **Administrative Templates | System > Ctrl+Alt+Del Options | Remove Task Manager (User)** to 'Enabled'. Deploy to Users and use a kiosk devices device filter.

### MultiApp Kiosk

1. Create a custom configuration profile and name it appropriately.

2. **Multi-App Configuration:** Add a new OMA-URI Setting and specify the **OMA-URI** as './Vendor/MSFT/AssignedAccess/Configuration' with the **Data type** as 'string (XML file)'. Then select the appropriate MultiApp XML file from the 'source\AssignedAccess\MultiApp' directory. [^2]

   **Figure 2:** Intune Multi-App Kiosk configuration

   ![Intune Restricted User Experience Kiosk Profile](../../docs/media/OMA-URI-MultiApp.png)

3. **Hide the Recommended Section of the Start Menu:** Add a new row and specify the **OMA-URI** as './Vendor/MSFT/Policy/Config/Start/HideRecommendedSection' with the **Data type** as 'integer'. Set the value to 1.

4. **Disable Search box in Start Menu:** Add a new row and specify **OMA-URI** as './Device/Vendor/MSFT/Policy/Config/Search' with the **Data type** as 'integer'. Set the value to 1.

5. **Hide Hibernate:** Add a new row and specify **OMA-URI** as './Device/Vendor/MSFT/Policy/Config/Start/HideHibernate' with the **Data type** as 'integer'. Set the value to 1.

6. **Hide Sleep:** Add a new row and specify **OMA-URI** as './Device/Vendor/MSFT/Policy/Config/Start/HideSleep' with the **Data type** as 'integer'. Set the value to 1.

   **Figure 3:** Intune Custom Profile configuration

   ![Intune Custom Profile Configuration](../../docs/media/MultiAppIntune.png)

7. Deploy this custom configuration profile to devices.

8. If you deployed a Multi-App Configuration with Settings and you wish to restrict the Settings and Control Panel to only certain pages, create a new Settings Catalog profile and select the settings as shown in the figure below.

   **Figure 4:** Intune Restrict Settings and Control Panel

   ![Intune Restrict Settings and Control Panel](../../docs/media/Intune-RestrictSettingsAndControlPanel.png)

### Common Settings

These settings apply to both Shell Launcher and MultiApp Kiosk configurations:

1. If desired, create a Shared multi-user device configuration profile and select the appropriate settings based on your desired configuration. The figure below shows all items configured.

   **Figure 5:** Intune Shared Multi-User Device Configuration

   ![Intune Shared PC Profile](../../docs/media/Intune-SharedPC.png)

2. Disable Windows Spotlight by creating a new Settings Catalog profile and setting **Experience | Allow Windows Spotlight (User)** to 'Block'. Deploy to Users and limit it to Kiosk Devices using a device filter.

3. If you did not deploy the Shared Multi-User device configuration profile, then to disable the First Logon animation, create a Settings Catalog profile and set **Windows Logon | Enable First Logon Animation** to 'Disabled'. Deploy to Devices.

4. If you selected an autologon multiapp or shell launcher profile, then you should disable Change Password, Lock, and Logoff from the Lock Screen. Complete this by creating a new settings catalog profile and setting the following three items from **Administrative Templates | System > Ctrl+Alt+Del Options** to 'Enabled': **Remove Change Password (User)**, **Remove Lock Computer (User)**, **Remove Logoff (User)**. Deploy to users and use the Kiosk Devices device filter.

5. For autologon kiosks, you might want to configure the Windows App Autologoff behavior. You can configure this as part of your Windows App Deployment or as a remediation script.

## Additional Resources

- [Intune Win32 App Management](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management)
- [Intune Configuration Profiles](https://learn.microsoft.com/en-us/mem/intune/configuration/device-profiles)
- [OMA-URI Settings](https://learn.microsoft.com/en-us/mem/intune/configuration/custom-settings-windows-10)
- [Intune Settings Catalog](https://learn.microsoft.com/en-us/mem/intune/configuration/settings-catalog)

[^1]: For more information see [Configure a Kiosk section of the Shell Launcher reference](https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/quickstart-kiosk?tabs=csp)
[^2]: For more information see [Configure a restricted user experience (multi-app kiosk) with Assigned Access](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/configure-multi-app-kiosk?tabs=intune)
