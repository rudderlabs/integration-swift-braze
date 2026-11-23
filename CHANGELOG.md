# Changelog

## [4.0.0](https://github.com/rudderlabs/rudder-monorepo-swift/compare/integration-braze-3.0.1...integration-braze-4.0.0) (2026-11-23)


### ⚠ BREAKING CHANGES

* **braze:** require braze-swift-sdk-prebuilt-static 19 ([#79](https://github.com/rudderlabs/rudder-monorepo-swift/issues/79))

### Features

* **braze:** require braze-swift-sdk-prebuilt-static 19 ([#79](https://github.com/rudderlabs/rudder-monorepo-swift/issues/79)) ([595fb14](https://github.com/rudderlabs/rudder-monorepo-swift/commit/595fb14c4d70bd4a9b0c516813a7d072b371f012))
* log integrations through the instance logger ([#74](https://github.com/rudderlabs/rudder-monorepo-swift/issues/74)) ([d00be0c](https://github.com/rudderlabs/rudder-monorepo-swift/commit/d00be0c2e42dcd4677a0f9285ac14e4e137ddef3))

## [3.0.1](https://github.com/rudderlabs/rudder-monorepo-swift/compare/integration-braze-3.0.0...integration-braze-3.0.1) (2026-11-06)


### Code Refactoring

* **braze:** resolve SwiftLint findings ([#43](https://github.com/rudderlabs/rudder-monorepo-swift/issues/43)) ([81cfd7e](https://github.com/rudderlabs/rudder-monorepo-swift/commit/81cfd7e72b5e2f13084d371cadbaec8cc7865eb5))

## 3.0.0 - 2026-10-27

### Breaking changes

- Require RudderStack Swift SDK 2.0.0 or later, below 3.0.0.
- `create` now throws when the destination config is invalid or Braze does not initialise.

### Features

- Add an initialiser that takes your app's own Braze instance.

### Documentation

- State which Braze package the app must use.

## 2.0.0 - 2026-09-11

### Breaking changes

- Require Braze Swift SDK 18.2.0 or later, below 19.0.0, instead of 14.x.
  Apps using the native instance must follow [MIGRATION.md](MIGRATION.md).

### Validation

- Add real-SDK compatibility checks alongside the existing mock-adapter tests.
- Keep iOS 15, tvOS 15, the core Swift SDK requirement, and ecommerce mapping unchanged.
