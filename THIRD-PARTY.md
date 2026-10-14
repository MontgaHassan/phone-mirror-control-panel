# Included third-party software

Phone Mirror Control Panel is based on scrcpy and bundles its official, unchanged Windows 64-bit v4.0 runtime. Dependency versions below come from the v4.0 upstream build scripts included in `third-party-source/scrcpy-4.0.tar.gz`.

| Component | Version | License / notice | Source |
|---|---|---|---|
| scrcpy | 4.0 | Apache 2.0, `licenses/scrcpy-Apache-2.0.txt` | `third-party-source/scrcpy-4.0.tar.gz` |
| FFmpeg | 8.1.1 | LGPL 2.1 or later, `licenses/FFmpeg-LGPL-2.1.txt` | `third-party-source/ffmpeg-8.1.1.tar.xz` |
| libusb | 1.0.29 | LGPL 2.1 or later, `licenses/libusb-LGPL-2.1.txt` | `third-party-source/libusb-1.0.29.tar.gz` |
| dav1d, linked into FFmpeg | 1.5.3 | BSD 2-Clause, `licenses/dav1d-BSD-2-Clause.txt` | `third-party-source/dav1d-1.5.3.tar.gz` |
| SDL | 3.4.8 | zlib, `licenses/SDL-zlib.txt` | https://github.com/libsdl-org/SDL/tree/release-3.4.8 |
| Android platform-tools / ADB | 37.0.0 | Component notices in `licenses/Android-platform-tools-NOTICE.txt` | https://android.googlesource.com/platform/packages/modules/adb/ |

ADB and its Windows support DLLs are copied from the official scrcpy distribution; the full platform-tools NOTICE is preserved. It also contains notices for additional platform-tools components that are not necessarily in this bundle.

FFmpeg is built without the upstream `--enable-gpl` or `--enable-nonfree` flags. It links dav1d and zlib. The upstream `app/deps/ffmpeg.sh` contains its build configuration. zlib's license and copyright notice are in `licenses/zlib.txt`. Its build dependency version is not pinned by scrcpy's FFmpeg script; it comes from the upstream build environment.

Shared LGPL runtime libraries remain separate DLLs in `vendor/scrcpy`. They are not modified here and may be replaced with compatible versions. This launcher adds no restrictions on modification or reverse engineering of those components for debugging modifications. Source archives are included for the LGPL libraries, along with their upstream build configuration in the scrcpy source archive.

The launcher runs the original scrcpy executable through its command-line interface. No scrcpy source files were edited. The original executable, DLL, image, and server files are preserved byte for byte.
