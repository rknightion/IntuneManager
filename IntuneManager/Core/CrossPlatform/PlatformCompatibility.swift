import SwiftUI
import AppKit

// MARK: - Platform Types

typealias PlatformViewController = NSViewController
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
typealias PlatformApplication = NSApplication

// MARK: - View Modifiers

struct PlatformNavigationStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

struct PlatformListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(SidebarListStyle())
    }
}

struct PlatformFormStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .formStyle(.grouped)
            .frame(minWidth: 400)
    }
}

private struct PlatformGlassBackground: ViewModifier {
    let cornerRadius: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let cornerRadius {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
                .background(.ultraThinMaterial)
        }
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

// MARK: - Navigation Helpers

struct PlatformNavigation<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
        }
    }
}

struct PlatformTabView<Content: View>: View {
    @Binding var selection: AppState.Tab
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationSplitView {
            UnifiedSidebarView(selection: $selection)
        } detail: {
            NavigationStack {
                content()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Platform Helpers

struct PlatformHelper {
    static func getRootViewController() async -> NSViewController? {
        await MainActor.run {
            NSApp.keyWindow?.contentViewController
        }
    }

    static func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func setIdleTimerDisabled(_ disabled: Bool) {
        // No idle timer concept on macOS
    }

    @MainActor
    static func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }
}

// MARK: - Buttons

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
                .frame(minWidth: 120)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(tintColor)
    }

    private var tintColor: Color {
        switch style {
        case .primary:
            return .accentColor
        case .secondary:
            return .gray
        case .destructive:
            return .red
        }
    }
}

// MARK: - Alerts

struct PlatformAlert {
    struct AlertButton {
        let title: String
        let action: () -> Void
    }

    @MainActor
    static func show(title: String, message: String, buttons: [AlertButton]) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0.title) }
        let response = alert.runModal()
        if response != .alertFirstButtonReturn {
            let index = Int(response.rawValue) - Int(NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
            if buttons.indices.contains(index) {
                buttons[index].action()
            }
        } else {
            buttons.first?.action()
        }
    }
}

// MARK: - File Management

struct PlatformFileManager {
    @MainActor
    static func selectFile(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.begin { response in
            completion(response == .OK ? openPanel.url : nil)
        }
    }

    @MainActor
    static func saveFile(data: Data, suggestedFilename: String, completion: @escaping (URL?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else {
                completion(nil)
                return
            }
            do {
                try data.write(to: url)
                completion(url)
            } catch {
                completion(nil)
            }
        }
    }
}

// MARK: - Pasteboard

struct PlatformPasteboard {
    static func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    static func getFromClipboard() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}

// MARK: - Haptics

struct PlatformHaptics {
    enum FeedbackType {
        case success
        case warning
        case error
        case selection
    }

    static func trigger(_ type: FeedbackType) {
        // No haptic feedback on macOS
    }
}

// MARK: - Windows

struct PlatformWindow {
    @MainActor
    static func setWindowSize(width: CGFloat, height: CGFloat) {
        NSApp.keyWindow?.setContentSize(NSSize(width: width, height: height))
    }

    @MainActor
    static func centerWindow() {
        NSApp.keyWindow?.center()
    }

    @MainActor
    static func setWindowTitle(_ title: String) {
        NSApp.keyWindow?.title = title
    }
}

// MARK: - Conditional View

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
        self
    }

    func macOS<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
    }

    func iPadOS<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        self
    }
}
