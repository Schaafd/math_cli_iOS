# MathCLI iOS

MathCLI is an iPhone/iPad SwiftUI calculator app that combines a terminal-style math prompt with a more familiar calculator surface. You can type commands such as `add 5 10`, write scientific expressions such as `7 + 9 * 2`, chain commands, reuse the previous answer, store variables, define functions, browse supported operations, and export session history.

For a full walkthrough of the app, including navigation, input modes, sessions, settings, and the built-in command reference, see [Docs/IOS_APP_GUIDE.md](Docs/IOS_APP_GUIDE.md).

## What The App Does

- Calculator tab for typed command entry, scientific expressions, autocomplete suggestions, pinned command buttons, session tabs, and command history.
- Command Drawer for browsing operations, reading command help, inserting commands into the prompt, and pinning commands to the quick command bar.
- Adjustable calculator and scientific-calculator drawers under the keyboard menu.
- Shared command and expression context, so variables, user functions, `$`, and `ans` work across both styles.
- History tab for searching, bookmarking, deleting, and exporting sessions to JSON or Markdown.
- Operations tab for category-based operation browsing and help.
- Settings tab for themes, calculator text font/color, app-data export/import, and confirmed destructive actions.

## Quick Start In The App

1. Open the Calculator tab.
2. Type either a command or a normal expression:

   ```text
   add 5 10
   7 + 9 * 2
   sqrt(16) + sin(0)
   ```

3. Tap the run button or use the keyboard return action.
4. Reuse the last result with `$` or `ans`:

   ```text
   multiply $ 3
   ans + 12
   ```

5. Store values for the session:

   ```text
   set x 7 + 9
   multiply $x 2
   x + ans
   ```

6. Tap the command grid button to open the Command Drawer. From there you can search commands, tap a command card for help, tap `Use` to insert it, or pin it to the command bar.

## Input Styles

MathCLI supports two complementary input styles in the same session.

Command syntax:

```text
operation argument1 argument2
add 5 10
mean 4 8 15 16 23 42
area_circle 3
```

Expression syntax:

```text
7 + 9 * 2
(7 + 9) * 2
sqrt(16) + power(2, 3)
radius = 12
pi * radius ^ 2
```

Command chains use `|`. The result of each step is passed as the first argument to the next step:

```text
add 7 2 | multiply 4 | subtract 6
```

## Current Scope

- iOS/iPadOS only. The Xcode project intentionally targets `iphoneos` and `iphonesimulator`.
- 200+ registered operations across arithmetic, trigonometry, statistics, number theory, matrix, calculus, conversions, data analysis, data transform, plotting summaries, export/import, variables, and user functions.
- Data analysis and transform operations are v1 array/file helpers, not a full DataFrame workspace.
- Plotting operations return deterministic chart-ready summaries. There is no Swift Charts UI in this pass.
- iCloud sync is future work and is not exposed as an active setting.

## Requirements

- Xcode 26.x with the iOS 26.5 simulator runtime installed for the current verified workflow.
- iOS deployment target: 17.6.
- Swift/XCTest through Xcode.

Physical-device builds require normal Apple development provisioning with a registered device. Simulator builds do not require that provisioning.

## Build And Test

Use Xcode or `xcodebuild` from the repo root.

```bash
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS Simulator' -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -quiet test
```

To launch the app manually, open the project in Xcode and run the `MathCLI` scheme on an iOS simulator.

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

## Documentation

- [Detailed iOS App Guide](Docs/IOS_APP_GUIDE.md): app navigation, workflows, input modes, settings, and full command reference.
- [Quick Reference](Docs/QUICK_REFERENCE.md): compact build/test and scope summary.
- [Project Summary](Docs/PROJECT_SUMMARY.md): current supported surfaces, boundaries, and technical debt.

## Known Technical Debt

- Matrix eigenvalue operations still call the deprecated CLAPACK entry point through Accelerate. Builds pass, but Xcode warns that the newer LAPACK compile path should be adopted with `ACCELERATE_NEW_LAPACK`.
- The repo contains older duplicate source paths for variable/function storage. The Xcode target currently builds the top-level `MathCLI/Variables` and `MathCLI/Functions` files, not the newer `MathCLI/Core/...` duplicates.
- Full DataFrame workflows, rendered charts, iCloud sync, widgets, Shortcuts/App Intents, and Mac Catalyst are future work.
