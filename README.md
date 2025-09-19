# IntuneManager

A powerful, native macOS/iOS/iPadOS application for efficiently managing Microsoft Intune devices, with a focus on streamlining app-to-device-group assignments.

## Overview

IntuneManager solves the pain points of managing hundreds of applications in Microsoft Intune through the web interface. Built with SwiftUI and leveraging the Microsoft Graph API, it provides a fast, native experience across all Apple platforms.

### Key Features

- **Bulk App Assignment**: Assign multiple applications to multiple device groups in seconds
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
2. Navigate to Azure Active Directory > App registrations
3. Click "New registration"
4. Configure the application:
   - Name: `IntuneManager`
   - Supported account types: Single tenant (or as per your needs)
   - Redirect URI:
     - Platform: Mobile and desktop applications
     - URI: `msauth.com.yourorganization.intunemanager://auth`
5. Note the Application (client) ID and Directory (tenant) ID

### 2. Configure API Permissions

In your app registration, add the following Microsoft Graph API permissions:

- `DeviceManagementManagedDevices.Read.All`
- `DeviceManagementManagedDevices.ReadWrite.All`
- `DeviceManagementApps.Read.All`
- `DeviceManagementApps.ReadWrite.All`
- `DeviceManagementConfiguration.Read.All`
- `DeviceManagementConfiguration.ReadWrite.All`
- `DeviceManagementRBAC.Read.All`
- `Group.Read.All`
- `GroupMember.Read.All`
- `User.Read`

Grant admin consent for your organization if required.

### 3. Project Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/intune-macos-tools.git
cd intune-macos-tools/IntuneManager
```

2. Open the project in Xcode:
```bash
open IntuneManager.xcodeproj
```

3. Configure environment variables:
   - Create a `.env` file in the project root:
   ```
   INTUNE_CLIENT_ID=your_client_id_here
   INTUNE_TENANT_ID=your_tenant_id_here
   ```

4. Update the Bundle Identifier:
   - In Xcode, select the project
   - Update Bundle Identifier to match your organization
   - Update the redirect URI in `MSALConfiguration.swift` if needed

### 4. Install Dependencies

The project uses Swift Package Manager. Dependencies will be automatically resolved when you open the project in Xcode.

Required packages:
- MSAL (Microsoft Authentication Library)
- KeychainAccess

### 5. Build and Run

1. Select your target device/simulator
2. Build and run (⌘+R)
3. Sign in with your Microsoft account
4. Grant necessary permissions

## Usage

### Initial Setup

1. **Launch the app** and sign in with your Microsoft Intune administrator account
2. **Grant permissions** when prompted
3. The app will automatically sync your devices, applications, and groups

### Bulk App Assignment (Main Feature)

1. Navigate to the **Assignments** tab
2. **Select Applications**: Choose multiple apps you want to assign
3. **Select Groups**: Choose the device groups for assignment
4. **Configure Settings**: Set the assignment intent (Required/Available/Uninstall)
5. **Review**: Verify your selections
6. **Execute**: Click "Assign" to process all assignments in batch

The app will handle all assignments efficiently, showing progress and any errors in real-time.

### Device Management

- View all enrolled macOS, iOS, and iPadOS devices
- Filter by compliance state, ownership, or OS version
- Search devices by name, user, or serial number
- Perform device actions (sync, restart, retire, wipe)

### Application Management

- Browse all managed applications
- Filter by app type or publishing state
- View installation statistics
- Manage individual app assignments

### Group Management

- View all Azure AD groups
- See member counts and types
- Filter dynamic vs. static groups
- Preview group membership

## Architecture

The app follows MVVM-C architecture with a modular structure:

```
IntuneManager/
├── App/                    # App lifecycle
├── Core/                   # Core functionality
│   ├── Authentication/     # MSAL integration
│   ├── Networking/         # Graph API client
│   └── DataLayer/          # Models and persistence
├── Features/               # Feature modules
│   ├── BulkAssignment/     # Main assignment feature
│   ├── Devices/
│   ├── Applications/
│   └── Groups/
├── Services/               # Business logic
└── Utilities/              # Helpers and extensions
```

## Performance Optimizations

- **Intelligent Caching**: 1-hour cache for device/app/group data
- **Batch Processing**: Groups API calls in batches of 20
- **Lazy Loading**: Loads data on-demand with pagination
- **Background Sync**: Refreshes data in background
- **Optimistic UI**: Updates UI immediately while processing

## Security

- **OAuth 2.0/OIDC**: Secure authentication via MSAL
- **Token Management**: Automatic token refresh
- **Keychain Storage**: Secure credential storage
- **Certificate Pinning**: For enhanced security (optional)
- **Audit Logging**: All actions are logged

## Troubleshooting

### Authentication Issues

1. Verify your Azure AD app registration
2. Check redirect URI matches your bundle ID
3. Ensure admin consent is granted
4. Clear app cache and re-authenticate

### API Errors

- **401 Unauthorized**: Token expired - sign out and back in
- **403 Forbidden**: Missing permissions - check API permissions
- **429 Too Many Requests**: Rate limited - app handles automatically

### Performance Issues

1. Clear cache via Settings
2. Check network connectivity
3. Reduce batch size in settings
4. Enable background refresh

## Future Enhancements

- **Policy Management**: Configure and deploy device policies
- **Compliance Reporting**: Advanced compliance dashboards
- **Automation Rules**: Conditional assignments based on device properties
- **Export/Import**: Bulk configuration management
- **Analytics Dashboard**: Usage trends and insights
- **Notifications**: Push notifications for critical events

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to your fork
5. Submit a pull request

## Support

For issues, questions, or feature requests:
- Create an issue on GitHub
- Contact your IT administrator
- Check the [Wiki](https://github.com/yourusername/intune-macos-tools/wiki)

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Acknowledgments

- Microsoft Graph API Team
- MSAL iOS Team
- SwiftUI Community

---

**Note**: This app is not affiliated with or endorsed by Microsoft. It's an independent tool built to enhance the Intune management experience.