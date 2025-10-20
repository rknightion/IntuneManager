# Getting Started

This guide walks Microsoft Intune administrators through the steps required to deploy, configure, and sign in to IntuneManager on macOS. By the end you will have a signed-in session with live Intune data and understand the basics of the app layout.

## Prerequisites

Before you launch IntuneManager make sure you have:

- An Azure AD account with **Intune Administrator** or equivalent delegated permissions
- Access to the Microsoft Intune tenant that hosts the devices and applications you want to manage
- The ability to register an app in Azure AD or the details of an existing registration (Client ID, Tenant ID, redirect URI)
- Microsoft Graph delegated permissions ready for admin consent:
  - `DeviceManagementManagedDevices.Read.All`
  - `DeviceManagementManagedDevices.ReadWrite.All`
  - `DeviceManagementManagedDevices.PrivilegedOperations.All`
  - `DeviceManagementApps.Read.All`
  - `DeviceManagementApps.ReadWrite.All`
  - `DeviceManagementConfiguration.Read.All`
  - `DeviceManagementConfiguration.ReadWrite.All`
  - `Group.Read.All`
  - `GroupMember.Read.All`
  - `AuditLog.Read.All`
  - `User.Read`
  - `offline_access`
- macOS 15 hardware

> **Tip**: If you are testing from a managed device, make sure company portal policies allow third-party app installations.

## Register an Azure AD application

IntuneManager relies on MSAL for authentication. You can reuse an existing public client application if it already targets Microsoft Graph with the scopes above.

1. Navigate to the [Azure Portal](https://portal.azure.com) → **Azure Active Directory** → **App registrations** → **New registration**.
2. Choose a descriptive name such as `IntuneManager` and select **Accounts in this organizational directory only** unless you intend to manage multiple tenants.
3. Set the redirect URI to `msauth.<bundle-id>://auth`. The default bundle identifier is `com.rknightion.IntuneManager.macOS`.
4. After creation, copy the **Application (client) ID** and **Directory (tenant) ID**.
5. Go to **Authentication** → enable **Mobile and desktop applications** and confirm the redirect URI is listed.
6. Under **API permissions**, add the delegated Microsoft Graph permissions listed in the prerequisites and grant admin consent.

Optional but recommended:
- Configure a custom logo and publisher domain to match your organisation.
- Enable conditional access policies that apply to Intune administrators.

## Install IntuneManager

### macOS

1. Download or build the `.app` bundle for macOS from your preferred distribution channel (TestFlight, direct download, or internal software catalog).
2. Move the app to `/Applications`.
3. Launch IntuneManager. The first run displays a splash screen while the local database is initialised.

## Complete the setup wizard

Before sign-in IntuneManager asks for registration details so that MSAL can initialise correctly.

1. On the **Welcome** screen select **Configure Tenant**.
2. Enter the **Client ID** and **Tenant ID** captured from Azure AD.
3. Leave the redirect URI set to the displayed default unless your registration uses a custom URI. Click **Copy** to store it in the clipboard if you need to verify Azure AD configuration.
4. (Optional) Enable **Use client secret** if you configured a confidential client. For standard public clients leave this off.
5. Choose **Save & Continue**. IntuneManager validates the input and writes it to the secure keychain.
6. When prompted, select **Sign in with Microsoft**.

If validation fails, double-check tenant spelling, confirm Graph permissions were granted, and verify your network allows outbound requests to `login.microsoftonline.com` and `graph.microsoft.com`.

## Sign in and consent

1. When the Microsoft sign-in screen appears, authenticate with your Intune administrator account.
2. If the app has not been consented, review the requested permissions and choose **Accept**. You only need to consent once per tenant unless scopes change.
3. When sign-in completes you are returned to IntuneManager. A banner confirms the tenant and signed-in user.

IntuneManager stores tokens securely using MSAL's keychain integration. If your macOS environment uses the sandbox, ensure keychain sharing is permitted or the app will surface a `-34018` warning.

## Initial data sync

After authentication the app performs an initial fetch of devices, applications, groups, and assignment statistics.

- The **Dashboard** populates with total devices, apps, and recent assignment activity.
- **Devices** loads the managed devices list, applying your tenant's default sort order.
- **Applications** preloads apps for bulk assignment scenarios.
- **Groups** loads Azure AD device groups for targeting.

You can track progress via the loading overlay at the top of the window. The initial sync uses cached data when available, so subsequent launches are faster.

## Navigating the app

- **Sidebar / Tab bar**: Access Dashboard, Devices, Applications, Groups, Configuration, Reports, and Settings.
- **Command bar (macOS)**: Use `⌘R` to refresh, `⌘⇧A` to jump straight to bulk assignments, and `⌘⇧C` to copy highlighted data (coming soon).
- **Filters**: Many lists include a filter toggle in the toolbar. On macOS the filter drawer appears inline alongside the primary content.

Spend a few minutes exploring each area. The [Supported Entities](supported-entities.md) page explains what you can do in each section.

## Verify permissions

If you see a **Permission Required** alert:

1. Note the listed Microsoft Graph permissions.
2. Confirm the signed-in account has the necessary delegated access.
3. In Azure AD, grant admin consent again or escalate to a Global Administrator.

The alert includes a shortcut to **Settings → Permissions** so you can review the tenant configuration without leaving the app.

## Next steps

- Learn how IntuneManager inventories devices across platforms in [Device Support](device-support.md).
- Review [Bulk assignment workflows](supported-entities.md#applications) to deploy apps faster.
- Check the [FAQ](faq.md) for troubleshooting tips and known limitations.

When you're ready to roll the app out to a wider audience, share the [User Guide site](index.md) and consider adding your own branding assets in the `/docs/images` directory.
