# Workflow Setup Status

The old script-based workflow document was stale. The current project workflow is Xcode-first and uses direct `xcodebuild` commands from the repo root.

## Verified Commands

```bash
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS Simulator' -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -quiet build
xcodebuild -project MathCLI.xcodeproj -scheme MathCLI -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -quiet test
```

## Notes

- No maintained helper scripts currently exist in this repo.
- Simulator development is ready without physical-device provisioning.
- Physical-device deployment still requires an Apple team, registered device UDID, and a matching iOS App Development provisioning profile.
- Matrix/Accelerate deprecation warnings are non-blocking technical debt.
