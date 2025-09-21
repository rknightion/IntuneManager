import SwiftUI

/// Unified content view that provides consistent navigation across iOS and macOS
struct UnifiedContentView: View {
    @EnvironmentObject var authManager: AuthManagerV2
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        if authManager.isAuthenticated {
            authenticatedView
        } else {
            UnifiedLoginView()
        }
    }
    @ViewBuilder
    private var authenticatedView: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad uses split view like macOS
            splitViewLayout
        } else {
            // iPhone uses tab bar
            tabBarLayout
        }
        #else
        // macOS uses split view
        splitViewLayout
        #endif
    }

    private var splitViewLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            UnifiedSidebarView(selection: $appState.selectedTab)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            NavigationStack {
                destinationView(for: appState.selectedTab)
                    .navigationTitle(appState.selectedTab.rawValue)
                    .toolbarTitleDisplayMode(.automatic)
            }
            .platformGlassBackground()
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var tabBarLayout: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                NavigationStack {
                    destinationView(for: tab)
                        .navigationTitle(tab.rawValue)
                        .toolbarTitleDisplayMode(.automatic)
                }
                .platformGlassBackground()
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for tab: AppState.Tab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView()
        case .devices:
            DeviceListView()
        case .applications:
            ApplicationListView()
        case .groups:
            GroupListView()
        case .assignments:
            BulkAssignmentView()
        case .settings:
            SettingsView()
        }
    }
}

/// Unified sidebar for split view layouts
struct UnifiedSidebarView: View {
    @Binding var selection: AppState.Tab
    @EnvironmentObject var authManager: AuthManagerV2
    @EnvironmentObject var credentialManager: CredentialManager
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    @State private var showingConfiguration = false

    var body: some View {
        sidebarContent
        .navigationTitle("IntuneManager")
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.leading")
                }
            }
            #endif
        }
        .platformGlassBackground()
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authManager)
                .environmentObject(credentialManager)
        }
        .sheet(isPresented: $showingConfiguration) {
            ConfigurationView()
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        #if os(macOS)
        List(selection: $selection) {
            navigationSectionMac
            accountSection
            actionsSection
        }
        .listStyle(SidebarListStyle())
        #else
        List {
            navigationSectionIOS
            accountSection
            actionsSection
        }
        .listStyle(.insetGrouped)
        #endif
    }

    @ViewBuilder
    private var navigationSectionMac: some View {
        Section("Navigation") {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                }
            }
        }
    }

    @ViewBuilder
    private var navigationSectionIOS: some View {
        Section("Navigation") {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                        .foregroundColor(selection == tab ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .listRowBackground(selection == tab ? Color.accentColor.opacity(0.15) : Color.clear)
            }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if let user = authManager.currentUser {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading) {
                            Text(user.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if let tenantId = user.tenantId {
                        Text("Tenant: \(tenantId)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if let expiration = authManager.tokenExpirationDate {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(expiration, style: .relative)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Button(action: { showingSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }

            Button(action: { showingConfiguration = true }) {
                Label("Reconfigure", systemImage: "wrench.and.screwdriver")
            }

            Button(action: signOut) {
                Label("Sign Out", systemImage: "arrow.right.square")
                    .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section("Actions") {
            Button(action: refresh) {
                Label("Refresh All", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

            Button(action: clearCache) {
                Label("Clear Cache", systemImage: "trash")
            }
        }
    }

    private func signOut() {
        Task {
            await authManager.signOut()
        }
    }

    private func refresh() {
        Task {
            await appState.syncAll()
        }
    }

    private func clearCache() {
        LocalDataStore.shared.reset()
        DeviceService.shared.hydrateFromStore()
        ApplicationService.shared.hydrateFromStore()
        GroupService.shared.hydrateFromStore()
        AssignmentService.shared.assignmentHistory = []
        PlatformHaptics.trigger(.success)
    }

    #if os(macOS)
    private func toggleSidebar() {
        PlatformHelper.toggleSidebar()
    }
    #endif
}

/// Unified login view that works across platforms
struct UnifiedLoginView: View {
    @EnvironmentObject var authManager: AuthManagerV2
    @EnvironmentObject var credentialManager: CredentialManager
    @State private var showConfiguration = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 32) {
                logoSection
                signInSection

                if let config = credentialManager.configuration {
                    configurationInfo(config)
                }
            }
            .padding(32)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .platformGlassBackground(cornerRadius: 30)
            .padding(.horizontal)
            .padding(.top, 80)
            .padding(.bottom, 120)
        }
        .background(liquidGlassBackground)
        .sheet(isPresented: $showConfiguration) {
            ConfigurationView()
                #if os(iOS)
                .presentationDetents([.large])
                #endif
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var logoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse)

            Text("IntuneManager")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Manage your Microsoft Intune devices efficiently")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var signInSection: some View {
        VStack(spacing: 20) {
            if authManager.isLoading {
                ProgressView("Authenticating...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            } else {
                PlatformButton(title: "Sign in with Microsoft", action: {
                    signIn()
                }, style: .primary)
                .frame(maxWidth: 300)

                Button("Reconfigure App") {
                    showConfiguration = true
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Text("You'll be redirected to Microsoft to authenticate")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func configurationInfo(_ config: AppConfiguration) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "building.2")
                    .font(.caption)
                Text("Tenant: \(config.tenantId)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            HStack {
                Image(systemName: config.isPublicClient ? "lock.open" : "lock.fill")
                    .font(.caption)
                Text(config.isPublicClient ? "Public Client" : "Confidential Client")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .platformGlassBackground(cornerRadius: 20)
    }

    private var liquidGlassBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.35),
                    Color.purple.opacity(0.15),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if #available(iOS 18, macOS 15, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .blur(radius: 60)
                    .opacity(0.3)
                    .ignoresSafeArea()
            }
        }
    }

    private func signIn() {
        // First check if we have a configuration
        guard credentialManager.configuration != nil else {
            errorMessage = "No configuration found. Please configure the app first."
            showError = true
            return
        }

        // Check if MSAL is initialized
        Task {
            do {
                // Try to initialize MSAL if not already done
                if !authManager.isAuthenticated {
                    try await authManager.initializeMSAL()
                }

                #if os(iOS)
                if let viewController = await PlatformHelper.getRootViewController() {
                    try await authManager.signIn(from: viewController)
                }
                #else
                try await authManager.signIn()
                #endif
                PlatformHaptics.trigger(.success)
            } catch AuthError.msalNotInitialized {
                await MainActor.run {
                    errorMessage = "Authentication system not initialized. Please restart the app."
                    showError = true
                }
                PlatformHaptics.trigger(.error)
            } catch AuthError.notConfigured {
                await MainActor.run {
                    errorMessage = "App not configured. Please complete the setup first."
                    showError = true
                }
                PlatformHaptics.trigger(.error)
            } catch AuthError.invalidConfiguration(let message) {
                await MainActor.run {
                    errorMessage = "Invalid configuration: \(message)"
                    showError = true
                }
                PlatformHaptics.trigger(.error)
            } catch AuthError.signInFailed(let underlyingError) {
                await MainActor.run {
                    errorMessage = "Sign in failed: \(underlyingError.localizedDescription)"
                    showError = true
                }
                PlatformHaptics.trigger(.error)
            } catch {
                await MainActor.run {
                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    showError = true
                }
                PlatformHaptics.trigger(.error)
            }
        }
    }
}

// MARK: - Platform-Specific Extensions

extension View {
    /// Applies platform-specific navigation styling
    func platformNavigation() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }

    /// Applies platform-specific list styling
    func platformList() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.sidebar)
        #endif
    }
}
