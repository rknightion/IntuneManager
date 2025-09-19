// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "IntuneManager",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "IntuneManager",
            targets: ["IntuneManager"]),
    ],
    dependencies: [
        // Microsoft Authentication Library
        .package(url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc.git", from: "1.3.0"),
        // SwiftLint for code quality
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.54.0"),
        // KeychainAccess for secure storage
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "IntuneManager",
            dependencies: [
                .product(name: "MSAL", package: "microsoft-authentication-library-for-objc"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]),
        .testTarget(
            name: "IntuneManagerTests",
            dependencies: ["IntuneManager"]),
    ]
)