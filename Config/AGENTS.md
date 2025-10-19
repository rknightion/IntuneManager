# Configuration Files

## Scope
- Applies to `Config/AppInfo.plist` and related metadata.

## Guidelines
- Treat plist changes as deliberate: mirror updates in Xcode's target settings to avoid drift.
- Do not embed secrets, client IDs, or bundle identifiers tied to production tenants; keep placeholders and rely on local overrides.
- When adding keys, document them in the feature README and ensure both iOS and macOS targets remain in sync.
- Avoid manual tweaks to entitlements or signing capabilities here—Xcode manages those per the root instructions.
