// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TNEFSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
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
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "TNEFSwift",
            dependencies: ["ZIPFoundation"],
            path: "Sources",
            sources: ["Core", "Extractors", "Models", "Utils"]),
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
