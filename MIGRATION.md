# Migrating to RudderIntegrationBraze 2.0.0

This release requires Braze Swift SDK `>=18.2.0, <19.0.0`, replacing 14.x.
It is a major integration release because apps can access native Braze APIs
through `getDestinationInstance()`.

The integration still supports iOS 15 and tvOS 15. Its core RudderStack Swift
SDK requirement remains unchanged. This package uses Swift Package Manager,
not the older Rudder-Braze CocoaPod.

## Upgrade

1. Use Xcode 26 or later. CI selects Xcode 26.2.
2. Select RudderIntegrationBraze 2.x after publication.
3. Update any direct Braze package requirement to allow 18.2.x.
4. Keep BrazeKit and BrazeUI on the same resolved version.
5. Resolve dependencies and rebuild the app.

## Native API changes

- Banner `onDismiss` receives `Braze.BannerDismissalEvent`, not a Banner.
- Dismiss a Banner on the main thread with `banner.context?.dismiss()`,
  or `banner.dismiss(using: braze)` when no context exists.
- Initialization and user changes are non-blocking. Prefer asynchronous
  getters for user IDs and Content Cards in latency-sensitive code.
- Content Card caches update immediately after interactions. Disabling cards
  clears the cache, and user changes notify subscribers.
- Remove `preventInAppMessageDisplayForDifferentUser`; isolation is always enabled.
- Replace removed Live Activities token-update APIs with state subscriptions.
- Native typed Product Viewed events use `type`, not `typeIdentifiers`.
  This integration keeps its existing dictionary-based ecommerce mapping.

See the [Braze 18.2.0 changelog](https://github.com/braze-inc/braze-swift-sdk/blob/18.2.0/CHANGELOG.md)
for the complete upstream migration, including Mac Catalyst and WebView APIs.
This upgrade does not add logout behavior or change the ecommerce opt-in flag.

## Release verification

Automated tests and example builds do not establish live campaign delivery.
Before publication, use an isolated test source and audience to verify:

- Identify, immediate traits/events, and switching between two test users.
- Banner display, programmatic dismissal, callback identifiers, refresh, and restart.
- Push registration/delivery and foreground in-app-message presentation.

Record live results separately in SDK-5373. Do not reuse the older iOS
integration's campaign evidence as proof for this Swift package.
