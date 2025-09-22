import SwiftUI

/// Test view for simplified MSAL authentication
struct TestAuthView: View {
    @StateObject private var authManager = SimpleMSALAuth()
    @EnvironmentObject var credentialManager: CredentialManager

    @State private var clientId: String = ""
    @State private var tenantId: String = ""
    @State private var isConfigured = false

    var body: some View {
        VStack(spacing: 20) {
            Text("MSAL Test Authentication")
                .font(.largeTitle)
                .padding()

            if !isConfigured {
                configurationSection
            } else {
                authenticationSection
            }

            if let errorMessage = authManager.errorMessage {
                errorView(message: errorMessage)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            loadConfiguration()
        }
    }

    private var configurationSection: some View {
        VStack(spacing: 15) {
            Text("Configure Authentication")
                .font(.headline)

            TextField("Client ID", text: $clientId)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Tenant ID (or 'common')", text: $tenantId)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Save Configuration") {
                saveConfiguration()
            }
            .buttonStyle(.borderedProminent)
            .disabled(clientId.isEmpty || tenantId.isEmpty)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    private var authenticationSection: some View {
        VStack(spacing: 20) {
            // Status
            HStack {
                Circle()
                    .fill(authManager.isAuthenticated ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(authManager.isAuthenticated ? "Authenticated" : "Not Authenticated")
                    .font(.headline)
            }

            if let displayName = authManager.userDisplayName {
                Text("User: \(displayName)")
                    .font(.subheadline)
            }

            if let token = authManager.accessToken {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Access Token:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(token.prefix(50)) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                }
            }

            // Actions
            HStack(spacing: 20) {
                if !authManager.isAuthenticated {
                    Button("Sign In") {
                        signIn()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Refresh Token") {
                        authManager.acquireTokenSilently()
                    }
                    .buttonStyle(.bordered)

                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }

            // Reconfigure button
            Button("Reconfigure") {
                isConfigured = false
                authManager.errorMessage = nil
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding()
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.headline)

            ScrollView {
                Text(message)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

            Button("Clear Error") {
                authManager.errorMessage = nil
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding()
    }

    private func loadConfiguration() {
        if let config = credentialManager.configuration {
            clientId = config.clientId
            tenantId = config.tenantId
            isConfigured = true

            // Update auth manager with configuration
            authManager.updateConfiguration(clientId: clientId, tenantId: tenantId)
        }
    }

    private func saveConfiguration() {
        let config = AppConfiguration(
            clientId: clientId,
            tenantId: tenantId,
            clientSecret: nil,
            redirectUri: "msauth.\(Bundle.main.bundleIdentifier ?? "com.app")://auth"
        )

        Task {
            do {
                try await credentialManager.saveConfiguration(config)
                isConfigured = true
                authManager.updateConfiguration(clientId: clientId, tenantId: tenantId)
            } catch {
                authManager.errorMessage = "Failed to save configuration: \(error.localizedDescription)"
            }
        }
    }

    private func signIn() {
        #if os(iOS)
        // For iOS, we need to pass the view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            authManager.signIn(from: rootVC)
        }
        #else
        // For macOS, we can call without view controller
        authManager.signIn()
        #endif
    }
}

#Preview {
    TestAuthView()
        .environmentObject(CredentialManager.shared)
}