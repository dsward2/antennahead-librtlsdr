# Building librtlsdr.xcframework

This Swift Package wraps a prebuilt `librtlsdr.xcframework` for consumption by
the AntennaHead macOS app. The C source lives in `librtlsdr-src/`, brought in
via `git subtree` from https://github.com/librtlsdr/librtlsdr.

## Prerequisites

- Xcode command-line tools
- CMake (`port install cmake` or `brew install cmake`)
- libusb-1.0 (`port install libusb` or `brew install libusb`)

## Rebuilding the xcframework

After modifying `librtlsdr-src/`, regenerate the xcframework:

```bash
./build.sh
```

This will:
- Configure + build librtlsdr for macOS arm64 via CMake
- Assemble a properly-structured macOS framework (Versions/A/... layout)
- Rewrite libusb references to `@rpath/libusb-1.0.0.dylib`
- Ad-hoc sign the binary and framework
- Wrap in `librtlsdr.xcframework/`

Commit the regenerated `librtlsdr.xcframework/` and push. The AntennaHead app
picks up changes via SPM after **File → Packages → Update to Latest Package
Versions** (or by bumping its pin).

## Bundling libusb

The framework references libusb at `@rpath/libusb-1.0.0.dylib`. The consuming
app is responsible for shipping that dylib alongside the framework (typically
in `Contents/Frameworks/` via an Embed Frameworks phase).

## Pulling upstream librtlsdr changes

```bash
git subtree pull --prefix=librtlsdr-src \
    https://github.com/librtlsdr/librtlsdr.git master --squash
```
