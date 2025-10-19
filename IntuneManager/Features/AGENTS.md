# Feature Module Playbook

## Scope
- Applies to folders under `IntuneManager/Features/`.
- Read root and parent guides first; this file addresses SwiftUI feature work specifically.

## Structure & Naming
- Keep `Views/`, `ViewModels/`, and `Models/` subfolders as needed. Views own layout, view models own async orchestration, and any feature-specific data types live alongside them.
- Suffix view models with `ViewModel` and keep them `@MainActor` `ObservableObject`s.
- Group related components with `// MARK:` sections to maintain readability; follow four-space indentation.
- Place multi-step wizards (Bulk Assignment, Configuration) under their dedicated feature folders so they can evolve without bloating generic modules like Applications.

## Working with Services
- Interact with business logic through the singleton services (`DeviceService.shared`, etc.). Do not perform Graph calls directly in views.
- When a feature needs new service behavior, extend the relevant service first, then consume it from view models.
- Use `AppState` for cross-feature navigation or shared loading indicators instead of inventing new globals.
- For assignment/configuration flows, subscribe to the service's published progress instead of duplicating timers or counters inside the view model.

## Multi-Platform UI
- Prefer platform shims (`platformGlassBackground`, `PlatformNavigation`) for visual parity. Where divergence is unavoidable, wrap it in `#if os` blocks scoped to the smallest view possible.
- Validate new UI on macOS, iPad, and iPhone. Consider adaptive layouts (split view vs tab view) and keep accessibility labels descriptive.
- File import/export views must rely on the cross-platform document helper APIs. Test `.fileImporter`/`.fileExporter` flows and provide fallbacks for platforms that lack certain UTIs.

## State & Error Handling
- Manage transient state inside view models (`@Published`). Views should bind to derived properties (e.g., `filteredDevices`) rather than re-filtering collections ad hoc.
- Surface recoverable issues through alerts, toasts, or inline messaging. Log errors via `Logger.shared` and propagate readable messages for the UI.
- When surfacing long-running work (bulk assignments, profile validations), expose progress structs/enums from the service and reflect them in the view (.overlay, banners) so users know what is happening.

## Navigation & Tabs
- Register new top-level destinations by updating `AppState.Tab`, `UnifiedSidebarView`, and `UnifiedContentView` together. Provide icons from SF Symbols compatible with all platforms.
- For drill-down flows, use `NavigationStack` and consider extracting destination views into their own files for clarity.
- Keep Applications tab focused on the bulk-assignment workspace; use dedicated detail views under `Features/Applications` for per-app insight.
- Configuration-specific navigation (profile detail, template editors, mobileconfig upload) should stay inside `Features/Configuration` and push via `NavigationStack` or sheets to avoid leaking domain state to other tabs.

## Testing Hooks
- For complex state machines, add unit tests under `IntuneManagerTests` mirroring the feature folder. Keep logic that can be tested (sorting, filtering) inside view models or standalone helpers.
- When UI automation is warranted, add scenarios to `IntuneManagerUITests` with clear accessibility identifiers.

## Specialized Modules
- **BulkAssignment** and **Configuration** have their own `CLAUDE.md` files—consult them for workflow specifics before changing wizard steps, validators, or import/export logic.
