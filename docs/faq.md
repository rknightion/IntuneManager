# FAQ

A collection of frequently asked questions collected during internal deployments of IntuneManager.

## Can I use IntuneManager without registering my own Azure AD application?

Not today. IntuneManager is a public client that relies on MSAL configuration stored locally. Registering your own application keeps credentials in your control and makes it easier to audit Graph API usage.

## Why do I see a `-34018` keychain error on macOS?

macOS sandboxing can prevent MSAL from writing tokens to the keychain, generating error `-34018`. Run the app outside the sandbox, grant Keychain Sharing to the bundle, or use an app-specific password manager profile. See the alert text for remediation steps.

## The device list is empty after sign-in. What should I check?

1. Confirm the signed-in account has the `DeviceManagementManagedDevices.Read.All` permission.
2. Open **Settings → Data Management** and verify caching is enabled.
3. Use the toolbar to refresh (`⌘R` on macOS). Watch the status banner for Graph API errors.
4. If nothing appears, open **Reports → Recent Activity** to review audit logs for failed device listings.

## How often does IntuneManager refresh data?

- Dashboard metrics update each time you visit the tab.
- Device, Application, and Group lists fetch on first load and cache subsequent visits for the session.
- Use the toolbar refresh button or `Settings → Refresh All` to force a tenant-wide refresh.
- Device sync triggers (`Sync Visible Devices`) queue an Intune sync request immediately and refresh after the Graph API confirms completion.

## Can I perform remote actions like wipe or retire?

Device actions beyond sync are currently read-only. Remote wipe, retire, or restart commands will ship in a future release once audit and permission flows are complete.

## What assignment types does the bulk assignment feature support?

Bulk assignment supports Required, Available for enrolled devices, and Uninstall intents. Use the assignment settings drawer to choose filters or specify installation behaviors per group.

## Does IntuneManager support multiple tenants?

You can reconfigure the tenant from **Settings → Configuration → Modify Configuration**. Tenant details are stored locally, so switching tenants requires re-authentication and cache clearing.

## Where are logs stored?

- macOS: `~/Library/Containers/com.rknightion.IntuneManager/Data/Library/Logs/IntuneManager/`
- iOS/iPadOS: accessible via the **Export Logs** button in Settings when running in debug builds.

Attach logs to any support request so we can trace Graph API responses.

## How do I update to a new version?

Install the new build over the top of the existing one. Your configuration, cached data, and tokens remain unless you explicitly clear data from Settings.

## What accessibility features are available?

IntuneManager uses dynamic type, VoiceOver labels, and high-contrast color tokens from SF Symbols. A manual light/dark appearance toggle is located in the macOS **View** menu and the iOS Settings view.

## Which languages are supported?

The interface currently ships in English (en). All Graph API data displays in the language configured for your Intune tenant.

Have a question that is not listed? Open an issue via the [IntuneManager repository](https://github.com/rknightion/IntuneManager/issues).
