# UI Test Guidance

## Strategy
- Target the primary cross-platform flows: authentication shell, sidebar/tab navigation, critical workflows (device search, assignment wizard).
- Keep scenarios platform-agnostic when possible by using accessibility identifiers rather than positional queries.

## Implementation Tips
- Wrap expensive setup in helper methods to keep tests readable.
- Use `@MainActor` where UI operations interact with SwiftUI app state.
- Reset global singletons (`DeviceService`, `ApplicationService`, etc.) between tests to avoid state leakage.

## Execution
- Run via `xcodebuild test -scheme IntuneManager -destination 'platform=iOS Simulator,name=iPhone 15'` (and macOS target if the scenario requires it).
- Note pass/fail results in your final report and capture logs when failures occur.
