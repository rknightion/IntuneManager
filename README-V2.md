# IntuneManager v2

A powerful, native macOS/iOS/iPadOS application for efficiently managing Microsoft Intune devices with secure credential management and MSAL v2 authentication.

## 🚀 What's New in v2

- **Secure Credential Management**: No hardcoded credentials - configure on first run
- **MSAL v2 Authentication**: Updated to use latest Microsoft Authentication Library
- **Enhanced Session Management**: Automatic token refresh and expiration handling
- **First-Run Configuration**: Easy setup wizard for Azure AD credentials
- **Improved Error Handling**: Better error messages and recovery options

## Overview

IntuneManager solves the pain points of managing hundreds of applications in Microsoft Intune through the web interface. Built with SwiftUI and leveraging the Microsoft Graph API, it provides a fast, native experience across all Apple platforms.

### Key Features

- **Bulk App Assignment**: Assign multiple applications to multiple device groups in seconds
- **Secure Authentication**: MSAL v2 with automatic token refresh
- **Native Performance**: Built with SwiftUI for blazing-fast performance
- **Cross-Platform**: Works seamlessly on macOS, iOS, and iPadOS
- **Smart Caching**: Intelligent caching reduces API calls and improves responsiveness
- **Batch Operations**: Process hundreds of assignments efficiently with progress tracking
- **Modern Architecture**: Modular, extensible design for future enhancements

## Requirements

- macOS 13.0+ / iOS 16.0+ / iPadOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- Microsoft Azure AD Application Registration
- Microsoft Intune License

## Setup Instructions

### 1. Azure AD App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Click **New registration**
4. Configure the application:
   - **Name**: `IntuneManager`
   - **Supported account types**: Choose based on your organization:
     - Single tenant (most secure)
     - Multitenant (for multiple organizations)
     - Personal Microsoft accounts (not recommended for Intune)
   - **Redirect URI**:
     - Platform: **Mobile and desktop applications**
     - URI: `msauth.YOUR-BUNDLE-ID://auth`
     - Example: `msauth.com.yourorg.intunemanager://auth`
5. After registration, note down:
   - **Application (client) ID** (e.g., `12345678-1234-1234-1234-123456789012`)
   - **Directory (tenant) ID** (e.g., `87654321-4321-4321-4321-210987654321`)

### 2. Configure API Permissions

In your app registration:

1. Go to **API permissions**
2. Click **Add a permission** > **Microsoft Graph**
3. Choose **Delegated permissions**
4. Add the following permissions:

   **Required Permissions:**
   - `User.Read` - Sign in and read user profile
   - `DeviceManagementManagedDevices.Read.All` - Read Intune devices
   - `DeviceManagementManagedDevices.ReadWrite.All` - Manage Intune devices
   - `DeviceManagementApps.Read.All` - Read Intune apps
   - `DeviceManagementApps.ReadWrite.All` - Manage Intune apps
   - `Group.Read.All` - Read all groups
   - `GroupMember.Read.All` - Read group memberships

   **Optional Permissions:**
   - `DeviceManagementConfiguration.Read.All` - Read device configurations
   - `DeviceManagementConfiguration.ReadWrite.All` - Manage device configurations
   - `DeviceManagementRBAC.Read.All` - Read RBAC settings

5. Click **Grant admin consent** (requires admin rights)

### 3. Configure Authentication Settings

1. In your app registration, go to **Authentication**
2. Under **Advanced settings**:
   - Enable **Allow public client flows**: Yes (for native apps)
   - **Supported account types**: Verify your selection
3. Under **Mobile and desktop applications**:
   - Ensure your redirect URI is listed
   - Format: `msauth.YOUR-BUNDLE-ID://auth`

### 4. Optional: Create Client Secret (Confidential Client)

For confidential client flow (more secure but requires secret management):

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Add description and expiration
4. **Copy the secret value immediately** (shown only once)
5. Store securely - the app will encrypt it in Keychain

### 5. Build and Configure the App

#### Clone and Build

```bash
# Clone the repository
git clone https://github.com/yourusername/intune-macos-tools.git
cd intune-macos-tools/IntuneManager

# Open in Xcode
open IntuneManager.xcodeproj
```

#### Configure Xcode Project

1. **Bundle Identifier**:
   - Select the project in Xcode
   - Change Bundle Identifier to match your organization
   - Example: `com.yourorg.intunemanager`

2. **Signing & Capabilities**:
   - Select your Development Team
   - Enable **Keychain Sharing**:
     - Add keychain group: `com.microsoft.adalcache`
   - Enable **Hardened Runtime** (macOS)

3. **Info.plist Configuration**:
   The Info.plist is pre-configured, but verify:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>msauth.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
           </array>
       </dict>
   </array>
   ```

4. **Build and Run**:
   - Select target device/simulator
   - Build and run (⌘+R)

### 6. First Run Configuration

When you launch the app for the first time:

1. **Configuration Screen** appears automatically
2. Enter your Azure AD credentials:
   - **Client ID**: From app registration
   - **Tenant ID**: Your directory ID or "common"
   - **Client Secret**: Optional (for confidential client)
   - **Redirect URI**: Auto-populated, modify if needed

3. Click **Save & Continue**
4. **Sign in** with your Microsoft account
5. **Grant permissions** when prompted

The credentials are securely stored in Keychain and will persist across app launches.

## Usage Guide

### Authentication

- **First Sign-In**: Click "Sign in with Microsoft"
- **Token Refresh**: Automatic (5 minutes before expiration)
- **Session Expiry**: Displayed in the UI
- **Sign Out**: Available in menu or settings

### Bulk App Assignment

1. Navigate to **Assignments** tab
2. **Step 1**: Select applications to assign
3. **Step 2**: Select target device groups
4. **Step 3**: Configure assignment settings (Required/Available)
5. **Step 4**: Review and confirm
6. Click **Assign** to execute

Progress is shown in real-time with ability to cancel or retry failed assignments.

### Managing Credentials

- **View Current Configuration**: Settings > Configuration
- **Update Credentials**: Settings > Reconfigure
- **Clear All Data**: Settings > Reset App

## Security Features

### Credential Storage
- Credentials stored in iOS/macOS Keychain
- Encrypted at rest
- Never transmitted except to Microsoft
- Biometric protection available (Face ID/Touch ID)

### Token Management
- Access tokens never persisted
- Automatic refresh before expiration
- Secure token cache in MSAL
- Session timeout handling

### Authentication
- OAuth 2.0 with PKCE
- No passwords stored locally
- Multi-factor authentication support
- Conditional access support

## Troubleshooting

### Common Issues

#### "App not configured"
- Launch the app and enter credentials
- Verify Client ID and Tenant ID are correct
- Check redirect URI matches Azure AD configuration

#### "Authentication failed"
- Verify API permissions are granted
- Check admin consent is provided
- Ensure account has Intune access
- Try signing out and back in

#### "Token expired"
- App should auto-refresh
- If not, sign out and back in
- Check network connectivity

#### "Invalid redirect URI"
- Verify bundle ID matches redirect URI
- Format: `msauth.YOUR-BUNDLE-ID://auth`
- Update in both Azure AD and app configuration

### Debug Mode

Enable verbose logging:
1. Settings > Advanced > Enable Debug Logging
2. Logs are stored in: `~/Library/Logs/IntuneManager/`

### Reset App

If experiencing persistent issues:
1. Settings > Advanced > Reset App
2. This clears all credentials and cache
3. Reconfigure on next launch

## Architecture

```
IntuneManager/
├── App/                    # App lifecycle
├── Core/
│   ├── Authentication/     # MSAL v2 integration
│   ├── Security/          # Credential management
│   ├── Networking/        # Graph API client
│   └── DataLayer/         # Models and persistence
├── Features/
│   ├── Setup/            # First-run configuration
│   ├── BulkAssignment/   # Main feature
│   ├── Devices/
│   ├── Applications/
│   └── Groups/
├── Services/             # Business logic
└── Utilities/           # Helpers and extensions
```

## Development

### Environment Variables

For development, you can set environment variables in Xcode:
- `INTUNE_CLIENT_ID`: Your app's client ID
- `INTUNE_TENANT_ID`: Your tenant ID

### Testing

```bash
# Run unit tests
xcodebuild test -scheme IntuneManager

# Run UI tests
xcodebuild test -scheme IntuneManagerUITests
```

## Security Reporting

Found a security issue? Please email security@yourorg.com

## License

MIT License - See LICENSE file for details

## Support

- Create an issue on GitHub
- Check the [Wiki](https://github.com/yourusername/intune-macos-tools/wiki)
- Contact your IT administrator

## Acknowledgments

- Microsoft Graph API Team
- MSAL iOS Team
- SwiftUI Community

---

**Note**: This app is not affiliated with or endorsed by Microsoft. It's an independent tool built to enhance the Intune management experience.