# Building librtlsdr.xcframework

The xcframework in this repo is prebuilt. To rebuild it from source:

## Prerequisites

- Xcode (non-App Store, full install)
- CMake (`port install cmake`)
- libusb-1.0 (`port install libusb`)

## Build steps

```bash
# arm64 (Apple Silicon)
mkdir build-arm64 && cd build-arm64
cmake .. \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DLIBUSB_INCLUDE_DIR=/opt/local/include/libusb-1.0 \
  -DLIBUSB_LIBRARIES=/opt/local/lib/libusb-1.0.dylib \
  -DDETACH_KERNEL_DRIVER=ON
make -j$(sysctl -n hw.logicalcpu)
cd ..

# Assemble .framework
mkdir -p build-arm64/librtlsdr.framework/Headers
mkdir -p build-arm64/librtlsdr.framework/Modules
cp build-arm64/src/librtlsdr.dylib build-arm64/librtlsdr.framework/librtlsdr
install_name_tool -id "@rpath/librtlsdr.framework/librtlsdr" \
  build-arm64/librtlsdr.framework/librtlsdr
cp include/rtl-sdr.h include/rtl-sdr_export.h \
  build-arm64/librtlsdr.framework/Headers/

# Copy Info.plist and module.modulemap (see existing files in the xcframework)

# Create xcframework
xcodebuild -create-xcframework \
  -framework build-arm64/librtlsdr.framework \
  -output librtlsdr.xcframework
```

## Note on x86_64

MacPorts libusb is arm64-only on Apple Silicon. To add x86_64 support,
provide an x86_64 libusb-1.0.dylib and add a second `-framework` argument
to the `xcodebuild -create-xcframework` invocation.
