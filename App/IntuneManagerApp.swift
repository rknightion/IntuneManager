import SwiftUI

@main
struct IntuneManagerApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appState = AppState()
    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appState)
                .task {
                    await initializeApp()
                }
                .onAppear {
                    configurePlatformSpecifics()
                }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About IntuneManager") {
                    appState.showingAbout = true
                }
            }
            CommandMenu("Device") {
                Button("Refresh Devices") {
                    Task {
                        await appState.refreshDevices()
                    }
                }
                .keyboardShortcut("R", modifiers: [.command])

                Divider()

                Button("Sync All") {
                    Task {
                        await appState.syncAll()
                    }
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(authManager)
                .environmentObject(appState)
        }
        #endif
    }

    private func initializeApp() async {
        // Initialize logging
        Logger.shared.configure()

        // Setup cache manager
        CacheManager.shared.configure()

        // Check authentication state
        await authManager.checkAuthenticationState()

        // Load initial data if authenticated
        if authManager.isAuthenticated {
            await appState.loadInitialData()
        }

        // Hide splash after initialization
        withAnimation {
            showingSplash = false
        }
    }

    private func configurePlatformSpecifics() {
        #if os(iOS)
        // iOS specific configuration
        UIApplication.shared.isIdleTimerDisabled = false
        #elseif os(macOS)
        // macOS specific configuration
        NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon")
        #endif
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingAbout = false
    @Published var selectedTab: Tab = .dashboard
    @Published var syncStatus: SyncStatus = .idle

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case devices = "Devices"
        case applications = "Applications"
        case groups = "Groups"
        case assignments = "Assignments"

        var systemImage: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .devices: return "laptopcomputer"
            case .applications: return "app.badge"
            case .groups: return "person.3"
            case .assignments: return "arrow.right.square"
            }
        }
    }

    enum SyncStatus {
        case idle
        case syncing
        case success
        case failure(Error)
    }

    @MainActor
    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load data from services
            async let devices = DeviceService.shared.fetchDevices()
            async let apps = ApplicationService.shared.fetchApplications()
            async let groups = GroupService.shared.fetchGroups()

            _ = try await (devices, apps, groups)
            syncStatus = .success
        } catch {
            self.error = error
            syncStatus = .failure(error)
            Logger.shared.error("Failed to load initial data: \(error)")
        }
    }

    @MainActor
    func refreshDevices() async {
        do {
            _ = try await DeviceService.shared.fetchDevices(forceRefresh: true)
        } catch {
            self.error = error
        }
    }

    @MainActor
    func syncAll() async {
        syncStatus = .syncing

        do {
            try await SyncService.shared.performFullSync()
            syncStatus = .success
        } catch {
            syncStatus = .failure(error)
            self.error = error
        }
    }
}