# Quick Reference

## Build

```bash
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS Simulator' -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -quiet build
```

## Test

```bash
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -quiet test
```

## App Scope

- iOS/iPadOS only.
- Calculator, History, Operations, and Settings tabs are the supported surfaces.
- Calculator input accepts both command syntax (`add 5 10`) and scientific expressions (`7 + 9 * 2`, `sqrt(16) + sin(0)`).
- Expressions and commands share variables, user functions, `$`, and `ans`.
- The command bar is customizable through the Command Drawer, and the keyboard menu switches between command-bar, calculator, and scientific input panels.
- History exports current/all sessions to JSON or Markdown.
- Settings exports/imports app data as JSON.
- Destructive Settings/History actions require confirmation.
- iCloud sync, rendered charts, full DataFrame workspaces, widgets, Shortcuts/App Intents, and Mac Catalyst are future work.

## Known Build Warning

The matrix eigenvalue operation still emits an Accelerate CLAPACK deprecation warning. Builds and tests pass; adopting the newer LAPACK compile path is tracked as technical debt.
