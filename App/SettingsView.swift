import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("refreshInterval") private var refreshInterval = 60
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("batchSize") private var batchSize = 20
    @State private var showingSignOut = false
    
    var body: some View {
        Form {
            Section("Account") {
                if let user = authManager.currentUser {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(user.displayName)
                                .font(.headline)
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Sign Out") {
                            showingSignOut = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Section("Sync Settings") {
                Picker("Auto Refresh", selection: $refreshInterval) {
                    Text("Off").tag(0)
                    Text("30 Minutes").tag(30)
                    Text("1 Hour").tag(60)
                    Text("2 Hours").tag(120)
                    Text("4 Hours").tag(240)
                }
                
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
            
            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $enableNotifications)
            }
            
            Section("Cache") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(formatBytes(CacheManager.shared.getCacheSize()))
                        .foregroundColor(.secondary)
                }
                
                Button("Clear Cache") {
                    CacheManager.shared.clearCache()
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link("Documentation", destination: URL(string: "https://github.com/yourusername/intune-macos-tools")!)
                Link("Report Issue", destination: URL(string: "https://github.com/yourusername/intune-macos-tools/issues")!)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .alert("Sign Out", isPresented: $showingSignOut) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}