import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManagerV2.shared
    @StateObject private var credentialManager = CredentialManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingSignOutAlert = false
    @State private var showingClearDataAlert = false
    @State private var showingConfiguration = false
    @State private var isSigningOut = false
    @State private var signOutError: String?
    @State private var showingError = false
    @State private var showingCacheStatus = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Settings")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Manage your account and app preferences")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 24)

            ScrollView {
                VStack(spacing: 24) {
                    // Account Section
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Account", systemImage: "person.circle.fill")
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 12) {
                            if let user = authManager.currentUser {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(user.email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Not signed in")
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }

                            Button(action: {
                                if authManager.isAuthenticated {
                                    showingSignOutAlert = true
                                } else {
                                    dismiss()
                                }
                            }) {
                                Label(authManager.isAuthenticated ? "Sign Out" : "Sign In",
                                      systemImage: authManager.isAuthenticated ? "arrow.right.square" : "arrow.left.square")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(isSigningOut)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)

                    // Configuration Section
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Configuration", systemImage: "wrench.and.screwdriver.fill")
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(spacing: 12) {
                            if let config = credentialManager.configuration {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("App Registration")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Custom App Registration")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }

                                Divider()

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Tenant")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(config.tenantId == "common" ? "Multi-tenant" : config.tenantId)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                }
                            }

                            Button(action: {
                                showingConfiguration = true
                            }) {
                                Label("Modify Configuration", systemImage: "pencil.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)

                    // Data Management Section
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Data Management", systemImage: "trash.circle.fill")
                            .font(.headline)
                            .foregroundColor(.primary)

                        // Cache Status Button
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cache Status")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Monitor and manage cached data")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                            .onTapGesture {
                                showingCacheStatus = true
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Clear All Data")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("This will sign you out and remove all stored credentials and configuration.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                showingClearDataAlert = true
                            }) {
                                Label("Clear All Data", systemImage: "trash")
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.red)
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)

                    // App Information
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack {
                            Text("Version")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("1.0.0")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)

                        HStack {
                            Text("Build")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("1")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding()
            }

            // Close Button
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .frame(width: 600, height: 700)
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to use the app.")
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All Data", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This action cannot be undone. All stored credentials, configuration, and cached data will be permanently deleted.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(signOutError ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showingConfiguration) {
            ConfigurationView()
        }
        .sheet(isPresented: $showingCacheStatus) {
            CacheStatusView()
        }
        .overlay {
            if isSigningOut {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                        Text("Signing out...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                }
            }
        }
    }

    private func signOut() {
        isSigningOut = true

        Task {
            await authManager.signOut()
            await MainActor.run {
                isSigningOut = false
                dismiss()
            }
        }
    }

    private func clearAllData() {
        isSigningOut = true

        Task {
            do {
                // Sign out first if signed in
                if authManager.isAuthenticated {
                    await authManager.signOut()
                }

                // Clear configuration
                try await credentialManager.clearConfiguration()

                await MainActor.run {
                    isSigningOut = false
                    // Return to setup screen
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSigningOut = false
                    signOutError = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
