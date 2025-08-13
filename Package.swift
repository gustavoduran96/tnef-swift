// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TNEFSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "TNEFSwift",
            targets: ["TNEFSwift"]),
        .executable(
            name: "TNEFSwiftDemo",
            targets: ["TNEFSwiftDemo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "TNEFSwift",
            dependencies: ["ZIPFoundation"],
            path: "Sources/TNEFSwift"),
        .executableTarget(
            name: "TNEFSwiftDemo",
            dependencies: ["TNEFSwift", "ZIPFoundation"],
            path: "Sources",
            sources: ["main.swift"]),
        .testTarget(
            name: "TNEFSwiftTests",
            dependencies: ["TNEFSwift"],
            path: "Tests"),
    ]
)
