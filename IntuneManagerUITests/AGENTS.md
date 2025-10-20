# UI Test Guidance

## Strategy
- Target the primary macOS flows: authentication shell, sidebar navigation, and the critical workflows (device search, assignment wizard).
- Rely on accessibility identifiers rather than positional queries so tests remain resilient across window sizes.
- Add coverage for the configuration hub (profile list → detail → mobileconfig upload) and bulk assignment wizard to ensure their multi-step state machines behave on macOS.

## Implementation Tips
- Wrap expensive setup in helper methods to keep tests readable.
- Use `@MainActor` where UI operations interact with SwiftUI app state.
- Reset global singletons (`DeviceService`, `ApplicationService`, etc.) between tests to avoid state leakage.

- ## Execution
- Run UI suites via `xcodebuild test -scheme IntuneManager -destination 'platform=macOS'`.
- Note pass/fail results in your final report and capture logs when failures occur.
- For file import/export tests, prefer injecting mock document URLs via test doubles rather than relying on real file pickers.
