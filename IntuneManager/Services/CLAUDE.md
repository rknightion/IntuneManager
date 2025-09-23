# Services Layer Guide

## Scope
- Applies to files under `IntuneManager/Services/`.
- Services mediate between Graph API, persistence, and UI-facing state. Keep them focused, composable, and concurrency-safe.

## Design Principles
- Expose async APIs that return models or throw `Error`; let callers decide how to present results.
- Retain shared instances via `static let shared` and enforce `@MainActor` for classes that publish state consumed by SwiftUI (`@Published` properties).
- Keep transient network helpers private. If multiple services need the same helper, move it into `Core`.

## Graph Integration
- Build requests with `GraphAPIClient`. Favor pagination helpers (`getAllPagesForModels`) and batching wrappers (`batchModels`) instead of raw loops.
- Respect rate limiting: delegate to `RateLimiter` before issuing bulk operations, and log when retries occur.
- Map responses into strongly-typed models from `Core/DataLayer/Models`. Extend these models rather than returning dictionaries.

## Persistence Coordination
- Keep `LocalDataStore` as the single source of truth for cached entities. Use its replace/fetch helpers instead of manually touching `ModelContext`.
- When mutating data, update both in-memory published arrays and the store so app restarts stay consistent.
- For destructive actions (wipes, deletes), provide audit-level logging via `Logger.shared.warning`.

## Error & Progress Handling
- Capture errors into the service's `@Published var error` so the UI can observe and react.
- Track loading state with `@Published var isLoading` and wrap long operations in `defer` blocks to reset flags.
- Offer convenience methods for filtering/searching to keep views lightweight (e.g., `DeviceService.searchDevices`).

## Testing Expectations
- Add unit coverage for new service methods to `IntuneManagerTests`, mocking Graph responses where feasible.
- Where side effects are complex, consider extracting pure helpers that can be tested independently.
