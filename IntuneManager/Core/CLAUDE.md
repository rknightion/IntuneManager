# Core Layer Expectations

## Scope
- Applies to `IntuneManager/Core/*`. Follow root and `IntuneManager/CLAUDE.md` first; this file narrows rules for infrastructure code.

## Authentication
- `AuthManagerV2` and `SimpleMSALAuth` wrap MSAL. Keep all MSAL-facing changes here and out of the UI.
- Never hardcode tenant secrets; use placeholders and let `CredentialManager` supply runtime values.
- Surface auth state changes via published properties and `AuthError` enums so the UI can present meaningful alerts.

## DataLayer
- SwiftData models (`@Model`) must stay `Codable`, `Identifiable`, and `Sendable` when practical. Preserve `@Attribute(.unique)` markers to avoid duplicates.
- Add migrations thoughtfully: update `LocalDataStore` helpers when schemas evolve, and provide backfill logic to keep cached data consistent.
- `LocalDataStore` is the canonical persistence entry point. Call `configure(with:)` before use and prefer `replace*` helpers for bulk updates.

## Networking
- Use `GraphAPIClient` for all HTTP requests. Prefer generic helpers (`getModel`, `getAllPagesForModels`, `batchModels`) instead of reimplementing networking stacks.
- Respect `RateLimiter`: for new batching logic, ask it for batch sizes and delays rather than hardcoding sleeps.
- When introducing new endpoints, add typed request/response structs and extend `GraphAPIError` if needed—avoid returning raw dictionaries.

## Security
- `CredentialManager` manages secure storage via Keychain/SwiftData hybrids. Route new secrets here and expose async APIs that stay on the main actor when touching UI or SwiftData contexts.
- Keep keychain identifiers and access groups aligned with entitlements managed by Xcode (do not edit entitlements here).

## CrossPlatform & UI Helpers
- Add cross-platform abstractions (`PlatformNavigation`, `PlatformFormStyle`, haptics, file presenters) in `CrossPlatform` to centralize OS branching.
- Shared SwiftUI components (empty states, theming) belong under `UI/` and should avoid feature-specific knowledge.

## Concurrency & Testing
- Mark observable classes `@MainActor` when they mutate shared state consumed by SwiftUI.
- For async helpers returning to the UI, use `await MainActor.run { ... }` to publish changes safely.
- Add dedicated unit tests under `IntuneManagerTests` whenever Core API contracts change; treat networking additions as prime candidates for mocks or response fixtures.
