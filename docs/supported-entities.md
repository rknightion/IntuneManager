# Supported Entities

IntuneManager organises Microsoft Intune information into dedicated workspaces. This page summarises what each workspace exposes and how to accomplish common tasks.

## Dashboard

- **Snapshot metrics**: Total devices, managed applications, assignment counts, and deployed apps for the selected time range (24 hours, 7 days, 30 days).
- **Compliance chart**: Doughnut chart showing compliant vs non-compliant devices.
- **Platform distribution**: Chart of platforms detected across your fleet.
- **Assignment trends**: When assignment statistics are available, the dashboard pairs them with assignment progress from the bulk assignment module.
- **Usage tips**: Switch ranges from the header, or revisit later after running bulk assignments to see updated KPIs.

## Devices

- **Search & filters**: Filter by compliance, encryption, supervision, ownership, platform, manufacturer, and device category.
- **Row actions**: Trigger a Graph `syncDevice` action or open detailed tabs for hardware, management, compliance, security, and network information.
- **Batch operations**: Use **Sync Visible Devices** to queue sync requests for the filtered subset of devices.
- **Permission handling**: Failures display the required Graph scope and offer a shortcut to Settings.

## Applications

- **Bulk assignment workspace**: Select multiple applications, choose target groups, and apply assignment intents (Required, Available, Uninstall).
- **Platform detection**: The view model determines supported platforms from Graph metadata and warns if selections are incompatible.
- **Assignment preview**: See existing assignments for each group and avoid duplicates before submitting.
- **Progress tracker**: Progress HUD tracks batch submission, retries, and verification. Completed assignments persist in history for review.

## Groups

- **Directory-backed**: Lists Azure AD device groups available for targeting assignments and configuration profiles.
- **Search**: Search by display name; Graph queries hydrate members when necessary.
- **Selection helper**: Quick toggles highlight built-in assignment targets.

## Configuration

- **Profile browser**: Split view showing configuration profiles by platform and type (Settings Catalog, Templates, Custom). Filter by platform or profile type.
- **Profile details**: Inspect assignments, settings, deployment status, and last modified dates.
- **Create & edit**: Launch profile creation from templates or edit existing profiles (name, description) directly.
- **Assignments**: Update assignments with multi-select group pickers and filter assistance.
- **Import/export**: Upload `.mobileconfig` payloads for Apple platforms and export profile JSON for backup.

## Reports

- **Assignment statistics**: Fetch Intune assignment KPIs (total assignments, apps with deployments, success/failure counts).
- **Device compliance overview**: Table summarising compliance states across platforms.
- **Top deployed apps**: Ranked list of applications by assignment reach.
- **Recent activity**: Dedicated audit log browser with time range and item limits. Tap an entry to open the detail sheet or export JSON.

## Settings

- **Account**: Review the current user, tenant, and sign out.
- **Configuration**: Re-run the setup wizard to change tenant IDs, redirect URI, or client secret usage.
- **Data management**: Inspect cache status, clear local data, or export aggregated logs.
- **Appearance**: Toggle light/dark themes (macOS View menu) or follow system appearance.

## About

Access the About screen from the macOS **IntuneManager → About IntuneManager** menu. The sheet summarises the app version, build number, and licensing information.

For a deeper architectural look, continue to [Architecture](architecture.md) or read [APIs & Performance](api-optimization.md) for data flow details.
