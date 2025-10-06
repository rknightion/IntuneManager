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
- **Services (`IntuneManager/Services`)**: Graph orchestration sits here. Core fetchers (`DeviceService`, `ApplicationService`, `GroupService`, `SyncService`) now work alongside assignment workflow helpers (`AssignmentService`, `AssignmentImportService`, `AssignmentExportService`), compliance/audit utilities (`AuditLogService`), and the configuration pipeline (`ConfigurationService`, `ProfileValidationService`, `ProfileExportService`, `MobileConfigService`). Keep them actor-isolated, expose async APIs, and let them own progress/error publishing for the UI.
- **Features (`IntuneManager/Features`)**: Modules now cover Dashboard, Devices, Applications (Bulk Assignment workspace), Groups, Configuration (profiles/templates/mobileconfig), Reports, Settings, Setup, About, and TestAuth scaffolding. Views live under `Views/` with paired `ViewModels/` that compose services and `AppState`; extend existing folders instead of spawning ad-hoc navigation inside other features.
- **Utilities & Extensions**: Cross-cutting helpers like `Logger` and styling/Color extensions; prefer reusing these before adding new helpers.
- **Tests (`IntuneManagerTests`, `IntuneManagerUITests`)**: XCTest suites mirror the source structure. Add unit coverage alongside new functionality; gate UI flows with `@MainActor` tests when feasible.
- **Config**: `Config/AppInfo.plist` and other plist/entitlement files hold bundle metadata—update carefully and never commit secrets.

Data flows from Microsoft Graph through `GraphAPIClient` → `RateLimiter` → domain services (assignments, configuration, audit logging, mobileconfig) → SwiftData caches (`LocalDataStore` plus per-service in-memory state) → view models and SwiftUI views. Configuration operations route through validation/export helpers before pushing back to Graph. Funnel logging through `Logger.shared` rather than `print`.

## Multi-Platform Best Practices
- Maintain feature parity: when updating a feature view, it should render acceptably on macOS, iPad, and iPhone. Use `platformGlassBackground`, `PlatformNavigation`, and other cross-platform modifiers instead of ad-hoc device checks when possible.
- While we want compatability of our app for iOS and iPadOS the main target audience is MacOS and that should be prioritised where possible.
- Keep platform-specific code behind `#if os(...)` guards and isolate it in `CrossPlatform` helpers to avoid scattering conditionals.
- Respect concurrency annotations: UI-facing models stay `@MainActor`; background Graph work happens inside services actors or async functions with explicit `Sendable` models.
- Reuse `AppState.Tab` to surface new sections; update sidebar/tab registration and provide consistent icons and labels.
- When introducing new Graph endpoints, define Codable/`@Model` types in `Core/DataLayer/Models`, extend services to call them, and document required API permissions in the relevant feature README.
- Test workflows that diverge per platform: profile import/export uses macOS save panels while iOS relies on `UIDocumentPicker`, so verify both paths and provide safe defaults.
- Provide keyboard-friendly affordances for macOS-first flows (commands, menu items) and mirror them with touch UI so iPad/iPhone stay functional without duplicating views.
- Validate dynamic type, pointer interactions, and compact width layouts when adding Bulk Assignment or Configuration screens—they must remain legible in split view and tab contexts.

## Implementation Guardrails
- Prefer dependency injection through shared singletons already established (`DeviceService.shared`, etc.); if a new shared service is needed, expose it via the Services layer rather than from a view.
- For SwiftData models, keep stored properties `Codable`, provide default initializers, and add `@Attribute(.unique)` where identity matters.
- Use `Logger.shared` for observability; include `category` hints (`.network`, `.ui`) when available.
- Favor structured error types (`GraphAPIError`, `AuthError`) over generic `Error`; bubble meaningful messages to the UI via `AppState` or view models.
- Keep configuration UI (`ConfigurationView`, Settings) free of tenant-specific values—lean on `CredentialManager` and local secrets.

## Graph API Permission Management
**CRITICAL**: When adding features that require new Microsoft Graph API permissions, you MUST update `PermissionCheckService.requiredPermissions` to include the new scopes. This ensures startup permission validation catches missing permissions before users encounter errors.

- The app validates all required Graph permissions at startup via `PermissionCheckService.checkPermissions()` (called from `IntuneManagerApp.initializeApp()`).
- All required permissions are centrally defined in `IntuneManager/Services/PermissionCheckService.swift` in the `requiredPermissions` static array.
- Each permission entry documents its scope, description, and which features depend on it.
- When users lack required permissions, they see a detailed alert on startup with options to continue, copy the permission list, or view details in Settings.
- The service checks the access token's granted scopes and compares them against required permissions, logging any missing scopes.

**Workflow for adding new Graph-dependent features:**
1. Identify the Graph API permission(s) required for your feature (consult context7 library ID 'microsoftgraph/microsoft-graph-docs-contrib' or Microsoft Graph documentation).
2. Add the permission(s) to `PermissionCheckService.requiredPermissions` with:
   - `scope`: The exact Graph permission scope (e.g., "DeviceManagementConfiguration.ReadWrite.All")
   - `description`: Brief explanation of what this permission grants
   - `features`: Array of feature names that depend on this permission
3. Update `AuthManagerV2.signIn()` if the new scope should be requested during interactive sign-in (line 148-153 in `Core/Authentication/AuthManagerV2.swift`).
4. Test that the permission check detects missing permissions correctly by signing in with an account that lacks the new scope.

This centralized approach ensures permission requirements are visible, documented, and validated consistently across the entire application.

## Testing & Verification Expectations
- Expand the XCTest suite whenever you add new service logic, models, or complex UI state; place files under mirrors of the source path and suffix them with `Tests.swift`.
- Use `xcodebuild test` destinations that match the platform you touched (macOS for shared logic, add iOS simulator for iOS-only changes). Summarize results in your final message.
- For diagnostics and migrations, prefer targeted utility scripts over modifying production code paths.
