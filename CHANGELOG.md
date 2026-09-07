# Changelog

## Unreleased

### Breaking changes

- Require Braze Swift SDK 18.2.0 or later, below 19.0.0, instead of 14.x.
  The proposed integration release is 2.0.0. Apps using the native instance
  must follow [MIGRATION.md](MIGRATION.md).

### Validation

- Add real-SDK compatibility checks alongside the existing mock-adapter tests.
- Keep iOS 15, tvOS 15, the core Swift SDK requirement, and ecommerce mapping unchanged.
