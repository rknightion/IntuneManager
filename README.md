# IntuneManager - Xcode Project

## Project Setup Complete! ✅

All source files have been successfully migrated from the Package.swift structure to the Xcode project structure.

## Next Steps in Xcode

### 1. Add Package Dependencies
1. Open `IntuneManager.xcodeproj` in Xcode
2. Select the project in the navigator
3. Go to **Package Dependencies** tab
4. Click **+** and add these packages:
   - `https://github.com/AzureAD/microsoft-authentication-library-for-objc.git` (Version: 1.3.0+)
   - `https://github.com/kishikawakatsumi/KeychainAccess.git` (Version: 4.2.2+)

### 2. Configure Build Settings
1. Select each target (iOS and macOS)
2. Go to **Build Settings**
3. Set these important settings:
   - Swift Language Version: **Swift 6**
   - Minimum Deployments: **iOS 18.0**, **macOS 15.0**
   - Enable **Strict Concurrency** checking

### 3. Configure Signing & Capabilities
For **both iOS and macOS targets**:

1. Go to **Signing & Capabilities**
2. Select your team
3. Add these capabilities:
   - ✅ Keychain Sharing
   - ✅ App Groups (create group: `group.$(PRODUCT_BUNDLE_IDENTIFIER)`)

For **macOS only**:
   - ✅ App Sandbox
   - ✅ Outgoing Connections (Client)

### 4. Update Info.plist Location
1. Select each target
2. Go to **Build Settings**
3. Search for "Info.plist"
4. Set path to: `IntuneManager/Info.plist`

### 5. Update Entitlements
1. Select each target
2. Go to **Build Settings**
3. Search for "Entitlements"
4. Set path to: `IntuneManager/IntuneManager.entitlements`

## Project Structure

```
IntuneManager/
├── App/                    # Main app files
│   ├── IntuneManagerApp.swift  # @main entry point
│   ├── UnifiedContentView.swift # Root content view
│   └── SettingsView.swift
├── Core/                   # Core functionality
│   ├── Authentication/     # MSAL auth
│   ├── DataLayer/         # SwiftData models
│   ├── Networking/        # Graph API client
│   ├── Security/          # Credential management
│   └── CrossPlatform/     # Platform compatibility
├── Features/              # Feature modules
│   ├── Dashboard/
│   ├── Devices/
│   ├── Applications/
│   ├── Groups/
│   ├── Assignments/
│   └── Setup/
├── Services/              # Business logic
└── Utilities/             # Helper utilities
```

## Configuration

### MSAL Setup
1. Register your app in Azure AD
2. Get your Client ID and Tenant ID
3. Update `MSALConfiguration.swift` with your values
4. Or use the in-app configuration screen on first launch

### Bundle Identifier
Make sure your bundle identifier matches what's registered in Azure AD for the redirect URI:
- Redirect URI format: `msauth.{your-bundle-id}://auth`

## Building & Running

### iOS
1. Select an iOS Simulator or device
2. Press ⌘R to build and run

### macOS
1. Select "My Mac" as the destination
2. Press ⌘R to build and run

## Troubleshooting

### "No such module 'MSAL'"
- Make sure you've added the package dependencies (see step 1 above)
- Clean build folder: ⌘⇧K
- Reset package caches: File → Packages → Reset Package Caches

### App doesn't launch
- Check that Info.plist path is correctly set
- Verify entitlements file path is set
- Check Console.app for crash logs

### MSAL Authentication fails
- Verify your redirect URI matches: `msauth.{bundle-id}://auth`
- Check keychain sharing is enabled
- Ensure Client ID and Tenant ID are correct

## Testing

### Unit Tests
Located in `IntuneManagerTests/`

### UI Tests
Located in `IntuneManagerUITests/`

Run tests with ⌘U

## Distribution

### TestFlight (iOS)
1. Archive the app (Product → Archive)
2. Upload to App Store Connect
3. Submit for TestFlight review

### Mac App Store
1. Archive the app (Product → Archive)
2. Upload to App Store Connect
3. Submit for review

### Direct Distribution (macOS)
1. Archive the app
2. Export with Developer ID
3. Notarize with Apple
4. Distribute .dmg or .pkg

## Important Files

- `Info.plist` - App configuration and permissions
- `IntuneManager.entitlements` - App capabilities and sandbox settings
- `MSALConfiguration.swift` - MSAL/Azure AD configuration
- `IntuneManagerApp.swift` - Main app entry point

## Notes

- All files have been moved from `/Users/rob/repos/IntuneManager`
- The original Package.swift structure is no longer needed
- This is now a standard Xcode project ready for App Store distribution
- SwiftData models are included and configured
- MSAL authentication is ready to use

## Support

For issues, check:
1. Xcode's Issue navigator (⌘5)
2. Console.app for runtime logs
3. The Logger output in Xcode's console

Good luck with your app! 🚀