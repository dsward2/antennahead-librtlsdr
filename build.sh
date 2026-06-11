#!/usr/bin/env bash
# Build librtlsdr.xcframework for macOS arm64, packaged as a proper
# (non-shallow) macOS framework with Versions/A/... layout.
#
# Output: ./librtlsdr.xcframework (replaces existing)
#
# Requirements:
#   - Xcode command-line tools
#   - CMake (port install cmake / brew install cmake)
#   - libusb-1.0 headers + dylib (MacPorts at /opt/local, Homebrew at /opt/homebrew)
#
# After editing librtlsdr-src/, run this script and commit the regenerated
# librtlsdr.xcframework.

set -euo pipefail

# Ensure MacPorts / Homebrew tools are on PATH (cmake, etc.)
export PATH="/opt/local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_ROOT/librtlsdr-src"
BUILD_DIR="$REPO_ROOT/build-arm64"
STAGE_DIR="$REPO_ROOT/build-stage"
XCF_OUT="$REPO_ROOT/librtlsdr.xcframework"

FW_NAME="librtlsdr"
FW_ID="com.antennahead.librtlsdr"
FW_VERSION_SHORT="0.9"
FW_VERSION="1"
DEPLOY_TARGET="12.0"

# --- locate libusb ---
if [[ -f /opt/local/lib/libusb-1.0.dylib && -d /opt/local/include/libusb-1.0 ]]; then
    LIBUSB_INC="/opt/local/include/libusb-1.0"
    LIBUSB_LIB="/opt/local/lib/libusb-1.0.dylib"
elif [[ -f /opt/homebrew/lib/libusb-1.0.dylib && -d /opt/homebrew/include/libusb-1.0 ]]; then
    LIBUSB_INC="/opt/homebrew/include/libusb-1.0"
    LIBUSB_LIB="/opt/homebrew/lib/libusb-1.0.dylib"
else
    echo "ERROR: libusb-1.0 not found in /opt/local or /opt/homebrew" >&2
    exit 1
fi
echo "Using libusb headers: $LIBUSB_INC"
echo "Using libusb dylib:   $LIBUSB_LIB"

# --- clean previous build ---
rm -rf "$BUILD_DIR" "$STAGE_DIR"
mkdir -p "$BUILD_DIR" "$STAGE_DIR"

# --- configure + build ---
cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
    -DLIBUSB_INCLUDE_DIR="$LIBUSB_INC" \
    -DLIBUSB_LIBRARIES="$LIBUSB_LIB" \
    -DDETACH_KERNEL_DRIVER=ON \
    -DINSTALL_UDEV_RULES=OFF \
    -DPROVIDE_PKGCONFIG_FILE=OFF

cmake --build "$BUILD_DIR" --target rtlsdr_shared --parallel "$(sysctl -n hw.logicalcpu)"

# librtlsdr's CMake produces librtlsdr.0.dylib (with versioned soname). Find it.
DYLIB_SRC=$(find "$BUILD_DIR/src" -maxdepth 1 -name "librtlsdr.*.dylib" -type f | head -1)
if [[ -z "$DYLIB_SRC" ]]; then
    DYLIB_SRC=$(find "$BUILD_DIR/src" -maxdepth 1 -name "librtlsdr.dylib" -type f | head -1)
fi
if [[ -z "$DYLIB_SRC" ]]; then
    echo "ERROR: built librtlsdr dylib not found in $BUILD_DIR/src" >&2
    exit 1
fi
echo "Built dylib: $DYLIB_SRC"

# --- assemble proper macOS framework (Versions/A layout) ---
FW_STAGE="$STAGE_DIR/$FW_NAME.framework"
mkdir -p "$FW_STAGE/Versions/A/Headers"
mkdir -p "$FW_STAGE/Versions/A/Modules"
mkdir -p "$FW_STAGE/Versions/A/Resources"

cp "$DYLIB_SRC" "$FW_STAGE/Versions/A/$FW_NAME"
chmod u+w "$FW_STAGE/Versions/A/$FW_NAME"

cp "$SRC_DIR/include/rtl-sdr.h" "$FW_STAGE/Versions/A/Headers/"
cp "$SRC_DIR/include/rtl-sdr_export.h" "$FW_STAGE/Versions/A/Headers/"

cat > "$FW_STAGE/Versions/A/Modules/module.modulemap" <<EOF
framework module $FW_NAME {
    umbrella header "rtl-sdr.h"
    export *
    module * { export * }
}
EOF

cat > "$FW_STAGE/Versions/A/Resources/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FW_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$FW_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FW_NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>$FW_VERSION_SHORT</string>
    <key>CFBundleVersion</key>
    <string>$FW_VERSION</string>
    <key>MinimumOSVersion</key>
    <string>$DEPLOY_TARGET</string>
</dict>
</plist>
EOF

# Versions/Current symlink + top-level symlinks
(cd "$FW_STAGE/Versions" && ln -s A Current)
(cd "$FW_STAGE" && ln -s Versions/Current/$FW_NAME $FW_NAME)
(cd "$FW_STAGE" && ln -s Versions/Current/Headers Headers)
(cd "$FW_STAGE" && ln -s Versions/Current/Modules Modules)
(cd "$FW_STAGE" && ln -s Versions/Current/Resources Resources)

# --- rewrite install names ---
BIN="$FW_STAGE/Versions/A/$FW_NAME"
install_name_tool -id "@rpath/$FW_NAME.framework/Versions/A/$FW_NAME" "$BIN"
# Replace any libusb reference with @rpath form. The exact path depends on the
# libusb the build linked against, so query it dynamically.
LIBUSB_REF=$(otool -L "$BIN" | awk '/libusb-1\.0/ {print $1; exit}')
if [[ -n "$LIBUSB_REF" ]]; then
    install_name_tool -change "$LIBUSB_REF" "@rpath/libusb-1.0.0.dylib" "$BIN"
fi

# --- ad-hoc sign the binary, then the framework ---
codesign --force --sign - "$BIN"
codesign --force --sign - "$FW_STAGE"

# --- wrap in xcframework ---
rm -rf "$XCF_OUT"
xcodebuild -create-xcframework \
    -framework "$FW_STAGE" \
    -output "$XCF_OUT"

# --- verify ---
echo
echo "=== Result ==="
echo "xcframework: $XCF_OUT"
otool -L "$XCF_OUT/macos-arm64/$FW_NAME.framework/Versions/A/$FW_NAME"
echo
echo "Framework layout:"
find "$XCF_OUT/macos-arm64/$FW_NAME.framework" -maxdepth 3 -print

rm -rf "$BUILD_DIR" "$STAGE_DIR"
echo
echo "Done."
