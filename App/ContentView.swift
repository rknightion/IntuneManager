import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                AuthenticatedView()
            } else {
                LoginView()
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
    }
}

struct AuthenticatedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        #if os(iOS)
        TabView(selection: $appState.selectedTab) {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                NavigationStack {
                    tabContent(for: tab)
                        .navigationTitle(tab.rawValue)
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        #elseif os(macOS)
        NavigationSplitView {
            SidebarView(selection: $appState.selectedTab)
        } detail: {
            NavigationStack {
                tabContent(for: appState.selectedTab)
            }
        }
        .navigationSplitViewStyle(.balanced)
        #endif
    }

    @ViewBuilder
    private func tabContent(for tab: AppState.Tab) -> some View {
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

#if os(macOS)
struct SidebarView: View {
    @Binding var selection: AppState.Tab
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        List(selection: $selection) {
            Section("Main") {
                ForEach(AppState.Tab.allCases, id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.systemImage)
                    }
                }
            }

            Section("Account") {
                HStack {
                    Image(systemName: "person.circle.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        if let user = authManager.currentUser {
                            Text(user.displayName)
                                .font(.caption)
                            Text(user.email)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                Button(action: {
                    Task {
                        await authManager.signOut()
                    }
                }) {
                    Label("Sign Out", systemImage: "arrow.right.square")
                }
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("IntuneManager")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.leading")
                }
            }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}
#endif

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("IntuneManager")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Manage your Microsoft Intune devices efficiently")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 20) {
                Button(action: signIn) {
                    HStack {
                        if isLoading {
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
                .disabled(isLoading)
                .buttonStyle(.plain)

                Text("You'll be redirected to Microsoft to authenticate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func signIn() {
        isLoading = true

        Task {
            do {
                try await authManager.signIn()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(AppState())
}