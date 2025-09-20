import SwiftUI

struct AssignmentSettingsView: View {
    @Binding var intent: Assignment.AssignmentIntent
    @Binding var settings: Assignment.AssignmentSettings?
    
    var body: some View {
        Form {
            Section("Assignment Intent") {
                Picker("Intent", selection: $intent) {
                    ForEach(Assignment.AssignmentIntent.allCases, id: \.self) { intent in
                        Label(intent.displayName, systemImage: intent.icon)
                            .tag(intent)
                    }
                }
                .pickerStyle(.segmented)
                
                Text(intentDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Notification Settings") {
                Toggle("Enable notifications", isOn: .init(
                    get: { settings?.notificationEnabled ?? false },
                    set: { newValue in
                        if settings == nil { settings = Assignment.AssignmentSettings() }
                        settings?.notificationEnabled = newValue
                    }
                ))
            }
        }
        .padding()
    }
    
    private var intentDescription: String {
        switch intent {
        case .required:
            return "Apps will be automatically installed and cannot be uninstalled by users."
        case .available:
            return "Apps will be available for users to install from Company Portal."
        case .uninstall:
            return "Apps will be uninstalled from targeted devices."
        case .availableWithoutEnrollment:
            return "Apps will be available without device enrollment."
        }
    }
}