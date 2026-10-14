A native Windows application based on [scrcpy 4.0](https://github.com/Genymobile/scrcpy) by Genymobile and Romain Vimont.

Download the portable Windows ZIP, extract the whole folder, and double-click **Phone Mirror.exe**. scrcpy is included; no CMD or PowerShell launcher is required.

### New in v1.2.0

- Choose **Entire phone screen** or **Selected app (separate display)**.
- Click **Load apps**, select an installed launchable app, and start mirroring or recording.
- Selected-app mode requires Android 10+ and opens the exact app package in a separate virtual display. It does not mirror the main phone screen or crop an existing app window.
- No fallback to whole-phone mirroring when selection is missing or the app cannot start.
- Main-phone screenshots, Home, and system-wide audio forwarding are disabled in app mode. Use recording to capture the app display.

Some apps or devices do not support secondary displays. This mode is not a security sandbox: an app can open other activities on its display. Live Android app mirroring remains unverified; native build, UI loading, portable launch, app-list parsing, exact display arguments, and control restrictions passed local checks. The release workflow repeats the executable/UI/app-mode checks before publishing.

The executable is unsigned. The release includes upstream attribution, licenses, source archives, and a SHA-256 checksum file. Recordings and saved device settings are excluded.
