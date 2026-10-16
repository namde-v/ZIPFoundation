// swift-tools-version:5.9
import PackageDescription

#if os(Windows)
// Windows has no system zlib.h and no pkg-config, and clang-cl rejects the
// `#import`s in Sources/CZLib/shim.h, so the systemLibrary target below
// cannot work there. Instead compile the vendored zlib 1.3.1 sources
// (Sources/CZLibWin) as a regular C target. The module is still named CZlib,
// so the Swift sources need no changes and compression keeps working.
// (os(Windows) is checked first, matching the port's own manifests; tools
// 5.9+ is required for the Windows platform condition in manifests.)
let targets: [Target] = [
    .target(name: "CZlib", path: "Sources/CZLibWin"),
    .target(name: "ZIPFoundation", dependencies: ["CZlib"]),
    .testTarget(name: "ZIPFoundationTests", dependencies: ["ZIPFoundation"])
]
#elseif canImport(Compression)
let targets: [Target] = [
    .target(name: "ZIPFoundation"),
    .testTarget(name: "ZIPFoundationTests", dependencies: ["ZIPFoundation"])
]
#else
let targets: [Target] = [
    .systemLibrary(name: "CZLib", pkgConfig: "zlib", providers: [.brew(["zlib"]), .apt(["zlib"])]),
    .target(name: "ZIPFoundation", dependencies: ["CZlib"], cSettings: [.define("_GNU_SOURCE", to: "1")]),
    .testTarget(name: "ZIPFoundationTests", dependencies: ["ZIPFoundation"])
]
#endif

let package = Package(
    name: "ZIPFoundation",
    platforms: [
        .macOS(.v10_11), .iOS(.v9), .tvOS(.v9), .watchOS(.v2)
    ],
    products: [
        .library(name: "ZIPFoundation", targets: ["ZIPFoundation"])
    ],
    targets: targets,
    swiftLanguageVersions: [.v4, .v4_2, .v5]
)
