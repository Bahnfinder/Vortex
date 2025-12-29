// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Vortex",
    platforms: [.iOS(.v15), .macOS(.v12), .macCatalyst(.v15), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Vortex",
            targets: ["Vortex"])
    ],
    dependencies: [
        .package(url: "https://github.com/efremidze/Haptica.git", from: "4.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Vortex",
            dependencies: [
                .product(name: "Haptica", package: "Haptica", condition: .when(platforms: [.iOS]))
            ],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "VortexTests",
            dependencies: ["Vortex"])
    ]
)
