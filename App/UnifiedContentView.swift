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
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var tabBarLayout: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                NavigationStack {
                    destinationView(for: tab)
                        .navigationTitle(tab.rawValue)
                }
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
        }
    }
}

/// Unified sidebar for split view layouts
struct UnifiedSidebarView: View {
    @Binding var selection: AppState.Tab
    @EnvironmentObject var authManager: AuthManagerV2
    @EnvironmentObject var credentialManager: CredentialManager
    @State private var showingSettings = false
    @State private var showingConfiguration = false

    var body: some View {
        List(selection: $selection) {
            Section("Navigation") {
                ForEach(AppState.Tab.allCases, id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.systemImage)
                    }
                }
            }

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
        .listStyle(SidebarListStyle())
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authManager)
                .environmentObject(credentialManager)
        }
        .sheet(isPresented: $showingConfiguration) {
            ConfigurationView()
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
        CacheManager.shared.clearCache()
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

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 30) {
                    Spacer(minLength: geometry.size.height * 0.1)

                    // Logo and title
                    logoSection

                    // Sign in section
                    signInSection

                    // Configuration info
                    if let config = credentialManager.configuration {
                        configurationInfo(config)
                    }

                    Spacer(minLength: geometry.size.height * 0.1)
                }
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .background(backgroundGradient)
        .sheet(isPresented: $showConfiguration) {
            ConfigurationView()
                #if os(iOS)
                .presentationDetents([.large])
                #endif
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
                PlatformButton(title: "Sign in with Microsoft", style: .primary) {
                    signIn()
                }
                .frame(maxWidth: 300)

                Button("Reconfigure App") {
                    showConfiguration = true
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Text("You'll be redirected to Microsoft to authenticate")
                .font(.caption2)
                .foregroundColor(.tertiary)
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
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(white: 0.95),
                Color(white: 0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func signIn() {
        Task {
            do {
                #if os(iOS)
                if let viewController = await PlatformHelper.getRootViewController() {
                    try await authManager.signIn(from: viewController)
                }
                #else
                try await authManager.signIn()
                #endif
                PlatformHaptics.trigger(.success)
            } catch {
                PlatformHaptics.trigger(.error)
                // Error handled by alert in parent view
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