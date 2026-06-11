// swift-tools-version:5.5

// Swift Package for AntennaHead macOS SDR app
// https://github.com/dsward2/AntennaHead
//
// librtlsdr is prebuilt via CMake and bundled as an XCFramework.
// The xcframework contains the dylib + public headers for arm64.
// To rebuild: see BUILD.md

import PackageDescription

let package = Package(
    name: "librtlsdr",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "librtlsdr",
            targets: ["librtlsdr"])
    ],
    targets: [
        .binaryTarget(
            name: "librtlsdr",
            path: "librtlsdr.xcframework")
    ]
)
