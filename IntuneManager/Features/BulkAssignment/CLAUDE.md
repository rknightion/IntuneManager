# Bulk Assignment Guidance

## Scope
- Applies to `IntuneManager/Features/BulkAssignment/*` (views and view models backing the Applications tab workspace).
- Read parent `IntuneManager/Features/CLAUDE.md` first; this file covers the bulk-assignment specific workflow.

## Architecture Notes
- `BulkAssignmentViewModel` orchestrates selection state and delegates execution to services:
  - `AssignmentService.shared` performs the actual Graph writes and publishes `AssignmentProgress`.
  - `AssignmentImportService.shared`/`AssignmentExportService.shared` validate JSON payloads for backup/restore.
  - Conflict and intent validation lives in `Core/Utilities/AssignmentConflictDetector.swift` and `AssignmentIntentValidator.swift`; extend those helpers instead of duplicating logic here.
- Views should bind directly to `viewModel.progress`, `completedAssignments`, and `failedAssignments` so they stay in sync with service updates.

## Implementation Guidelines
- Keep selection UI (`ApplicationSelectionView`, `GroupSelectionView`, etc.) declarative; mutations belong in the view model.
- When adding new progress phases, extend `AssignmentService.AssignmentProgress` and surface them through the view model rather than adding local timers.
- File import/export must use the shared helpers (`fileImporter`, `fileExporter`) so macOS save/open panels stay consistent.
- Respect platform affordances: provide keyboard shortcuts for macOS (toolbar buttons or `Commands`) and touch-friendly labels for iPad/iPhone.
- After successful operations, call `AppState.refreshAll()` or targeted service fetches so other tabs reflect changes.

## Testing Tips
- Unit-test changes to selection/validation logic in `IntuneManagerTests/BulkAssignmentViewModelTests` (create if missing) with canned application/group fixtures.
- Add fixture JSON under tests when adjusting import/export schemas so both services and the view model exercise the same sample payloads.
