# Feature Module Playbook

## Scope
- Applies to folders under `IntuneManager/Features/`.
- Read root and parent guides first; this file addresses SwiftUI feature work specifically.

## Structure & Naming
- Keep `Views/`, `ViewModels/`, and `Models/` subfolders as needed. Views own layout, view models own async orchestration, and any feature-specific data types live alongside them.
- Suffix view models with `ViewModel` and keep them `@MainActor` `ObservableObject`s.
- Group related components with `// MARK:` sections to maintain readability; follow four-space indentation.

## Working with Services
- Interact with business logic through the singleton services (`DeviceService.shared`, etc.). Do not perform Graph calls directly in views.
- When a feature needs new service behavior, extend the relevant service first, then consume it from view models.
- Use `AppState` for cross-feature navigation or shared loading indicators instead of inventing new globals.

## Multi-Platform UI
- Prefer platform shims (`platformGlassBackground`, `PlatformNavigation`) for visual parity. Where divergence is unavoidable, wrap it in `#if os` blocks scoped to the smallest view possible.
- Validate new UI on macOS, iPad, and iPhone. Consider adaptive layouts (split view vs tab view) and keep accessibility labels descriptive.

## State & Error Handling
- Manage transient state inside view models (`@Published`). Views should bind to derived properties (e.g., `filteredDevices`) rather than re-filtering collections ad hoc.
- Surface recoverable issues through alerts, toasts, or inline messaging. Log errors via `Logger.shared` and propagate readable messages for the UI.

## Navigation & Tabs
- Register new top-level destinations by updating `AppState.Tab`, `UnifiedSidebarView`, and `UnifiedContentView` together. Provide icons from SF Symbols compatible with all platforms.
- For drill-down flows, use `NavigationStack` and consider extracting destination views into their own files for clarity.

## Testing Hooks
- For complex state machines, add unit tests under `IntuneManagerTests` mirroring the feature folder. Keep logic that can be tested (sorting, filtering) inside view models or standalone helpers.
- When UI automation is warranted, add scenarios to `IntuneManagerUITests` with clear accessibility identifiers.
