import SwiftUI

@main
struct IntuneManagerApp: App {
    @StateObject private var authManager = AuthManagerV2.shared
    @StateObject private var credentialManager = CredentialManager.shared
    @StateObject private var appState = AppState()

    @State private var showingConfiguration = false
    @State private var showingSplash = true
    @State private var initializationError: Error?

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showingSplash {
                    SplashView()
                        .transition(.opacity)
                } else if !credentialManager.isConfigured || showingConfiguration {
                    ConfigurationView()
                        .transition(.move(edge: .bottom))
                } else {
                    UnifiedContentView()
                        .environmentObject(authManager)
                        .environmentObject(appState)
                        .environmentObject(credentialManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showingSplash)
            .task {
                await initializeApp()
            }
            .onAppear {
                configurePlatformSpecifics()
            }
            .alert("Initialization Error", isPresented: .constant(initializationError != nil)) {
                Button("Retry") {
                    Task {
                        await initializeApp()
                    }
                }
                Button("Configure") {
                    showingConfiguration = true
                    initializationError = nil
                }
            } message: {
                if let error = initializationError {
                    Text(error.localizedDescription)
                }
            }
            .preferredColorScheme(appState.preferredColorScheme)
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            // App Menu
            CommandGroup(replacing: .appInfo) {
                Button("About IntuneManager") {
                    appState.showingAbout = true
                }
            }

            // File Menu
            CommandGroup(replacing: .newItem) { }

            // Edit Menu additions
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copy Device Info") {
                    // Implement device info copy
                }
                .keyboardShortcut("C", modifiers: [.command, .shift])
                .disabled(!authManager.isAuthenticated)
            }

            // View Menu
            CommandMenu("View") {
                Button("Refresh") {
                    Task {
                        await appState.syncAll()
                    }
                }
                .keyboardShortcut("R", modifiers: .command)

                Divider()

                Picker("Appearance", selection: $appState.preferredColorScheme) {
                    Text("System").tag(ColorScheme?.none)
                    Text("Light").tag(ColorScheme.light as ColorScheme?)
                    Text("Dark").tag(ColorScheme.dark as ColorScheme?)
                }
            }

            // Authentication Menu
            CommandMenu("Account") {
                if authManager.isAuthenticated {
                    if let user = authManager.currentUser {
                        Text(user.displayName)
                            .font(.headline)
                        Text(user.email)
                            .font(.caption)
                        Divider()
                    }

                    Button("Sign Out") {
                        Task {
                            await authManager.signOut()
                        }
                    }
                    .keyboardShortcut("Q", modifiers: [.command, .shift])
                } else {
                    Button("Sign In") {
                        Task {
                            try? await authManager.signIn()
                        }
                    }
                    .keyboardShortcut("L", modifiers: .command)
                }

                Divider()

                Button("Reconfigure") {
                    showingConfiguration = true
                }
                .keyboardShortcut(",", modifiers: [.command, .option])
            }

            // Tools Menu
            CommandMenu("Tools") {
                Button("Bulk Assignment") {
                    appState.selectedTab = .assignments
                }
                .keyboardShortcut("A", modifiers: [.command, .shift])

                Divider()

                Button("Clear Cache") {
                    CacheManager.shared.clearCache()
                }

                Button("Export Logs") {
                    exportLogs()
                }
            }
        }
        #endif

        #if os(macOS)
        Settings {
            UnifiedSettingsView()
                .environmentObject(authManager)
                .environmentObject(appState)
                .environmentObject(credentialManager)
        }
        #endif
    }

    // MARK: - Initialization

    private func initializeApp() async {
        // Initialize logging
        Logger.shared.configure()

        // Setup cache manager
        CacheManager.shared.configure()

        // Short delay for splash screen
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Check if app is configured
        if credentialManager.isConfigured {
            do {
                // Initialize MSAL with stored credentials
                try await authManager.initializeMSAL()

                // Try to authenticate silently
                if await authManager.validateToken() {
                    // Load initial data if authenticated
                    await appState.loadInitialData()
                }
            } catch {
                // Store error for display
                await MainActor.run {
                    initializationError = error
                    Logger.shared.error("App initialization failed: \(error)")
                }
            }
        }

        // Hide splash screen
        await MainActor.run {
            withAnimation {
                showingSplash = false
            }
        }
    }

    private func configurePlatformSpecifics() {
        #if os(iOS)
        // iOS specific configuration
        UIApplication.shared.isIdleTimerDisabled = false

        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Configure tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        #elseif os(macOS)
        // macOS specific configuration
        NSApplication.shared.applicationIconImage = NSImage(systemSymbolName: "laptopcomputer.and.iphone", accessibilityDescription: "IntuneManager")

        // Set activation policy
        NSApplication.shared.setActivationPolicy(.regular)
        #endif
    }

    #if os(macOS)
    private func exportLogs() {
        let logs = Logger.shared.getCriticalErrors()
        let logContent = logs.joined(separator: "\n")
        let data = logContent.data(using: .utf8) ?? Data()

        PlatformFileManager.saveFile(data: data, suggestedFilename: "IntuneManager-Logs.txt") { url in
            if url != nil {
                PlatformHaptics.trigger(.success)
            }
        }
    }
    #endif
}

// MARK: - Splash View

struct SplashView: View {
    @State private var isAnimating = false
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.1),
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Animated logo
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse)
                }

                VStack(spacing: 8) {
                    Text("IntuneManager")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Initializing...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Loading indicator
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                    .tint(.accentColor)
            }
        }
        .onAppear {
            isAnimating = true
            withAnimation(.linear(duration: 1.0)) {
                progress = 1.0
            }
        }
    }
}

// MARK: - Unified Settings View

struct UnifiedSettingsView: View {
    @EnvironmentObject var authManager: AuthManagerV2
    @EnvironmentObject var credentialManager: CredentialManager
    @AppStorage("refreshInterval") private var refreshInterval = 60
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("batchSize") private var batchSize = 20

    var body: some View {
        #if os(iOS)
        NavigationView {
            settingsForm
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
        }
        #else
        settingsForm
            .frame(width: 500, height: 600)
        #endif
    }

    private var settingsForm: some View {
        Form {
            accountSection
            syncSection
            notificationSection
            cacheSection
            aboutSection
        }
        .platformFormStyle()
    }

    private var accountSection: some View {
        Section("Account") {
            if let user = authManager.currentUser {
                VStack(alignment: .leading, spacing: 8) {
                    Text(user.displayName)
                        .font(.headline)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let tenant = user.tenantId {
                        Text("Tenant: \(tenant)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Button("Sign Out") {
                Task {
                    await authManager.signOut()
                }
            }
            .foregroundColor(.red)
        }
    }

    private var syncSection: some View {
        Section("Sync Settings") {
            Picker("Auto Refresh", selection: $refreshInterval) {
                Text("Off").tag(0)
                Text("30 Minutes").tag(30)
                Text("1 Hour").tag(60)
                Text("2 Hours").tag(120)
                Text("4 Hours").tag(240)
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Batch Size")
                    Spacer()
                    Text("\(batchSize) items")
                        .foregroundColor(.secondary)
                }
                Slider(value: .init(
                    get: { Double(batchSize) },
                    set: { batchSize = Int($0) }
                ), in: 5...50, step: 5)
            }
        }
    }

    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Enable Notifications", isOn: $enableNotifications)

            #if os(iOS)
            Button("Configure Notification Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    PlatformHelper.openURL(url)
                }
            }
            #endif
        }
    }

    private var cacheSection: some View {
        Section("Cache") {
            HStack {
                Text("Cache Size")
                Spacer()
                Text(formatBytes(CacheManager.shared.getCacheSize()))
                    .foregroundColor(.secondary)
            }

            Button("Clear Cache") {
                CacheManager.shared.clearCache()
                PlatformHaptics.trigger(.success)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("2.0.0")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text("\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")")
                    .foregroundColor(.secondary)
            }

            Link("Documentation", destination: URL(string: "https://github.com/yourusername/intune-macos-tools")!)
            Link("Report Issue", destination: URL(string: "https://github.com/yourusername/intune-macos-tools/issues")!)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}