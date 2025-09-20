# Xcode Project Setup for App Store Distribution

## Why You Need an Xcode Project
- **Code Signing**: Required for App Store
- **Provisioning Profiles**: Manage device testing and distribution
- **App Store Connect**: Upload and metadata management
- **Platform-specific settings**: Different configs for iOS/macOS
- **Entitlements**: Proper sandboxing and capabilities

## Project Structure

```
IntuneManagerXcode/
├── IntuneManager.xcodeproj
├── IntuneManager (iOS)/
│   ├── Info.plist
│   ├── IntuneManager.entitlements
│   └── Assets.xcassets
├── IntuneManager (macOS)/
│   ├── Info.plist
│   ├── IntuneManager.entitlements
│   └── Assets.xcassets
├── IntuneManagerTests/
└── IntuneManagerUITests/
```

## Step-by-Step Setup

### 1. Create Xcode Project
- Open Xcode → File → New → Project
- Choose **Multiplatform → App**
- Product Name: `IntuneManager`
- Interface: SwiftUI
- Language: Swift
- Use Core Data: Yes (we'll replace it)

### 2. Add Your Package
1. File → Add Package Dependencies
2. Add Local Package → Select your `/Users/rob/repos/IntuneManager` folder
3. Add to both iOS and macOS targets

### 3. Configure Info.plist for iOS

Add to iOS Info.plist:
```xml
<!-- MSAL Configuration -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </array>
    </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>msauthv2</string>
    <string>msauthv3</string>
</array>
```

### 4. Configure Info.plist for macOS

Add to macOS Info.plist:
```xml
<key>LSMinimumSystemVersion</key>
<string>15.0</string>
```

### 5. Create Bridge File

Create `AppDelegate.swift` in iOS target:
```swift
import UIKit
import IntuneManager

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication,
                    configurationForConnecting connectingSceneSession: UISceneSession,
                    options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: IntuneManagerApp().view)
        self.window = window
        window.makeKeyAndVisible()
    }
}
```

### 6. Entitlements Configuration

iOS Entitlements (`IntuneManager.entitlements`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    </array>
</dict>
</plist>
```

macOS Entitlements:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
    </array>
</dict>
</plist>
```

### 7. Build Settings

For both targets:
1. Build Settings → Swift Compiler - Language
   - Swift Language Version: Swift 6
2. Build Settings → Deployment
   - iOS Deployment Target: 18.0
   - macOS Deployment Target: 15.0

### 8. Schemes Configuration

1. Product → Scheme → Edit Scheme
2. For Run configuration:
   - Build Configuration: Debug
   - Debug executable: ✅
3. For Archive configuration:
   - Build Configuration: Release

## Testing Your Setup

1. Select iOS Simulator → iPhone 16 Pro
2. Build and Run (⌘R)
3. Should launch successfully

4. Select macOS target
5. Build and Run (⌘R)
6. Should launch as native Mac app

## App Store Preparation

### Required Assets
- App Icons (1024x1024 for both platforms)
- Screenshots (various sizes)
- App Store description
- Privacy policy URL

### Before Submission
1. Test on real devices
2. Run Instruments for memory leaks
3. Test MSAL authentication flow
4. Verify all entitlements work
5. Archive and validate

## Common Issues

### Issue: "No such module 'IntuneManager'"
**Solution**: Make sure package is added to both targets

### Issue: MSAL redirect not working
**Solution**: Verify URL schemes in Info.plist match your bundle ID

### Issue: Keychain access denied
**Solution**: Check keychain entitlements are properly configured

## Next Steps

1. Configure App Store Connect
2. Set up TestFlight
3. Create provisioning profiles
4. Submit for review

## Important Notes

- Keep your Package.swift for development
- Use Xcode project for distribution
- Both can coexist in separate folders
- Update both when adding dependencies