# Repository Guidelines

## Project Structure & Module Organization
IntuneManager is structured around a shared SwiftUI codebase that targets iOS and macOS. Key directories:
- `IntuneManager/App` hosts the entry point (`IntuneManagerApp.swift`) and root scenes.
- `IntuneManager/Core` groups authentication, data, networking, and cross-platform shims; add shared logic in the existing subfolders.
- `IntuneManager/Features` contains user-facing modules (Dashboard, Devices, Applications, Groups, Assignments, Setup) with SwiftUI views and view models.
- `IntuneManager/Services` encapsulates Graph and business workflows; `IntuneManager/Utilities` holds helpers such as logging.
- Configuration lives in `Config/AppInfo.plist` and `IntuneManager/IntuneManager.entitlements`; tests sit in `IntuneManagerTests` and `IntuneManagerUITests`.

## Build, Test, and Development Commands
- `open IntuneManager.xcodeproj` (or `xed .`) launches Xcode with the configured schemes.
- `xcodebuild -scheme IntuneManager -destination 'platform=iOS Simulator,name=iPhone 15' build` performs a clean CLI build for iOS.
- `xcodebuild test -scheme IntuneManager -destination 'platform=macOS,arch=arm64'` runs the macOS unit suite; add `-destination 'platform=iOS Simulator,name=iPhone 15'` for iOS.
- `swift package resolve` syncs dependency pins in `Package.resolved` before committing.

## Coding Style & Naming Conventions
- Target Swift 6 with strict concurrency; prefer async/await and `@MainActor` annotations for UI-facing services.
- Keep indentation at four spaces, organize files with `// MARK:` groups, and use `camelCase` for methods/properties plus `PascalCase` for types and SwiftData models.
- Place shared assets in `Assets.xcassets`; keep feature-specific views inside their feature module.
- Run formatting through Xcode’s “Re-indent Selection”; avoid committing generated project artifacts.

## Testing Guidelines
- Unit specs live in `IntuneManagerTests` (XCTest); mirror source folder names and suffix files with `Tests.swift`.
- UI flows belong in `IntuneManagerUITests`; gate new flows behind `@MainActor` tests when interacting with SwiftUI.
- Use `xcodebuild test` or Xcode’s ⌘U; add coverage assertions for Graph API error paths and authentication regressions where practical.

## Commit & Pull Request Guidelines
- Follow the existing Conventional Commit style (`fix(auth): …`, `chore(deps): …`); scope names should map to top-level modules.
- Each PR should include a concise summary, testing notes, and screenshots for visual changes on both platforms.
- Link Azure DevOps or GitHub issues when relevant and confirm MSAL client IDs or secrets remain in local configuration only.

## Security & Configuration Tips
- Update `MSALConfiguration.swift` with tenant-specific values via local secrets; never commit credentials.
- Ensure entitlements (`IntuneManager/IntuneManager.entitlements`) and `Config/AppInfo.plist` stay aligned with provisioning profiles before distributing builds.
- When adding new Graph endpoints, document required permissions in the feature folder’s README stub.
