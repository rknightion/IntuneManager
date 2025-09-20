import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Settings interface shared across platforms
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManagerV2
    @EnvironmentObject var credentialManager: CredentialManager
    @AppStorage("refreshInterval") private var refreshInterval = 60
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("batchSize") private var batchSize = 20
    @State private var storageSummary = StorageSummary()

    var body: some View {
        #if os(iOS)
        NavigationView {
            settingsForm
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            storageSummary = LocalDataStore.shared.summary()
        }
        #else
        settingsForm
            .frame(width: 500, height: 600)
            .onAppear {
                storageSummary = LocalDataStore.shared.summary()
            }
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
        .scrollContentBackground(.hidden)
        .platformFormStyle()
        .padding(.vertical, 12)
        .platformGlassBackground(cornerRadius: 26)
        .padding(.horizontal)
        .background(settingsBackground)
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
            } else {
                Text("Not signed in")
                    .foregroundColor(.secondary)
            }

            if let configuration = credentialManager.configuration {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tenant ID: \(configuration.tenantId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Client ID: \(configuration.clientId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
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
                Text("Persisted Data")
                Spacer()
                Text(storageSummary.formatted)
                    .foregroundColor(.secondary)
            }

            Button("Clear Cache") {
                LocalDataStore.shared.reset()
                storageSummary = StorageSummary()
                PlatformHaptics.trigger(.success)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                    .foregroundColor(.secondary)
            }

            Link("Documentation", destination: URL(string: "https://github.com/yourusername/intune-macos-tools")!)
            Link("Report Issue", destination: URL(string: "https://github.com/yourusername/intune-macos-tools/issues")!)
        }
    }

    private var settingsBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.2),
                    Color.secondary.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if #available(iOS 18, macOS 15, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .blur(radius: 80)
                    .opacity(0.35)
                    .ignoresSafeArea()
            }
        }
    }
}
