# Changelog

## 1.2.0

- Added Entire phone screen / Selected app mirror-source selection and Load apps for the selected phone.
- Selected app opens its exact Android package in a separate virtual display; Android 10+ is required.
- No fallback to the main phone display when an app is unselected or cannot start.
- Disabled main-phone screenshot, Home, and system-wide audio forwarding in selected-app mode. App-mode recordings capture the separate display.
- Added checks for app-list parsing, exact virtual-display arguments, invalid-package rejection, and mode-specific UI controls.

This is a separate app display, not a crop of an app already visible on the phone and not a security sandbox. Some apps may refuse secondary displays. Live device testing remains outstanding.

## 1.1.0

- Replaced the CMD/PowerShell launcher with a native C# Windows application, `Phone Mirror.exe`.
- Retained device selection, USB/Wi-Fi setup, pairing, presets, recording, screenshots, Home, and volume controls.
- Launches bundled scrcpy and ADB directly without a command shell.
- Runs with the current user's privileges; no administrator elevation is requested.
- Stores new preferences and captures in `%LOCALAPPDATA%\PhoneMirror\Saved`, accessible through Open saved files.
- Automatically refreshes devices at startup and disables session start buttons while a mirror is running.
- Supports graceful close of the mirror to finish recordings.
- Adds a native build script, source code, and application manifest.
- Portable release omits the optional upstream BAT/VBS helper launchers and developer build scripts.

The executable is unsigned. UI loading and bundle portability are verified; live Android behavior requires a connected device and remains unverified.

## 1.0.0

Initial PowerShell control panel with portable scrcpy 4.0 runtime, documentation, and attribution.
