# MathCLI Development Workflow

This repo is currently an Xcode iOS/iPadOS app project. There are no maintained helper shell scripts in the repo, so use Xcode or `xcodebuild` directly.

## Daily Commands

From `/Users/davidschaaf/projects/mathCLI_App`:

```bash
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS Simulator' -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -quiet test
```

The first command verifies simulator compilation. The second verifies the iOS device build graph without requiring signing. The third runs unit and UI tests on the iPhone 17 / iOS 26.5 simulator.

## Xcode Use

Use Xcode for:

- Interactive simulator runs.
- Breakpoints and console debugging.
- SwiftUI previews.
- Profiling and Instruments.
- Physical-device signing once an iPhone UDID is registered in Apple Developer.

## Simulator Testing Scope

The simulator-ready baseline covers:

- Calculator launch and command execution.
- Suggestions for partial operation names.
- Session creation, renaming, and switching.
- History persistence, search, bookmarks, and export schema.
- Operation browser category/help display.
- Settings data export/import and destructive confirmation flows.

Simulator readiness does not prove physical-device provisioning. Device deployment still depends on Apple account/device/profile setup.

## Feature Scope

- Data analysis and transform operations are v1 array/file helpers.
- Plotting operations return deterministic summaries suitable for later chart rendering.
- iCloud sync is deferred and should stay documented as future work only.
- Full DataFrame workspaces, Swift Charts rendering, widgets, Shortcuts/App Intents, and Mac Catalyst are not in the current supported build.

## Non-Blocking Warning

Matrix eigenvalue operations still use an Accelerate CLAPACK symbol. Xcode emits a deprecation warning and recommends the newer LAPACK compile path with `ACCELERATE_NEW_LAPACK`. The warning does not block simulator builds or tests, but it should be handled before calling the matrix layer production-polished.
