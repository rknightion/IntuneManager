import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Centralized theme configuration for consistent UI across the app
struct Theme {

    // MARK: - Colors
    struct Colors {
        /// Primary brand color - Microsoft-inspired blue
        static let primary = Color.accentColor

        /// Success state - green
        static let success = Color.green

        /// Warning state - orange
        static let warning = Color.orange

        /// Error/danger state - red
        static let error = Color.red

        /// Background colors
        #if os(iOS)
        static let primaryBackground = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
        static let tertiaryText = Color(UIColor.tertiaryLabel)
        static let cardBackground = Color(UIColor.systemBackground).opacity(0.95)
        #else
        static let primaryBackground = Color(NSColor.windowBackgroundColor)
        static let secondaryBackground = Color(NSColor.controlBackgroundColor)
        static let tertiaryBackground = Color(NSColor.controlBackgroundColor)
        static let tertiaryText = Color(NSColor.tertiaryLabelColor)
        static let cardBackground = Color(NSColor.windowBackgroundColor).opacity(0.95)
        #endif

        /// Text colors
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
    }

    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle
        static let title = Font.title
        static let title2 = Font.title2
        static let title3 = Font.title3
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2

        /// Monospaced font for IDs and technical data
        static let monospaced = Font.system(.body, design: .monospaced)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let xxLarge: CGFloat = 48
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xLarge: CGFloat = 16
    }

    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
    }
}

// MARK: - View Modifiers

/// Card style modifier for consistent card appearance
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

/// Loading overlay modifier
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)

            if isLoading {
                VStack(spacing: Theme.Spacing.medium) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)

                    if let message = message {
                        Text(message)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                .padding(Theme.Spacing.large)
                .background(Theme.Colors.primaryBackground)
                .cornerRadius(Theme.CornerRadius.large)
                .shadow(radius: 10)
            }
        }
        .animation(Theme.Animation.quick, value: isLoading)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}