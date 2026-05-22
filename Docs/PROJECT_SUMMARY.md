# Project Summary

MathCLI is an iOS/iPadOS SwiftUI calculator app built around typed command execution, scientific expression input, session history, variables, user functions, operation browsing, and export/import workflows.

## Current Supported Surfaces

- Calculator: command input, scientific expressions, autocomplete suggestions, chained commands, quick operation buttons, session tabs, rename/switch/close behavior.
- History: active/past sessions, calculation details, bookmarks, search, delete, JSON export, Markdown export, destructive confirmations.
- Operations: categorized operation list and operation help.
- Settings: display/calculator preferences, app-data JSON export/import, destructive confirmations for clearing variables/functions.

## Current Feature Boundaries

- iOS/iPadOS only.
- Simulator-ready testing is the primary readiness bar.
- Physical-device deployment requires Apple provisioning and a registered iPhone UDID.
- Data analysis and transform operations are v1 array/file helpers.
- Plotting operations return deterministic summaries for later chart rendering.
- iCloud sync is future work and is not an active setting.
- Full DataFrame workspaces, rendered charts, widgets, Shortcuts/App Intents, and Mac Catalyst are future work.
- Expression input supports standard scientific-calculator operations, order of operations, assignment, constants, functions, and shared session variables.

## Verification

```bash
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS Simulator' -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -quiet test
```

## Known Technical Debt

- Matrix eigenvalue operations still emit an Accelerate CLAPACK deprecation warning.
- The repo has duplicate variable/function storage source paths; the Xcode target currently builds the top-level `MathCLI/Variables` and `MathCLI/Functions` files.
