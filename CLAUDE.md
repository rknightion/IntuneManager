# Claude Operator Guide

## Read Me First
- Follow any direct instructions within this file as you edit. Ensure this file and any relevant CLAUDE.md files in sub directories is kept up to date as the project evolves with any significant architecture changes or new best practices introduced but do not update this file for every minor change only significant ones that would be useful for a future LLMs context
- Use context7 MCP server when searching for library documentation. Use context7 library ID 'microsoftgraph/microsoft-graph-docs-contrib' for all information about the microsoft graph API. Search there first for any required information before doing generic web searches but also you should verify context obtained from context7 with web searches where you are not confident of a result

## Non-Negotiable Rules
- Never run git commands that mutate history or remotes (`git commit`, `git push`, `git reset --hard`, etc.). Local diff inspection (`git status`, `git diff`) is fine.
- After any change that alters executable Swift code, build settings, or dependencies, validate compilation by running `XcodeBuildMCP - build_run_macos (MCP)(projectPath: "/Users/rob/repos/IntuneManager/IntuneManager.xcodeproj", scheme: "IntuneManager", configuration: "Debug")` before declaring the task complete.
- Treat every compiler **ERROR** as blocking: resolve them before you summarize or hand off.
- Leave code signing, provisioning profiles, and entitlements management to Xcode unless the user gives explicit instructions; avoid editing `IntuneManager/IntuneManager.entitlements` or signing-related build settings.

## Claude Workflow Principles
- Begin with context gathering: read the impacted files end-to-end and summarize intent before editing.
- For anything non-trivial, draft a plan (even a short checklist) and keep it updated as you execute.
- Ask clarifying questions early when requirements or acceptance criteria seem ambiguous.
- Work in small, verifiable steps; prefer focused diffs that include tests or instrumentation where practical.
- Narrate verification: when you run builds or tests, summarize what command ran and whether it passed.
- Surface risks, regressions, or open questions alongside your changes so humans can follow up.

## Architecture Overview
- **App Layer (`IntuneManager/App`)**: `IntuneManagerApp` bootstraps global singletons (`AuthManagerV2`, `CredentialManager`, `AppState`) and wires platform-specific scenes. `UnifiedContentView` adapts navigation between macOS split-view and iOS/tab layouts.
- **Core Layer (`IntuneManager/Core`)**: Shared infrastructure split into Authentication (MSAL glue), DataLayer (SwiftData models & `LocalDataStore` cache), Networking (`GraphAPIClient` + `RateLimiter`), Security (`CredentialManager`), CrossPlatform shims, and shared UI components.
- **Services (`IntuneManager/Services`)**: `DeviceService`, `ApplicationService`, `GroupService`, `AssignmentService`, `SyncService` orchestrate Graph requests, caching, and business flows. They centralize async work on the main actor and hydrate the SwiftData store.
- **Features (`IntuneManager/Features`)**: User-facing modules (Dashboard, Devices, Applications, Groups, Assignments, Reports, Settings, Setup). Each feature keeps SwiftUI views under `Views/` and supporting models or view models under `ViewModels/`, consuming shared services instead of duplicating logic.
- **Utilities & Extensions**: Cross-cutting helpers like `Logger` and styling/Color extensions; prefer reusing these before adding new helpers.
- **Tests (`IntuneManagerTests`, `IntuneManagerUITests`)**: XCTest suites mirror the source structure. Add unit coverage alongside new functionality; gate UI flows with `@MainActor` tests when feasible.
- **Config**: `Config/AppInfo.plist` and other plist/entitlement files hold bundle metadata—update carefully and never commit secrets.

Data flows from the Microsoft Graph through `GraphAPIClient` → rate-limited batch helpers → Services → SwiftData `LocalDataStore` → environment-bound view models and SwiftUI views. Logging runs through `Logger.shared` so new work should surface key events there rather than `print`.

## Multi-Platform Best Practices
- Maintain feature parity: when updating a feature view, it should render acceptably on macOS, iPad, and iPhone. Use `platformGlassBackground`, `PlatformNavigation`, and other cross-platform modifiers instead of ad-hoc device checks when possible.
- While we want compatability of our app for iOS and iPadOS the main target audience is MacOS and that should be prioritised where possible.
- Keep platform-specific code behind `#if os(...)` guards and isolate it in `CrossPlatform` helpers to avoid scattering conditionals.
- Respect concurrency annotations: UI-facing models stay `@MainActor`; background Graph work happens inside services actors or async functions with explicit `Sendable` models.
- Reuse `AppState.Tab` to surface new sections; update sidebar/tab registration and provide consistent icons and labels.
- When introducing new Graph endpoints, define Codable/`@Model` types in `Core/DataLayer/Models`, extend services to call them, and document required API permissions in the relevant feature README.

## Implementation Guardrails
- Prefer dependency injection through shared singletons already established (`DeviceService.shared`, etc.); if a new shared service is needed, expose it via the Services layer rather than from a view.
- For SwiftData models, keep stored properties `Codable`, provide default initializers, and add `@Attribute(.unique)` where identity matters.
- Use `Logger.shared` for observability; include `category` hints (`.network`, `.ui`) when available.
- Favor structured error types (`GraphAPIError`, `AuthError`) over generic `Error`; bubble meaningful messages to the UI via `AppState` or view models.
- Keep configuration UI (`ConfigurationView`, Settings) free of tenant-specific values—lean on `CredentialManager` and local secrets.

## Testing & Verification Expectations
- Expand the XCTest suite whenever you add new service logic, models, or complex UI state; place files under mirrors of the source path and suffix them with `Tests.swift`.
- Use `xcodebuild test` destinations that match the platform you touched (macOS for shared logic, add iOS simulator for iOS-only changes). Summarize results in your final message.
- For diagnostics and migrations, prefer targeted utility scripts over modifying production code paths.