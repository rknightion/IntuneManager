# IntuneManager Xcode Setup Checklist

## ✅ Migration Complete!
All files have been successfully moved from `/Users/rob/repos/IntuneManager` to this Xcode project.

## Essential Setup Steps

### 🔴 CRITICAL - Do These First in Xcode:

1. **[ ] Open the project**
   ```
   open /Users/rob/Documents/IntuneManager/IntuneManager.xcodeproj
   ```

2. **[ ] Add Swift Package Dependencies**
   - File → Add Package Dependencies
   - Add: `https://github.com/AzureAD/microsoft-authentication-library-for-objc.git`
   - Add: `https://github.com/kishikawakatsumi/KeychainAccess.git`
   - Select both iOS and macOS targets when prompted

3. **[ ] Fix File References** (if any files show red)
   - Select red files in navigator
   - Delete reference (not file)
   - Drag files back from Finder
   - Make sure "Copy items if needed" is UNCHECKED
   - Add to both targets

4. **[ ] Configure Both Targets**

   For EACH target (iOS and macOS):

   **General Tab:**
   - [ ] Minimum Deployments: iOS 18.0 / macOS 15.0
   - [ ] Bundle Identifier: Your reverse domain (e.g., com.yourcompany.intunemanager)

   **Signing & Capabilities:**
   - [ ] Team: Select your Apple Developer team
   - [ ] Add Capability: Keychain Sharing
   - [ ] Add Capability: App Groups (use: group.$(PRODUCT_BUNDLE_IDENTIFIER))

   **Build Settings:**
   - [ ] Info.plist File: `IntuneManager/Info.plist`
   - [ ] Code Signing Entitlements: `IntuneManager/IntuneManager.entitlements`
   - [ ] Swift Language Version: Swift 6

5. **[ ] Test Build**
   - Select iOS Simulator
   - Press ⌘B to build
   - Should build without errors

6. **[ ] Test Run**
   - Press ⌘R
   - App should launch to configuration screen
   - Enter your Azure AD details or use environment variables

## File Organization

```
IntuneManager/
├── App/                    ✅ Copied
├── Core/                   ✅ Copied
├── Features/               ✅ Copied
├── Services/               ✅ Copied
├── Utilities/              ✅ Copied
├── Info.plist              ✅ Created
└── IntuneManager.entitlements ✅ Created
```

## Azure AD Configuration

You'll need:
- Client ID from Azure AD app registration
- Tenant ID (or use "common" for multi-tenant)
- Redirect URI: `msauth.{your-bundle-id}://auth`

## Quick Fixes

### If you see "No such module 'MSAL'":
1. File → Packages → Reset Package Caches
2. Clean Build Folder (⌘⇧K)
3. Build again (⌘B)

### If app won't launch:
1. Check Console.app for crash logs
2. Verify Info.plist path in Build Settings
3. Check entitlements are configured

### If files are missing/red:
1. Remove reference (don't delete)
2. Re-add from IntuneManager folder
3. Ensure added to both targets

## Ready to Ship?

Once everything builds and runs:
1. Create app icons (1024x1024)
2. Take screenshots for App Store
3. Archive → Distribute App
4. Upload to App Store Connect

---

**Note**: Your original Package.swift project in `/Users/rob/repos/IntuneManager` can be deleted or kept for reference. This Xcode project is now self-contained with all the code.