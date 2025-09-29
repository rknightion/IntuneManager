# Naming Conventions

Consistent naming makes it easier to target assignments, locate devices, and audit changes. These conventions are recommendations based on Intune best practices and how IntuneManager displays data.

## Devices

| Attribute | Recommended pattern | Example |
| --- | --- | --- |
| Device name | `<Platform>-<Location>-<AssetTag>` | `MAC-LON-14325` |
| Category | `<Department>-<Role>` | `FIN-Field` |
| Notes | Key context for operators | `Loan device – return Oct 2024` |

Tips:
- Use uppercase abbreviations for platform prefixes (`MAC`, `WIN`, `IOS`, `AND`).
- Keep device names under 15 characters so they display cleanly in list view badges.
- Populate the **Notes** field for exceptions or temporary assignments—IntuneManager highlights them in the General tab.

## Azure AD device groups

| Group type | Naming scheme | Example |
| --- | --- | --- |
| Dynamic device | `DEV-<Platform>-<Scope>` | `DEV-MAC-FINANCE`
| Assigned device | `ASG-<App/Policy>-<Audience>` | `ASG-OfficeSuite-Exec`
| Filter group | `FLT-<Conditional>-<Purpose>` | `FLT-OS-18+`

Tips:
- Prefix dynamic groups with `DEV` (device), `USR` (user), or `APP` (app-based) to clarify membership.
- Use consistent scope descriptors such as `GLOBAL`, `REGION`, `DEPT`.
- Track filter logic in the group's description; IntuneManager surfaces the description beneath the group name.

## Configuration profiles

| Profile type | Naming scheme | Example |
| --- | --- | --- |
| Settings Catalog | `CFG-<Platform>-<Intent>-<Version>` | `CFG-MAC-FileVault-v3`
| Templates | `TPL-<Template>-<Audience>` | `TPL-Windows-Defender-Std`
| Custom | `CUS-<Platform>-<Policy>-<Ticket>` | `CUS-iOS-VPN-INC1042`

Tips:
- Append a semantic version (`v1`, `v2`) when iterating so you can track adoption in Reports.
- For custom `.mobileconfig` uploads, include the originating ticket or change number for quicker audits.

## Applications

| Type | Naming scheme | Example |
| --- | --- | --- |
| Store app | `APP-<Platform>-<StoreName>` | `APP-iOS-Outlook`
| LOB app | `APP-LOB-<Platform>-<Vendor>` | `APP-LOB-WIN-CustomERP`
| Web app | `APP-WEB-<Purpose>` | `APP-WEB-ServiceDesk`

Tips:
- Populate the **Publisher** field so the Dashboard shows a friendly source label.
- Use the **Notes** field to document installation requirements or post-install tasks.

## Assignments

IntuneManager displays assignment summaries using app and group names. Keep both concise and descriptive to avoid truncated strings.

- When creating groups for assignments, include the deployment intent (`REQ`, `AVL`, `UNINSTALL`).
- Assignment history stores the Graph ID; consider keeping a spreadsheet mapping assignment IDs to change requests if your organisation requires audit trails.

## Tags and filters

- Map business units to tags using the `Assignments` workspace's metadata so Reports can segment results.
- Use consistent label casing; tag names appear in Reports and the Dashboard legend.

Need more structure? Copy these tables into your internal documentation or update the [includes/abbreviations](includes/abbreviations.md) list with company-specific acronyms.
