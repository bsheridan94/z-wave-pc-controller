#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
# SPDX-FileCopyrightText: Z-Wave Alliance <https://z-wavealliance.org>
#
# Builds the native macOS Z-Wave PC Controller as a self-contained application bundle: the .NET runtime
# and all libraries are copied in, so the result does not depend on what is installed on the system.
#
#   ./build-macos.sh             build "Z-Wave PC Controller.app" in bin/publish/<rid>
#   ./build-macos.sh --install   also copy it to ~/Applications
#
# The architecture of this Mac is built by default (osx-arm64 on Apple Silicon). RID=osx-x64 builds
# for Intel Macs, which also bundles the native x86_64 S2 crypto and Z/IP transport libraries.
# On Apple Silicon S2 crypto runs on the managed implementation of z-wave-tools-core, and Z/IP over
# DTLS is not available, because there is no arm64 build of the native ziptrans library.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(dirname "$here")"
case "$(uname -m)" in
    arm64) default_rid=osx-arm64 ;;
    *) default_rid=osx-x64 ;;
esac
rid="${RID:-$default_rid}"
out="$here/bin/publish/$rid"
app_name="Z-Wave PC Controller"
app="$out/$app_name.app"
bundle_id="org.z-wavealliance.pc-controller"

dotnet="$(command -v dotnet || true)"
if [ -z "$dotnet" ] && [ -x "$HOME/.dotnet/dotnet" ]; then
    dotnet="$HOME/.dotnet/dotnet"
    export DOTNET_ROOT="$HOME/.dotnet"
fi
if [ -z "$dotnet" ]; then
    echo "The .NET 10 SDK is needed to build. Install it for your user, without root, with:" >&2
    echo "  curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0" >&2
    exit 1
fi
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1

if [ ! -f "$repo/z-wave-tools-core/ZWave/ZWave_netcore.csproj" ]; then
    git -C "$repo" submodule update --init --recursive
fi

files="$out/files"
rm -rf "$files" "$app"
"$dotnet" publish "$here/ZWaveControllerUI.Avalonia.csproj" -c Release -r "$rid" --self-contained true \
    -p:DebugType=None -p:DebugSymbols=false -p:UseAppHost=true -o "$files"

version="$(sed -n 's:.*<FileVersion>\(.*\)</FileVersion>.*:\1:p' "$here/ZWaveControllerUI.Avalonia.csproj" | head -n 1)"
version="${version:-1.0.0.0}"

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp -a "$files/." "$app/Contents/MacOS/"
rm -rf "$files"

# Application icon, from the 256 px logo.
iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"
logo="$repo/ZWaveControllerUI/Images/z-wave_logo256.png"
for size in 16 32 128 256; do
    sips -z $size $size "$logo" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    [ $double -le 256 ] && sips -z $double $double "$logo" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$iconset")"

cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$app_name</string>
    <key>CFBundleDisplayName</key><string>$app_name</string>
    <key>CFBundleIdentifier</key><string>$bundle_id</string>
    <key>CFBundleExecutable</key><string>ZWaveControllerUI</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$version</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2018 Silicon Labs, Inc. All rights reserved.</string>
</dict>
</plist>
EOF

# Apple Silicon runs only signed code; an ad-hoc signature is enough on the Mac that built it.
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
echo "Built: $app"

if [ "${1:-}" = "--install" ]; then
    dest="$HOME/Applications/$app_name.app"
    mkdir -p "$HOME/Applications"
    rm -rf "$dest"
    cp -a "$app" "$dest"
    echo "Installed: $dest (open it from Finder, Launchpad or with: open \"$dest\")"
fi
