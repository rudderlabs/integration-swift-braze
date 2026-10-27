# Changelog

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
