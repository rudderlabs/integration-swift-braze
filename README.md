<p align="center">
  <a href="https://rudderstack.com/">
    <img alt="RudderStack" width="512" src="https://raw.githubusercontent.com/rudderlabs/rudder-sdk-js/develop/assets/rs-logo-full-light.jpg">
  </a>
  <br />
  <caption>The Customer Data Platform for Developers</caption>
</p>
<p align="center">
  <b>
    <a href="https://rudderstack.com">Website</a>
    ·
    <a href="https://rudderstack.com/docs/">Documentation</a>
    ·
    <a href="https://rudderstack.com/join-rudderstack-slack-community">Community Slack</a>
  </b>
</p>

---


# Braze Integration

The Braze integration allows you to send your event data from RudderStack to Braze for customer engagement, marketing automation, and analytics.

> This SDK fully supports both Swift and Objective-C and can be used seamlessly in either type of project.

## Installation

### Swift Package Manager

Add the Braze integration to your Swift project using Swift Package Manager:

1. In Xcode, go to `File > Add Package Dependencies`
    <img width="960" height="540" alt="add_package_dependency" src="https://github.com/user-attachments/assets/56f2673c-127b-4766-b570-c07523c6bda4" />
2. Enter the package repository URL: `https://github.com/rudderlabs/integration-swift-braze` in the search bar
3. Select the version you want to use
    <img width="1075" height="597" alt="image" src="https://github.com/user-attachments/assets/0ea6c8d1-efeb-4589-a92c-d1763a19e63e" />
4. Select the target to which you want to add the package
5. Finally, click on **Add Package**

    <img width="650" height="289" alt="image" src="https://github.com/user-attachments/assets/dde6889d-3966-42f6-96e3-7919a0bf2d58" />

Alternatively, add it to your `Package.swift` file:

```swift
// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YourApp",
    products: [
        .library(
            name: "YourApp",
            targets: ["YourApp"]),
    ],
    dependencies: [
        // Add the Braze integration
        .package(url: "https://github.com/rudderlabs/integration-swift-braze.git", .upToNextMajor(from: "<latest_version>"))
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "RudderIntegrationBraze", package: "integration-swift-braze")
            ]),
    ]
)
```

### Braze package

The integration depends on the static Braze package, `braze-swift-sdk-prebuilt-static`. If your app also adds Braze itself, for example for lite mode or for `BrazeUI`, it must use the same package. Swift Package Manager cannot build an app that gets Braze from two packages. The build then fails with `multiple similar targets 'BrazeKit' ... appear in package`.

If your app uses another Braze package, for example `braze-swift-sdk`, do one of these:

- Replace it with `https://github.com/braze-inc/braze-swift-sdk-prebuilt-static`. The product names are the same, for example `BrazeKit` and `BrazeUI`.
- Keep it, and add a Swift Package Manager mirror from your Braze package to the static package:
  - In a Swift package, run this in the package folder:

    ```bash
    swift package config set-mirror --original https://github.com/braze-inc/braze-swift-sdk --mirror https://github.com/braze-inc/braze-swift-sdk-prebuilt-static
    ```

  - In an Xcode project, add the file `YourApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/configuration/mirrors.json` with the content below. Add an empty file `config.lock` in the same folder.

    ```json
    {
      "object" : [
        {
          "mirror" : "https://github.com/braze-inc/braze-swift-sdk-prebuilt-static",
          "original" : "https://github.com/braze-inc/braze-swift-sdk"
        }
      ],
      "version" : 1
    }
    ```

  Then delete `Package.resolved` and resolve the packages again.

## Supported Native Braze SDK Version

This integration supports Braze iOS SDK version:

```
12.0.0+
```

### Platform Support

The integration supports the following platforms:
- iOS 15.0+
- tvOS 15.0+

## Usage

Initialize the RudderStack SDK and add the Braze integration:

```swift
import RudderStackAnalytics
import RudderIntegrationBraze

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Initialize the RudderStack Analytics SDK
        let config = Configuration(
            writeKey: "<WRITE_KEY>",
            dataPlaneUrl: "<DATA_PLANE_URL>"
        )
        let analytics = Analytics(configuration: config)

        // Add Braze integration
        analytics.add(plugin: BrazeIntegration())

        return true
    }
}
```

Replace:
- `<WRITE_KEY>`: Your project's write key from the RudderStack dashboard
- `<DATA_PLANE_URL>`: The URL of your RudderStack data plane

## Recommended ecommerce events

The integration can map supported RudderStack ecommerce `track` events to [Braze recommended ecommerce events](https://www.braze.com/docs/user_guide/data/activation/events/recommended_events) (`ecommerce.*`). This is opt-in via the `useEcommerceRecommendedEvents` destination flag (configured in the RudderStack dashboard) and defaults to **off** — when off, track handling is unchanged.

When enabled, the following events are mapped:

| RudderStack event | Braze event                  | action   |
| ----------------- | ---------------------------- | -------- |
| Product Viewed    | `ecommerce.product_viewed`   | —        |
| Product Added     | `ecommerce.cart_updated`     | `add`    |
| Product Removed   | `ecommerce.cart_updated`     | `remove` |
| Checkout Started  | `ecommerce.checkout_started` | —        |
| Order Completed   | `ecommerce.order_placed`     | —        |
| Order Refunded    | `ecommerce.order_refunded`   | —        |
| Order Cancelled   | `ecommerce.order_cancelled`  | —        |

Notes:

- Event names match case-insensitively after trimming. `Cart Viewed` and `Cart Updated` are not mapped and fall through to the generic custom-event path.
- With the flag on, `Order Completed` emits `ecommerce.order_placed` instead of the legacy purchase call.
- The mapping never drops or rejects an event: values are coerced to Braze's expected type where the conversion is lossless, unmapped properties are preserved under `metadata`, and missing required fields or type mismatches are surfaced as warnings while the event is still sent.

---

## Contact us

For more information:

- Email us at [docs@rudderstack.com](mailto:docs@rudderstack.com)
- Join our [Community Slack](https://rudderstack.com/join-rudderstack-slack-community)

## Follow Us

- [RudderStack Blog](https://rudderstack.com/blog/)
- [Slack](https://rudderstack.com/join-rudderstack-slack-community)
- [Twitter](https://twitter.com/rudderstack)
- [YouTube](https://www.youtube.com/channel/UCgV-B77bV_-LOmKYHw8jvBw)
