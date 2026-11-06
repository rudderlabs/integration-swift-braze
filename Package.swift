// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "RudderIntegrationBraze",
    platforms: [.iOS(.v15), .tvOS(.v15)],
    products: [.library(name: "RudderIntegrationBraze", targets: ["RudderIntegrationBraze"])],
    dependencies: [.package(url: "https://github.com/rudderlabs/rudder-sdk-swift.git", from: "2.0.0"), .package(url: "https://github.com/braze-inc/braze-swift-sdk-prebuilt-static", .upToNextMajor(from: "18.2.0"))],
    targets: [.target(name: "RudderIntegrationBraze", dependencies: [.product(name: "RudderStackAnalytics", package: "rudder-sdk-swift"), .product(name: "BrazeKit", package: "braze-swift-sdk-prebuilt-static")])]
)
