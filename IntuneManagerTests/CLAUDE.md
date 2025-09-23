## Organization
- Mirror the source tree: `Core` helpers → `*Tests.swift`, feature view models → `<Feature>Tests.swift`.
- Keep filenames suffixed with `Tests.swift` so Xcode discovers them automatically.

## Writing Tests
- Use `@testable import IntuneManager` for access to internal types.
- Favor targeted tests over broad integration. Exercise view models, services, and utility functions directly.
- For async APIs, mark tests with `async` and `await` the service calls; leverage `XCTExpectFailure` only when documenting known gaps.

## Fixtures & Helpers
- Stub Graph responses with lightweight structs or mocked data instead of hitting the network.
- Reuse helper factories for models (e.g., fake `Device` instances) to avoid duplication.

## Running Tests
- Default command: `xcodebuild test -scheme IntuneManager -destination 'platform=macOS,arch=arm64'` for shared logic.
- Add an iOS simulator destination when touching iOS-only code paths.
- Record command output and status in your summary per the root guide.
