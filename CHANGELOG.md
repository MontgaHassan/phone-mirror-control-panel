# Changelog

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
