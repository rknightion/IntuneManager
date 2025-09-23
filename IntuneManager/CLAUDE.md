# IntuneManager Module Guide

## Scope
- Applies to everything inside `IntuneManager/`. Pair this with the repo root `CLAUDE.md` for global rules.
- Focus on keeping layering intact: App → Core → Services → Features → UI helpers.

## Layer Responsibilities
- **App/**: Entry scenes only. Compose environment objects (`AuthManagerV2`, `CredentialManager`, `AppState`) and host cross-platform shells (`UnifiedContentView`). Avoid business logic here.
- **Core/**: Reusable infrastructure. Keep dependencies pointing inward (Core should not import feature code). Split responsibilities across existing subfolders (Authentication, DataLayer, Networking, Security, CrossPlatform, UI). New shared helpers belong here only if they are platform-agnostic.
- **Services/**: Bridge Graph + persistence to the UI. Services may rely on Core but should not reference SwiftUI types. Maintain singleton access (`static let shared`) and ensure public APIs are `async` and `@MainActor` when mutating shared state.
- **Features/**: House SwiftUI `Views/` plus lightweight `ViewModels/`. Views talk to services and `AppState`; view models own state and orchestrate async calls. Keep navigation registration in `AppState.Tab` and `UnifiedContentView`.
- **Utilities/** & **Extensions/**: Shared helpers for logging, styling, or system extensions. Prefer extending existing types over inventing globals.

## State & Environment
- `AppState` drives navigation, loading, and color scheme preferences. If a feature needs new global state, add it to `AppState` with careful consideration of sidebar/tab impacts.
- Environment objects available across the app: `AuthManagerV2`, `CredentialManager`, and `AppState`. Avoid creating new singletons for view-only state—prefer view models scoped to features.

## Patterns to Follow
- Keep SwiftUI views declarative; push side effects into services or view models. Use `.task` or explicit async helpers rather than mixing `Task {}` blocks inside initializers.
- Reuse shared modifiers from `Core/CrossPlatform` and `Core/UI` (e.g., `platformGlassBackground`, `PlatformFormStyle`). Add new modifiers there for cross-cutting styling.
- When adding Graph-powered features: define Codable/SwiftData models under `Core/DataLayer/Models`, expose service APIs, then build feature views atop those services. Persist data via `LocalDataStore` if it should survive app relaunches.
- Extend `AppState.Tab` and `UnifiedSidebarView`/tab layout together to surface new top-level destinations.

## Platform Conditioning
- Keep platform checks centralized. Prefer helper abstractions (`PlatformNavigation`, `PlatformHelper`) to limit scattered `#if os` blocks.
- If a feature needs platform-specific UI, split the view into contained `#if os` sections or provide dedicated helper views per platform within the feature folder.

## Logging & Telemetry
- Use `Logger.shared` with categories (`.network`, `.ui`, `.auth`, `.persistence`) to keep logs structured. Avoid `print`.
- For recoverable errors, bubble `Error` up to view models so the UI can react (alerts, empty states) instead of swallowing silently.

## Adding New Modules
- New feature? Create `Features/<Name>/Views` (and optionally `ViewModels`/`Models`). Register navigation, hook into services, and add targeted tests.
- New background workflow? Consider `Services/` (for business processes) or `Core` if it’s infrastructural. Document required permissions in the feature-level README.
