<!--
SPDX-License-Identifier: BSD-3-Clause
SPDX-FileCopyrightText: Z-Wave Alliance <https://z-wavealliance.org>
-->
# Z-Wave PC Controller for GNU/Linux and macOS

A native GNU/Linux and macOS front end of the PC Controller, without Wine or Mono. It is built with
[Avalonia](https://avaloniaui.net/) on .NET 10.

The view models are compiled directly from `../ZWaveControllerUI/Models`, so they stay identical to the
WPF build. The controller logic comes from `../ZWaveController` and `z-wave-tools-core` through their
`*_netcore` projects. Only the views, converters and controls are specific to this project.

## Build and run

Building needs the .NET 10 SDK. A user-local install needs no root:

```sh
curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0
```

Then build:

```sh
./build-linux.sh              # self-contained build in bin/publish/linux-x64
./build-linux.sh --install    # and install to ~/.local/opt, with an application menu entry
bin/publish/linux-x64/ZWaveControllerUI
```

The build is self-contained. It includes the .NET runtime, and every package version is pinned in
`ZWaveControllerUI.Avalonia.csproj`, so running it does not depend on what is installed on the system.
The script fetches the `z-wave-tools-core` submodules if they are missing.

## macOS

The same project builds a native macOS application, for Apple Silicon (`osx-arm64`) and Intel
(`osx-x64`) Macs:

```sh
./build-macos.sh              # "Z-Wave PC Controller.app" in bin/publish/osx-arm64 (or osx-x64)
./build-macos.sh --install    # and copy it to ~/Applications
open "bin/publish/osx-arm64/Z-Wave PC Controller.app"
```

The script builds for the architecture of the Mac it runs on; `RID=osx-x64 ./build-macos.sh` builds
for Intel Macs. The bundle is self-contained and signed ad hoc, which is enough to run it on the Mac
that built it. To hand it to others it has to be signed with a Developer ID and notarized.

Controllers show up as `/dev/cu.usbmodem*` (or `/dev/cu.usbserial-*`) in Settings. macOS also creates
a `/dev/tty.*` twin of every port; those are left out because opening one waits for a carrier signal.
No extra permissions are needed.

Apple Silicon has no native build of the S2 crypto and Z/IP transport libraries. S2 crypto there
runs on the managed implementation in `z-wave-tools-core`, which gives the same results as the native
library (the unit tests compare them). **Z/IP Gateway connections over DTLS are not available on Apple
Silicon**: discovery finds nothing and a connection fails cleanly. An Intel build (`osx-x64`), which
can also run under Rosetta, bundles the native libraries instead.

## Serial ports on GNU/Linux

Controllers show up as `/dev/ttyACM*` (or `/dev/ttyUSB*`) in Settings. If opening one fails with a
permission error, add yourself to the group that owns the port, then log out and back in:

```sh
sudo usermod -aG dialout "$USER"
```

The native S2 crypto (`libs2crypto64.so`) and Z/IP transport (`libziptrans64.so`) libraries ship with
the `linux-x64` build.

## Differences from the Windows build

- Scanning a DSK QR code with a webcam is not available, because that uses a Windows-only capture
  library. A QR code typed by a barcode scanner, or pasted, is read instead.
- The log view copies the selected lines with Ctrl+C (Cmd+C on macOS).
- Settings of the UI are kept in `~/.config/Silicon Labs/Z-Wave PC Controller 5/ui-settings.json`
  on both GNU/Linux and macOS, next to the controller configuration. The crash log is `Controller_curr.log` in the temp folder.
