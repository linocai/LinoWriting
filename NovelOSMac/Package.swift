// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NovelOSMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NovelOSMac", targets: ["NovelOSMac"]),
        .library(name: "NovelOSMacCore", targets: ["NovelOSMacCore"]),
    ],
    targets: [
        .target(
            name: "NovelOSMacCore"
        ),
        .executableTarget(
            name: "NovelOSMac",
            dependencies: ["NovelOSMacCore"]
        ),
        .testTarget(
            name: "NovelOSMacTests",
            dependencies: ["NovelOSMacCore"],
            resources: [.process("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
