import SwiftUI

// MARK: - Platform-Specific Type Aliases and Extensions

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
typealias PlatformApplication = UIApplication
#elseif os(macOS)
import AppKit
typealias PlatformViewController = NSViewController
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
typealias PlatformApplication = NSApplication
#endif

// MARK: - Cross-Platform View Modifiers

struct PlatformNavigationStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .navigationBarTitleDisplayMode(.large)
        #else
        content
        #endif
    }
}

struct PlatformListStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .listStyle(InsetGroupedListStyle())
        #else
        content
            .listStyle(SidebarListStyle())
        #endif
    }
}

struct PlatformFormStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .formStyle(.grouped)
        #else
        content
            .formStyle(.grouped)
            .frame(minWidth: 400)
        #endif
    }
}

private struct PlatformGlassBackground: ViewModifier {
    let cornerRadius: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS) || os(macOS)
        if #available(iOS 18, macOS 15, *) {
            if let cornerRadius {
                content
                    .glassBackgroundEffect(in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .glassBackgroundEffect()
            }
        } else {
            if let cornerRadius {
                content
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                content
                    .background(.ultraThinMaterial)
            }
        }
        #else
        content
        #endif
    }
}

extension View {
    func platformNavigationStyle() -> some View {
        modifier(PlatformNavigationStyle())
    }

    func platformListStyle() -> some View {
        modifier(PlatformListStyle())
    }

    func platformFormStyle() -> some View {
        modifier(PlatformFormStyle())
    }

    /// Applies Apple's liquid glass styling when available, while gracefully degrading on older OS releases.
    func platformGlassBackground(cornerRadius: CGFloat? = nil) -> some View {
        modifier(PlatformGlassBackground(cornerRadius: cornerRadius))
    }
}

// MARK: - Platform-Specific Navigation

struct PlatformNavigation<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
        }
        #else
        NavigationStack {
            content()
                .navigationTitle(title)
        }
        #endif
    }
}

// MARK: - Platform-Specific Tab View

struct PlatformTabView<Content: View>: View {
    @Binding var selection: AppState.Tab
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if os(iOS)
        TabView(selection: $selection) {
            content()
        }
        #else
        NavigationSplitView {
            UnifiedSidebarView(selection: $selection)
        } detail: {
            NavigationStack {
                content()
            }
        }
        .navigationSplitViewStyle(.balanced)
        #endif
    }
}

// MARK: - Platform-Specific Helpers

struct PlatformHelper {
    #if os(iOS)
    static func getRootViewController() async -> UIViewController? {
        await MainActor.run {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return nil
            }
            return rootViewController
        }
    }

    static func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }

    static func setIdleTimerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
    #elseif os(macOS)
    static func getRootViewController() async -> NSViewController? {
        await MainActor.run {
            NSApp.keyWindow?.contentViewController
        }
    }

    static func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func setIdleTimerDisabled(_ disabled: Bool) {
        // Not applicable on macOS
    }

    static func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    #endif
}

// MARK: - Platform-Specific Buttons

struct PlatformButton: View {
    let title: String
    let action: () -> Void
    var style: ButtonStyle = .primary

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                #if os(iOS)
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .cornerRadius(10)
                #else
                .padding(.horizontal)
                #endif
        }
        #if os(macOS)
        .buttonStyle(macButtonStyle)
        #else
        .buttonStyle(.plain)
        #endif
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Color.accentColor
        case .secondary:
            return Color.gray.opacity(0.2)
        case .destructive:
            return Color.red
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return .primary
        }
    }

    #if os(macOS)
    private var macButtonStyle: some PrimitiveButtonStyle {
        switch style {
        case .primary:
            return .borderedProminent
        case .secondary:
            return .bordered
        case .destructive:
            return .bordered
        }
    }
    #endif
}

// MARK: - Platform-Specific Alerts

struct PlatformAlert {
    static func show(title: String, message: String, buttons: [AlertButton]) {
        #if os(iOS)
        // iOS alert handling
        #elseif os(macOS)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        for button in buttons {
            alert.addButton(withTitle: button.title)
        }
        alert.runModal()
        #endif
    }

    struct AlertButton {
        let title: String
        let action: () -> Void
    }
}

// MARK: - Platform-Specific File Handling

struct PlatformFileManager {
    static func selectFile(completion: @escaping (URL?) -> Void) {
        #if os(iOS)
        // iOS document picker
        #elseif os(macOS)
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.begin { response in
            if response == .OK {
                completion(openPanel.url)
            } else {
                completion(nil)
            }
        }
        #endif
    }

    static func saveFile(data: Data, suggestedFilename: String, completion: @escaping (URL?) -> Void) {
        #if os(iOS)
        // iOS document exporter
        #elseif os(macOS)
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                    completion(url)
                } catch {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
        #endif
    }
}

// MARK: - Platform-Specific Pasteboard

struct PlatformPasteboard {
    static func copyToClipboard(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    static func getFromClipboard() -> String? {
        #if os(iOS)
        return UIPasteboard.general.string
        #elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #endif
    }
}

// MARK: - Platform-Specific Haptics

struct PlatformHaptics {
    enum FeedbackType {
        case success
        case warning
        case error
        case selection
    }

    static func trigger(_ type: FeedbackType) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success:
            generator.notificationOccurred(.success)
        case .warning:
            generator.notificationOccurred(.warning)
        case .error:
            generator.notificationOccurred(.error)
        case .selection:
            let selectionGenerator = UISelectionFeedbackGenerator()
            selectionGenerator.selectionChanged()
        }
        #endif
        // No haptics on macOS
    }
}

// MARK: - Platform-Specific Window Management

struct PlatformWindow {
    #if os(macOS)
    static func setWindowSize(width: CGFloat, height: CGFloat) {
        if let window = NSApp.keyWindow {
            window.setContentSize(NSSize(width: width, height: height))
        }
    }

    static func centerWindow() {
        NSApp.keyWindow?.center()
    }

    static func setWindowTitle(_ title: String) {
        NSApp.keyWindow?.title = title
    }
    #endif
}

// MARK: - Platform Conditional View

struct PlatformConditional<TrueContent: View, FalseContent: View>: View {
    let condition: Bool
    let trueContent: () -> TrueContent
    let falseContent: () -> FalseContent

    var body: some View {
        if condition {
            trueContent()
        } else {
            falseContent()
        }
    }
}

extension View {
    func iOS<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(iOS)
        content()
        #else
        self
        #endif
    }

    func macOS<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(macOS)
        content()
        #else
        self
        #endif
    }

    @ViewBuilder
    func iPadOS<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            content()
        } else {
            self
        }
        #else
        self
        #endif
    }
}
