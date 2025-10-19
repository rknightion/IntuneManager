# Configuration Feature Guidance

## Scope
- Applies to `IntuneManager/Features/Configuration/*` (profile list, detail editors, import/export, validation, and mobileconfig upload flows).
- Follow the parent `IntuneManager/Features/CLAUDE.md` and `IntuneManager/Services/CLAUDE.md`; this file documents feature-specific expectations.

## Architecture Overview
- `ConfigurationViewModel` hydrates data through:
  - `ConfigurationService.shared` for Graph CRUD and template/profile fetching.
  - `ProfileValidationService.shared` for validation/ conflict analysis reports.
  - `ProfileExportService.shared` for JSON export/import, and `MobileConfigService.shared` for `.mobileconfig` uploads.
- `ConfigurationListView` presents profiles/templates and routes to detail screens. Detail views should consume view-model bindings rather than touching services directly.
- Assignment editing flows reuse `ConfigurationAssignmentView` and must round-trip through `ConfigurationService.updateProfileAssignments` to stay in sync.

## Implementation Guidelines
- Keep Graph mutation logic in the services; view models should only coordinate calls and update published collections.
- When introducing new validation checks, extend `ProfileValidationService` and ensure UI surfaces both errors and warnings clearly.
- Mobileconfig ingestion should validate payload metadata before hitting Graph—use `MobileConfigService.validateMobileConfig` and surface results in the upload sheet.
- File import/export must use cross-platform document helper APIs so macOS save panels and iOS document pickers behave consistently.
- Template-driven creation flows should map settings through the existing conversion helpers (`toConfigurationProfile`, `toGraphSettingInstance`). Add new helpers alongside the model definitions if needed.
- Update `AppState.handlePermissionError` mappings when new configuration operations require additional Graph scopes.

## UX Considerations
- Provide clear status indicators (`ProfileStatusView`) for validation results and assignment state; avoid silent failures.
- Keep editing surfaces responsive: long-running operations (validation, assignments) should display progress or disabled states until completion.
- Maintain accessibility by setting descriptive labels on segmented controls, pickers, and status badges.

## Testing Tips
- Add unit tests for new validation rules or conversion helpers under `IntuneManagerTests/Configuration` with representative Graph payload fixtures.
- UI automation should cover profile creation, validation, and mobileconfig upload on both macOS and iOS destinations.
