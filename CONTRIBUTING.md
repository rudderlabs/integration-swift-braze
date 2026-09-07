# Contributing to RudderStack

Thanks for taking the time and for your help in improving this project!

## Table of contents

- [**RudderStack Contributor Agreement**](#rudderstack-contributor-agreement)
- [**How you can contribute to RudderStack**](#how-you-can-contribute-to-rudderstack)
- [**Committing**](#committing)
- [**Getting help**](#getting-help)

## RudderStack Contributor Agreement

To contribute to this project, we need you to sign the [**Contributor License Agreement (“CLA”)**][CLA] for the first commit you make. By agreeing to the [**CLA**][CLA], we can add you to list of approved contributors and review the changes proposed by you.

## How you can contribute to RudderStack

If you come across any issues or bugs, or have any suggestions for improvement, you can navigate to the specific file in the [**repo**](https://github.com/rudderlabs/integration-swift-braze), make the change, and raise a PR.

You can also contribute to any open-source RudderStack project. View our [**GitHub page**](https://github.com/rudderlabs) to see all the different projects.

## Committing

We prefer squash or rebase commits so that all changes from a branch are committed to master as a single commit. All pull requests are squashed when merged, but rebasing prior to merge gives you better control over the commit message.

## Getting help

For any questions, concerns, or queries, you can start by asking a question in our [**Slack**](https://rudderstack.com/join-rudderstack-slack-community/) community.

### We look forward to your feedback on improving this project!


<!----variables---->

[CLA]: https://rudderlabs.wufoo.com/forms/rudderlabs-contributor-license-agreement

## Validation

CI uses macOS 15 and Xcode 26.2. Select that installation before running the
same commands locally:

```sh
export DEVELOPER_DIR=/Applications/Xcode_26.2.app/Contents/Developer
xcodebuild -version
```

Run package tests on an available iOS simulator:

```sh
xcrun simctl list devices available
xcodebuild test -scheme RudderIntegrationBraze \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -derivedDataPath DerivedData/tests \
  -resultBundlePath /tmp/braze-package-tests.xcresult \
  CODE_SIGNING_ALLOWED=NO
xcrun xcresulttool get test-results summary \
  --path /tmp/braze-package-tests.xcresult
```

Use an unused result-bundle path for each run. CI requires a nonzero test
count and no failures. Tests use a mock Braze adapter and placeholder
configuration; no customer credentials or live campaign are required.
Passing these tests does not prove native Braze SDK behavior.

Build both supported platforms and the Example:

```sh
xcodebuild build -scheme RudderIntegrationBraze \
  -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData/ios CODE_SIGNING_ALLOWED=NO
xcodebuild build -scheme RudderIntegrationBraze \
  -destination 'generic/platform=tvOS' \
  -derivedDataPath DerivedData/tvos CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Example/Example.xcodeproj -scheme Example \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData/example CODE_SIGNING_ALLOWED=NO
```

Install the iOS and tvOS platform components in Xcode before building.
The Example references the package in this checkout, independent of its
folder name. CI builds the Example but does not launch it.

The workflow uploads build logs and the test result bundle for 14 days,
including failed runs. Dependency requirements are defined in `Package.swift`.

### Native compatibility tests

`NativeTests` provides an empty application host because Braze accesses
notification APIs that cannot run in a hostless package-test process.
It checks real-SDK request serialization for immediate user switches, traits,
events, purchases, aliases, and flush. A separate Objective-C test compiles
and calls the public wrapper. CI runs this suite independently of mock tests.

```sh
xcodebuild test -project NativeTests/NativeTests.xcodeproj \
  -scheme NativeBrazeTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -derivedDataPath DerivedData/native \
  -resultBundlePath /tmp/braze-native-tests.xcresult CODE_SIGNING_ALLOWED=NO
```

The native test uses a generated dummy key and a reserved `.invalid`
endpoint. Expected DNS failures do not establish delivery success.
Assertions inspect JSON from the SDK's request logger. They can require
updates if a future SDK changes its diagnostic format.

For live Banner checks, configure the Example for an isolated test source,
identify an eligible test user, and enter the campaign placement in the
Banner panel. The panel starts with an empty placement and does not load
a campaign automatically. Never commit customer credentials.
