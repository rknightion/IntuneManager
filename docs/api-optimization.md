# API & Performance

IntuneManager interacts with Microsoft Graph extensively. Understanding how the app optimises requests helps administrators plan tenant-wide rollouts and stay within service throttling limits.

## Request batching and throttling

- **Device sync**: The batch sync feature queues Graph `/managedDevices/{id}/syncDevice` requests sequentially with a short delay to avoid hitting the per-minute limit.
- **Bulk assignments**: Assignments are chunked into batches of 20 (Graph maximum) and submitted concurrently. Each batch retries up to three times with exponential backoff.
- **Configuration profiles**: Profile listings use `$select` queries to limit payload size and `$expand=assignments` only when the detail view is opened.

## Caching strategy

- **SwiftData cache**: Device, application, group, assignment, and configuration entities persist locally. Cached items hydrate views instantly and reduce repeated Graph calls.
- **Staleness checks**: `CacheMetadata` stores the last refresh timestamp per entity. If an entity is older than 30 minutes, the service fetches fresh data.
- **Manual override**: Toolbar refresh buttons pass `forceRefresh: true` to services, bypassing the cache.

## Error resilience

- **Permission mapping**: `AppState.handlePermissionError` translates Graph errors into actionable permission names shown to the user.
- **Rate limit handling**: When Graph returns `429`, IntuneManager respects the `Retry-After` header and delays the batch before retrying.
- **Partial failure reporting**: Bulk assignment progress indicates how many assignments succeeded, failed, or were skipped due to existing deployments.

## Data shape improvements

- **Projection models**: Services map Graph responses into lightweight SwiftData models to avoid costly conversions in the view layer.
- **Lazy associations**: Large collections (installed apps, assignment history) load on demand to keep memory usage predictable.
- **Platform inference**: Application platform detection intersects supported platforms across selected apps to guarantee compatible group targeting.

## Network endpoints

| Feature | Graph endpoint | Notes |
| --- | --- | --- |
| Device inventory | `/deviceManagement/managedDevices` | Uses `$top` paging and delta tokens (coming soon) |
| Device sync | `/deviceManagement/managedDevices/{id}/syncDevice` | Requires `DeviceManagementManagedDevices.PrivilegedOperations.All` |
| Applications | `/deviceAppManagement/mobileApps` | `$select` for assignment metadata |
| App assignments | `/deviceAppManagement/mobileApps/{id}/assign` | Wrapper handles payload formatting |
| Groups | `/groups` with filters | Prefers device security groups |
| Configuration profiles | `/deviceManagement/configurationPolicies` and `/deviceManagement/configurationSettings` | Handles both Settings Catalog and template profiles |
| Audit logs | `/auditLogs/directoryAudits` | Filtered by activity type and timestamp |

## Monitoring usage

Use Reports → Recent Activity to verify Graph calls. The audit log entry lists the target resource, actor, and result. Pair this with Azure Portal sign-in logs when auditing delegated permission usage.

Future enhancements include delta queries for managed devices, background refresh tasks, and server-driven throttling hints. Track progress in the [changelog](changelog.md).
