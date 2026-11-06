<p align="center"><img src="assets/controller-off.svg" alt="DualSense Bluetooth Off — One click to disconnect. Pairing stays saved." width="960"></p>

# DualSense Bluetooth Off

Disconnect a paired **Sony DualSense (PS5) controller** from Windows with a desktop shortcut. Pairing stays saved, so you can reconnect with the PS button.

- **One-click setup:** run `Install.cmd` to add a **DualSense Off** shortcut to your desktop.
- **Runs as your normal Windows user.**
- **Selects a single paired DualSense automatically.** If several are paired, choose the controller by Bluetooth address.
- **Command-line controls:** list controllers, check connection status, preview an action with `-WhatIf`, or return JSON.
- **Uses Windows Bluetooth APIs:** no added drivers, services or background watchers; no unpairing or device disabling.

## Scope: controller-off only

This is a **standalone controller-off utility**, not the Bluetooth pairing/connection fix. It assumes the controller is already paired with Windows.

The pairing fix must remain in a **separate repository**, with its own instructions and releases. Do not bundle pairing-repair scripts, driver changes, or adapter-reset operations into this tool or its installer. Installing this utility does not install or apply the pairing fix.

## Install

1. Download the ZIP from the [latest release](https://github.com/Khayoon/dualsense-bluetooth-off/releases/latest).
2. Extract the ZIP to a folder.
3. Double-click **`Install.cmd`**.

Setup copies the utility to `%LOCALAPPDATA%\DualSenseBluetoothOff` and creates the **DualSense Off** desktop shortcut. Double-click that shortcut when you want to disconnect the controller.

If more than one DualSense is paired, list their addresses and run the installer with the address you want the shortcut to use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Controller-Off.ps1 -List
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-ControllerOff.ps1 -Address AA:BB:CC:DD:EE:FF
```

Replace the example address with an address reported by `-List`.

## Command-line usage

Run these commands in PowerShell from the extracted folder:

```powershell
# List paired DualSense controllers
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Controller-Off.ps1 -List

# Check connection status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Controller-Off.ps1 -Status

# Disconnect the single paired DualSense
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Controller-Off.ps1

# Disconnect a specific controller
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Controller-Off.ps1 -Address AA:BB:CC:DD:EE:FF

# Preview the selected action
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Controller-Off.ps1 -Address AA:BB:CC:DD:EE:FF -WhatIf

# Read status as JSON
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Controller-Off.ps1 -Status -Json
```

The `ExecutionPolicy Bypass` option applies to that PowerShell process; it does not change the system's saved execution policy.

## Windows

Intended for **Windows 10 and Windows 11**, with Windows PowerShell and a paired Bluetooth DualSense. Windows 11 has not been checked on physical hardware for this release.

The shortcut uses standard Windows Bluetooth APIs and keeps your controller selection in a local per-user configuration.

## FAQ

**Does “Off” mean a guaranteed physical power-off?** Windows confirms the Bluetooth disconnect; controller firmware determines the physical power state.

**Will I need to pair the controller again?** Pairing is retained. Press the PS button to reconnect.

**Why does it ask for an address?** When multiple DualSense controllers are paired, an explicit address prevents the utility from choosing the wrong one.

## References and support

- [Microsoft: IOCTL_BTH_DISCONNECT_DEVICE](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/bthioctl/ni-bthioctl-ioctl_bth_disconnect_device)
- [Report an issue](https://github.com/Khayoon/dualsense-bluetooth-off/issues)
- [Project link index](llms.txt) · [CodeMeta metadata](codemeta.json)

Independently authored utility; not affiliated with Sony, ASUS or Microsoft. Released under the [MIT License](LICENSE).

## Separate connection repair

For pairing and reconnection help on the ASUS P9X79 PRO's onboard Atheros adapter, see [ASUS P9X79 PRO DualSense Bluetooth Fix](https://github.com/Khayoon/asus-p9x79-dualsense-bluetooth-fix).
