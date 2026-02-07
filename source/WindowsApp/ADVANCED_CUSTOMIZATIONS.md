# Windows App Kiosk - Advanced Customizations

**Navigation:** [Overview](README.md) | [Solution Overview](SOLUTION_OVERVIEW.md) | [Implementation Guide](IMPLEMENTATION.md) | [Intune Deployment](INTUNE_DEPLOYMENT.md) | Advanced Customizations

---

## Table of Contents

- [Windows App Kiosk - Advanced Customizations](#windows-app-kiosk---advanced-customizations)
  - [Table of Contents](#table-of-contents)
  - [Adding Microsoft Edge to Multi-App Kiosk](#adding-microsoft-edge-to-multi-app-kiosk)
    - [Why So Many Executables?](#why-so-many-executables)
  - [Understanding Child Process Requirements](#understanding-child-process-requirements)
    - [How to Identify Child Processes](#how-to-identify-child-processes)
    - [Common Examples](#common-examples)
  - [Custom Start Menu Layouts](#custom-start-menu-layouts)
  - [Additional Resources](#additional-resources)

## Adding Microsoft Edge to Multi-App Kiosk

If you want to include Microsoft Edge in your Multi-App Kiosk configuration, you can use the reference file [WindowsApp_withEdge.xml](AssignedAccess/MultiApp/WindowsApp_withEdge.xml) as an example.

> **Important:** This file is **not deployed by this solution**. It serves as a reference for customizing your kiosk configuration.

The example configuration includes:

```xml
<AllowedApps>
  <App AppUserModelId="windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel" />
  <App AppUserModelId="Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe!App" />
  <App DesktopAppPath="%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" />
  <App DesktopAppPath="%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge_proxy.exe" />
  <App DesktopAppPath="%ProgramFiles(x86)%\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" />
  <App DesktopAppPath="crossdeviceresume.exe" />
  <App AppUserModelId="MicrosoftCorporationII.Windows365_8wekyb3d8bbwe!Windows365" />
  <App DesktopAppPath="windows365.exe" />
  <App DesktopAppPath="msedgewebview2.exe" />
</AllowedApps>
```

### Why So Many Executables?

When you add Microsoft Edge to the allowed apps list, you must include **all** of its child process executables. This is because Edge:

- Uses `msedge_proxy.exe` for certain browser operations
- Requires `msedgewebview2.exe` for WebView2 content
- Uses `MicrosoftEdgeUpdate.exe` for browser updates
- May launch `crossdeviceresume.exe` for cross-device features
- Can launch Windows App (`windows365.exe`) when connecting to Cloud PCs or Azure Virtual Desktop

If you don't include these executables, those features will fail silently or Edge may not function properly within the kiosk environment.

## Understanding Child Process Requirements

When configuring a Multi-App Kiosk, Windows uses AppLocker policies behind the scenes to restrict which applications can run. The configuration file you provide is converted into AppLocker rules.

**Key Principle:** If an application has a dependency on another application or launches child processes, **all of them must be included** in the allowed apps list.

### How to Identify Child Processes

To determine which executables an application might launch:

1. **Process Monitor:** Use [Process Monitor](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon) from Sysinternals to observe which executables are launched when you run the application.

2. **Application Folder:** Check the application's installation folder for multiple executables. For example, Microsoft Edge installs several executables in `%ProgramFiles(x86)%\Microsoft\Edge\Application\`.

3. **Test in Kiosk Mode:** Deploy your configuration to a test device and monitor for failures or unexpected behavior. Check Event Viewer for AppLocker blocks (Applications and Services Logs > Microsoft > Windows > AppLocker).

4. **Vendor Documentation:** Check the application vendor's documentation for known dependencies or required executables.

### Common Examples

| Application | Additional Executables Required |
| :---------- | :------------------------------ |
| Microsoft Edge | `msedge.exe`, `msedge_proxy.exe`, `msedgewebview2.exe`, `MicrosoftEdgeUpdate.exe` |
| Windows App | `windows365.exe` (when Edge is present) |
| Microsoft Teams | Multiple executables in the Teams installation folder |
| Google Chrome | `chrome.exe`, various child processes in the Chrome folder |

## Custom Start Menu Layouts

Multi-App Kiosk configurations require a customized Start menu layout. You can create highly customized layouts by:

1. **Configuring a Test Device:** Set up a test Windows device and arrange the Start menu exactly as you want it to appear in the kiosk.

2. **Exporting the Layout:** Use PowerShell to export the layout:

   ```powershell
   Export-StartLayout -Path "C:\Temp\StartLayout.xml"
   ```

3. **Converting to JSON:** Windows 11 uses JSON format for Start layouts. You can export the layout using the Settings app or by examining existing configurations.

4. **Embedding in Configuration:** Add the layout to your Assigned Access XML using the `v5:StartPins` element:

   ```xml
   <v5:StartPins>
     <![CDATA[
       {
         "pinnedList": [
           {"packagedAppId":"Microsoft.WindowsCalculator_8wekyb3d8bbwe!App"},
           {"desktopAppLink":"%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\File Explorer.lnk"}
         ]
       }
     ]]>
   </v5:StartPins>
   ```

For detailed guidance on Start menu customization, see Microsoft's [Customize the Start layout](https://learn.microsoft.com/en-us/windows/configuration/start/layout) documentation.

## Additional Resources

- [Assigned Access Configuration File Schema](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/configuration-file)
- [Allowed Apps List Requirements](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/configuration-file#allapplist)
- [Multi-App Kiosk Configuration Guide](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/configure-multi-app-kiosk)
- [Process Monitor (Sysinternals)](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon)
- [Customize the Start Layout](https://learn.microsoft.com/en-us/windows/configuration/start/layout)
- [AppLocker Overview](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/applocker/applocker-overview)
