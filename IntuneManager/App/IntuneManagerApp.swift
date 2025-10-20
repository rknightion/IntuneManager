import SwiftUI
import SwiftData
import AppKit

@main
struct IntuneManagerApp: App {
    @StateObject private var authManager = AuthManagerV2.shared
    @StateObject private var credentialManager = CredentialManager.shared
    @StateObject private var appState = AppState()
    @StateObject private var permissionService = PermissionCheckService.shared

    @State private var showingConfiguration = false
    @State private var showingSplash = true
    @State private var initializationError: Error?
    @State private var showingPermissionWarning = false

    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: Device.self,
                     Application.self,
                     DeviceGroup.self,
                     Assignment.self,
                     CacheMetadata.self
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootScene(
                showingConfiguration: $showingConfiguration,
                showingSplash: $showingSplash,
                initializationError: $initializationError,
                showingPermissionWarning: $showingPermissionWarning,
                initializeApp: initializeApp,
                configurePlatformSpecifics: configurePlatformSpecifics
            )
            .environmentObject(authManager)
            .environmentObject(appState)
            .environmentObject(credentialManager)
            .environmentObject(permissionService)
        }
        .modelContainer(modelContainer)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About IntuneManager") {
                    appState.showingAbout = true
                }
            }

            CommandGroup(replacing: .newItem) { }

            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copy Device Info") {
                    // TODO: Implement device info copy action
                }
                .keyboardShortcut("C", modifiers: [.command, .shift])
                .disabled(!authManager.isAuthenticated)
            }

            CommandMenu("View") {
                Button("Refresh") {
                    Task {
                        await appState.refreshAll()
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

            CommandMenu("Tools") {
                Button("Bulk Assignment") {
                    appState.selectedTab = .applications
                }
                .keyboardShortcut("A", modifiers: [.command, .shift])

                Divider()

                Button("Clear Local Data") {
                    LocalDataStore.shared.reset()
                    DeviceService.shared.hydrateFromStore()
                    ApplicationService.shared.hydrateFromStore()
                    GroupService.shared.hydrateFromStore()
                    AssignmentService.shared.assignmentHistory = []
                }

                Button("Export Logs") {
                    exportLogs()
                }
            }
        }
        Settings {
            SettingsView()
                .environmentObject(authManager)
                .environmentObject(credentialManager)
                .environmentObject(appState)
        }
        .modelContainer(modelContainer)
        WindowGroup("Assignments Overview") {
            AssignmentQuickLookView()
                .environmentObject(authManager)
                .environmentObject(appState)
                .environmentObject(credentialManager)
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Initialization

    private func initializeApp() async {
        Logger.shared.configure()

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        if credentialManager.isConfigured {
            do {
                try await authManager.initializeMSAL()

                if await authManager.validateToken() {
                    // Check Graph API permissions
                    await permissionService.checkPermissions()

                    // Show warning if permissions are missing, but continue loading
                    if !permissionService.missingPermissions.isEmpty {
                        await MainActor.run {
                            showingPermissionWarning = true
                        }
                    }

                    await appState.loadInitialData()
                }
            } catch {
                await MainActor.run {
                    initializationError = error
                    Logger.shared.error("App initialization failed: \(error)")
                }
            }
        }

        await MainActor.run {
            withAnimation {
                showingSplash = false
            }
        }
    }

    private func configurePlatformSpecifics() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    private func exportLogs() {
        let logs = Logger.shared.getCriticalErrors()
        let data = logs.joined(separator: "\n").data(using: .utf8) ?? Data()

        PlatformFileManager.saveFile(data: data, suggestedFilename: "IntuneManager-Logs.txt") { url in
            if url != nil {
                PlatformHaptics.trigger(.success)
            }
        }
    }
}

// MARK: - Root Scene

private struct RootScene: View {
    @Environment(
        \.modelContext
    ) private var modelContext
    @EnvironmentObject private var authManager: AuthManagerV2
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var credentialManager: CredentialManager
    @EnvironmentObject private var permissionService: PermissionCheckService

    @Binding var showingConfiguration: Bool
    @Binding var showingSplash: Bool
    @Binding var initializationError: Error?
    @Binding var showingPermissionWarning: Bool
    let initializeApp: () async -> Void
    let configurePlatformSpecifics: () -> Void

    var body: some View {
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
                    .environmentObject(permissionService)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingSplash)
        .task {
            LocalDataStore.shared.configure(with: modelContext)
            CacheManager.shared.configure(with: modelContext)
            DeviceService.shared.hydrateFromStore()
            ApplicationService.shared.hydrateFromStore()
            GroupService.shared.hydrateFromStore()
            let assignments = LocalDataStore.shared.fetchAssignments()
            await MainActor.run {
                AssignmentService.shared.assignmentHistory = assignments
            }
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
        .alert("Missing Permissions", isPresented: $showingPermissionWarning) {
            Button("Continue Anyway") {
                showingPermissionWarning = false
            }
            Button("Copy Permission List") {
                copyPermissionsToClipboard()
            }
            Button("View Details") {
                appState.selectedTab = .settings
                showingPermissionWarning = false
            }
        } message: {
            Text(permissionService.missingSummary)
        }
        .preferredColorScheme(appState.preferredColorScheme)
    }

    private func copyPermissionsToClipboard() {
        let missingScopes = permissionService.missingPermissions.map { $0.scope }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(missingScopes, forType: .string)
    }
}

// MARK: - Splash Screen

struct SplashView: View {
    @State private var isAnimating = false
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.3),
                    Color.purple.opacity(0.2),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if #available(macOS 15, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .blur(radius: 90)
                    .opacity(0.35)
                    .ignoresSafeArea()
            }

            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    Image(systemName: "laptopcomputer")
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

                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                    .tint(.accentColor)
            }
            .padding(40)
            .platformGlassBackground(cornerRadius: 32)
        }
        .onAppear {
            isAnimating = true
            withAnimation(.linear(duration: 1.0)) {
                progress = 1.0
            }
        }
    }
}
