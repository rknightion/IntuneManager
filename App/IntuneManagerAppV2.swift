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
            Group {
                if showingSplash {
                    SplashScreen()
                } else if !credentialManager.isConfigured || showingConfiguration {
                    ConfigurationView()
                } else {
                    MainContentView()
                        .environmentObject(authManager)
                        .environmentObject(appState)
                        .environmentObject(credentialManager)
                }
            }
            .task {
                await initializeApp()
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
            CommandMenu("Authentication") {
                if authManager.isAuthenticated {
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
                    .keyboardShortcut("L", modifiers: [.command])
                }

                Divider()

                Button("Reconfigure") {
                    showingConfiguration = true
                }
                .keyboardShortcut(",", modifiers: [.command, .option])
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(authManager)
                .environmentObject(appState)
                .environmentObject(credentialManager)
        }
        #endif
    }

    private func initializeApp() async {
        // Initialize logging
        Logger.shared.configure()

        // Setup cache manager
        CacheManager.shared.configure()

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
}

struct MainContentView: View {
    @EnvironmentObject var authManager: AuthManagerV2
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                AuthenticatedView()
            } else {
                EnhancedLoginView()
            }
        }
        .alert("Error", isPresented: .constant(appState.error != nil)) {
            Button("OK") {
                appState.error = nil
            }
        } message: {
            if let error = appState.error {
                Text(error.localizedDescription)
            }
        }
        .alert("Authentication Error", isPresented: .constant(authManager.authenticationError != nil)) {
            Button("Retry") {
                Task {
                    try? await authManager.signIn()
                }
            }
            Button("Cancel", role: .cancel) {
                authManager.authenticationError = nil
            }
        } message: {
            if let error = authManager.authenticationError {
                Text(error.localizedDescription)
            }
        }
    }
}

struct EnhancedLoginView: View {
    @EnvironmentObject var authManager: AuthManagerV2
    @EnvironmentObject var credentialManager: CredentialManager
    @State private var isLoading = false
    @State private var showConfiguration = false

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse)

                Text("IntuneManager")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Manage your Microsoft Intune devices efficiently")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if let config = credentialManager.configuration {
                    HStack {
                        Image(systemName: "building.2")
                        Text("Tenant: \(config.tenantId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }

            VStack(spacing: 20) {
                Button(action: signIn) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "person.badge.key")
                        }
                        Text("Sign in with Microsoft")
                    }
                    .frame(maxWidth: 300)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(authManager.isLoading)
                .buttonStyle(.plain)

                Button("Reconfigure App") {
                    showConfiguration = true
                }
                .font(.caption)
                .foregroundColor(.secondary)

                VStack(spacing: 4) {
                    Text("You'll be redirected to Microsoft to authenticate")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if authManager.tokenExpirationDate != nil {
                        HStack {
                            Image(systemName: "clock")
                            Text("Session expires: \(authManager.tokenExpirationDate!, style: .relative)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
        .sheet(isPresented: $showConfiguration) {
            ConfigurationView()
        }
    }

    private func signIn() {
        Task {
            do {
                #if os(iOS)
                if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    try await authManager.signIn(from: rootViewController)
                }
                #else
                try await authManager.signIn()
                #endif
            } catch {
                // Error is handled by the alert in MainContentView
            }
        }
    }
}

struct SplashScreen: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Text("IntuneManager")
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}