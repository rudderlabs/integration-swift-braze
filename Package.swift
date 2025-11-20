// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "integration-swift-braze",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RudderIntegrationBraze",
            targets: ["RudderIntegrationBraze"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/braze-inc/braze-swift-sdk-prebuilt-static", .upToNextMajor(from: "12.0.0")),
        // TODO: Update rudder-sdk-swift dependency after the stable release of rudder-sdk-swift.
        .package(url: "https://github.com/rudderlabs/rudder-sdk-swift.git", branch: "feat/sdk-502-make-standard-integration-public")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RudderIntegrationBraze",
            dependencies: [
                .product(name: "BrazeKit", package: "braze-swift-sdk-prebuilt-static"),
                .product(name: "RudderStackAnalytics", package: "rudder-sdk-swift")
            ]
        ),
        .testTarget(
            name: "RudderIntegrationBrazeTests",
            dependencies: ["RudderIntegrationBraze"]
        ),
    ]
)
