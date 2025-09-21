// swift-tools-version: 5.10
// This file is for dependency management reference only
// Add these dependencies through Xcode's Package Dependencies interface

import PackageDescription

let package = Package(
    name: "IntuneManager-Dependencies",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    dependencies: [
        // Microsoft Authentication Library (handles token storage securely)
        .package(url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc.git", from: "2.4.0"),
    ]
)

// HOW TO ADD DEPENDENCIES IN XCODE:
// 1. Select your project in the navigator
// 2. Select the project (not a target) in the editor
// 3. Click "Package Dependencies" tab
// 4. Click the + button
// 5. Enter the package URL above
// 6. Click "Add Package"
// 7. Select which targets should use the package