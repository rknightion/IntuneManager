# Operations & Productivity

Although the file name says "development", this guide focuses on power-user workflows and productivity tools when operating IntuneManager day to day.

## Keyboard shortcuts (macOS)

| Command | Shortcut |
| --- | --- |
| Refresh current workspace | `⌘R` |
| Open Bulk Assignment workspace | `⌘⇧A` |
| Copy highlighted item (lists) | `⌘C` |
| Toggle Appearance picker | `⌘,` in the View menu |
| Sign out | `⌘⇧Q` |
| Open Settings | `⌘,` |

> iPad hardware keyboards support `⌘+` navigation shortcuts on a subset of screens. Hold `⌘` to show the native iPad shortcut overlay.

## Multi-window on macOS

IntuneManager supports additional windows for focused tasks:

- **Assignments Overview**: `Window → Assignments Overview` opens a secondary window with assignment metrics.
- **Reports pop-outs**: Right-click charts to open them in stand-alone windows (macOS 15 feature).
- **Split view**: Use macOS split view or Stage Manager to reference Configuration profiles while triaging Devices.

## Data caching

IntuneManager uses SwiftData for local persistence. The cache reduces Graph API calls and keeps the app responsive offline.

- **Cache hydrate**: On launch `LocalDataStore` hydrates Device, Application, Group, and Assignment data before hitting the network.
- **Auto-expiry**: Metadata older than 30 minutes is refreshed automatically when you revisit a tab.
- **Manual reset**: Settings → Data Management → Clear All Data wipes caches and tokens (you will need to sign in again).

## Permissions awareness

The app surfaces Graph permission requirements whenever an operation fails with `403 Forbidden`.

- Alerts include the exact scope required.
- Selecting **View Settings** opens the configuration sheet so you can inspect the tenant quickly.
- All permission alerts are logged via `Logger.shared` for later review.

## Platform differences

| Feature | macOS | iPadOS | iOS |
| --- | --- | --- | --- |
| Navigation | Sidebar split view | Sidebar split view | Tab bar |
| Multi-window | ✅ | ✅ (Stage Manager) | ❌ |
| Drag & drop | Copy text into other macOS apps | Drag charts into Notes/Freeform | Not supported |
| Clipboard | System clipboard | Universal clipboard | Universal clipboard |

## Offline behaviour

- After a successful sign-in IntuneManager can browse cached data offline.
- Actions that require Graph (sync, assignment, fetch) queue and report an error if the device is offline.
- When connectivity returns, use the refresh command to retry failed operations.

## Exporting logs

1. Open **Settings** and scroll to **Data Management**.
2. Choose **Export Logs**.
3. macOS saves logs to the Desktop; iOS/iPadOS opens the share sheet.

Include the exported archive and an approximate timestamp when submitting feedback.

## Troubleshooting workflow

1. Check the toast banner or notice in the header for contextual errors.
2. Visit **Reports → Recent Activity** to confirm Microsoft Graph received the request.
3. Re-run the action; if it fails, review the log file for detailed Graph responses.
4. Submit an issue with reproduction steps and logs.

For developer-specific information, keep an eye on the public repository; internal architecture notes are covered in [Architecture](architecture.md).
