# MathCLI iOS

MathCLI is an iPhone/iPad SwiftUI calculator app with terminal-style command entry, session history, variables, user-defined functions, operation browsing, and JSON/Markdown export paths.

## Current Scope

- iOS/iPadOS only. The Xcode project intentionally targets `iphoneos` and `iphonesimulator`.
- 200+ registered operations across arithmetic, statistics, number theory, matrix, calculus, conversions, data analysis, data transform, plotting summaries, export/import, variables, and user functions.
- Data analysis and transform operations are v1 array/file helpers, not a full DataFrame workspace.
- Plotting operations return deterministic chart-ready summaries. There is no Swift Charts UI in this pass.
- iCloud sync is future work and is not exposed as an active setting.

## Requirements

- Xcode 26.x with the iOS 26.5 simulator runtime installed for the current verified workflow.
- iOS deployment target: 17.6.
- Swift/XCTest through Xcode.

## Build And Test

Use Xcode or `xcodebuild` from the repo root.

```bash
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS Simulator' -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -quiet test
```

Physical-device builds still require normal Apple development provisioning with a registered device. Simulator builds do not require that provisioning.

## App Features

- Calculator tab with command entry, autocomplete suggestions, quick operations, chained commands, `$`/`ans` references, and session tabs.
- History tab with active/past sessions, bookmarks, search, JSON export, Markdown export, and confirmation for destructive clearing.
- Operations tab with categorized operation help.
- Settings tab with display/calculator preferences, app data export/import, and confirmation for clearing variables/functions.

## Export Schema

Session export is versioned JSON:

```json
{
  "version": 1,
  "exportedAt": "ISO-8601 timestamp",
  "sessions": [
    {
      "id": "UUID",
      "name": "Session name",
      "createdAt": "ISO-8601 timestamp",
      "isActive": true,
      "commands": [
        {
          "id": "UUID",
          "command": "add 5 10",
          "result": "15",
          "timestamp": "ISO-8601 timestamp",
          "isBookmarked": false,
          "bookmarkName": null
        }
      ]
    }
  ]
}
```

Settings app-data export includes the same session snapshots plus current variables and user-defined functions.

## Known Technical Debt

- Matrix eigenvalue operations still call the deprecated CLAPACK entry point through Accelerate. Builds pass, but Xcode warns that the newer LAPACK compile path should be adopted with `ACCELERATE_NEW_LAPACK`.
- The repo contains older duplicate source paths for variable/function storage. The Xcode target currently builds the top-level `MathCLI/Variables` and `MathCLI/Functions` files, not the newer `MathCLI/Core/...` duplicates.
- Full DataFrame workflows, rendered charts, iCloud sync, widgets, Shortcuts/App Intents, and Mac Catalyst are future work.
