import SwiftUI

struct AssignmentSettingsView: View {
    @Binding var intent: Assignment.AssignmentIntent
    @Binding var settings: Assignment.AssignmentSettings?
    @Binding var targetPlatform: Application.DevicePlatform?
    let availablePlatforms: Set<Application.DevicePlatform>

    var body: some View {
        Form {
            // Platform Selection (if multiple platforms available)
            if availablePlatforms.count > 1 {
                Section("Target Platform") {
                    Picker("Target Platform", selection: $targetPlatform) {
                        Text("All Supported Platforms").tag(Application.DevicePlatform?.none)
                        ForEach(Array(availablePlatforms.sorted { $0.rawValue < $1.rawValue }), id: \.self) { platform in
                            Label(platform.displayName, systemImage: platform.icon)
                                .tag(Application.DevicePlatform?.some(platform))
                        }
                    }
                    .pickerStyle(.menu)

                    if let platform = targetPlatform {
                        Text("Apps will only be assigned to \(platform.displayName) devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Apps will be assigned to all compatible devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Assignment Intent") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How should this app be deployed?")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Picker("Intent", selection: $intent) {
                        ForEach(Assignment.AssignmentIntent.allCases, id: \.self) { intent in
                            Label(intent.displayName, systemImage: intent.icon)
                                .tag(intent)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    // Detailed description based on selected intent
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: intent.icon)
                            .foregroundColor(.accentColor)
                            .font(.footnote)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intent.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(intentDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Section("Notification Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable notifications", isOn: .init(
                        get: { settings?.notificationEnabled ?? false },
                        set: { newValue in
                            if settings == nil { settings = Assignment.AssignmentSettings() }
                            settings?.notificationEnabled = newValue
                        }
                    ))

                    Text("When enabled, users will receive notifications in Company Portal and system notifications about:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("App installation progress", systemImage: "arrow.down.circle")
                        Label("App updates available", systemImage: "arrow.clockwise")
                        Label("Installation completion", systemImage: "checkmark.circle")
                        Label("Required restarts", systemImage: "arrow.counterclockwise")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
                }
            }
        }
        .padding()
    }
    
    private var intentDescription: String {
        switch intent {
        case .required:
            return "The app will be automatically installed on all targeted devices. Users cannot uninstall the app, and it's required for device compliance. Installation happens in the background without user interaction."
        case .available:
            return "The app appears in Company Portal for users to install on-demand. Users have full control to install, uninstall, and reinstall as needed. Perfect for optional productivity apps."
        case .uninstall:
            return "The app will be removed from all targeted devices where it's currently installed. This action cannot be reversed by users. Use this to clean up unwanted or outdated applications."
        case .availableWithoutEnrollment:
            return "The app is available to users on personal devices without requiring MDM enrollment. Ideal for BYOD scenarios where full device management isn't appropriate."
        }
    }
}