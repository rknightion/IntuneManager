import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ConfigurationView: View {
    @StateObject private var credentialManager = CredentialManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var clientId = ""
    @State private var tenantId = "common" // Default to common for multitenant
    @State private var clientSecret = ""
    @State private var useClientSecret = false
    @State private var customRedirectUri = ""
    @State private var useCustomRedirectUri = false

    @State private var isValidating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false

    @FocusState private var focusedField: Field?

    enum Field {
        case clientId, tenantId, clientSecret, redirectUri
    }

    var body: some View {
        #if os(iOS)
        GeometryReader { geometry in
            VStack(spacing: 0) {
                configContent
            }
            .ignoresSafeArea(.keyboard)
        }
        #else
        VStack(spacing: 0) {
            configContent
        }
        #endif
    }

    @ViewBuilder
    private var configContent: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()

            // Form
            ScrollView {
                VStack(spacing: 24) {
                    // Instructions
                    InstructionCard()

                    // App Registration Configuration
                    VStack(alignment: .leading, spacing: 16) {
                        Label("App Registration", systemImage: "key.fill")
                            .font(.headline)
                            .foregroundColor(.primary)

                        ConfigField(
                            title: "Client ID (Required)",
                            placeholder: "00000000-0000-0000-0000-000000000000",
                            text: $clientId,
                            focused: $focusedField,
                            field: .clientId,
                            helpText: "Application (client) ID from your Azure AD app registration"
                        )

                        ConfigField(
                            title: "Tenant ID",
                            placeholder: "common, organizations, or specific tenant ID",
                            text: $tenantId,
                            focused: $focusedField,
                            field: .tenantId,
                            helpText: "Use 'common' for multitenant access, or your specific tenant ID for single tenant"
                        )
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)

                    // Redirect URI Display
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Redirect URI Configuration", systemImage: "link.circle.fill")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("⚠️ Copy this URI and add it to your app registration in Azure AD:")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Go to Azure Portal → App registrations → Your App")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("2. Navigate to Authentication → Platform configurations")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("3. Add a platform → Mobile and desktop applications")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("4. Enter this custom redirect URI:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text(useCustomRedirectUri ? customRedirectUri.isEmpty ? defaultRedirectUri : customRedirectUri : defaultRedirectUri)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                                .textSelection(.enabled)

                            Button(action: {
                                let uri = useCustomRedirectUri && !customRedirectUri.isEmpty ? customRedirectUri : defaultRedirectUri
                                #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(uri, forType: .string)
                                #else
                                UIPasteboard.general.string = uri
                                #endif
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .help("Copy redirect URI")
                        }

                        Toggle("Use Custom Redirect URI", isOn: $useCustomRedirectUri)
                            .toggleStyle(SwitchToggleStyle())
                            .padding(.top, 4)

                        if useCustomRedirectUri {
                            TextField("Custom Redirect URI", text: $customRedirectUri)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .redirectUri)
                                .help("Only change if you have a specific redirect URI requirement")
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(12)

                    // Documentation Links
                    DocumentationLinks()
                }
                .padding()
            }

            // Footer
            VStack {
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }

                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    if isValidating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }

                    Button("Save & Continue") {
                        saveConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || isValidating)
                }
                .padding()
                #if os(iOS)
                .background(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
                #endif
            }
        }
        .navigationTitle("Setup")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Configuration Saved", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your Azure AD configuration has been saved successfully. You can now sign in.")
        }
        .alert("Configuration Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadExistingConfiguration()
        }
    }

    private var isValid: Bool {
        // Client ID is now required
        guard !clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !tenantId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        // Validate UUID format for client ID
        let clientIdTrimmed = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let uuidRegex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
        guard clientIdTrimmed.matches(of: uuidRegex).count > 0 else { return false }

        if useCustomRedirectUri && customRedirectUri.isEmpty {
            return false
        }

        return true
    }

    private var defaultRedirectUri: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.example.IntuneManager"
        return "msauth.\(bundleId)://auth"
    }

    private func loadExistingConfiguration() {
        if let config = credentialManager.configuration {
            clientId = config.clientId
            tenantId = config.tenantId

            if let secret = config.clientSecret {
                clientSecret = secret
                useClientSecret = true
            }

            if config.redirectUri != defaultRedirectUri {
                customRedirectUri = config.redirectUri
                useCustomRedirectUri = true
            }
        }
    }

    private func saveConfiguration() {
        isValidating = true
        errorMessage = ""

        Task {
            do {
                let redirectUri = useCustomRedirectUri && !customRedirectUri.isEmpty
                    ? customRedirectUri
                    : defaultRedirectUri

                let config = AppConfiguration(
                    clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
                    tenantId: tenantId.trimmingCharacters(in: .whitespacesAndNewlines),
                    clientSecret: useClientSecret ? clientSecret.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    redirectUri: redirectUri
                )

                try await credentialManager.saveConfiguration(config)

                // Initialize MSAL with new configuration
                try await AuthManagerV2.shared.initializeMSAL()

                await MainActor.run {
                    isValidating = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.icloud.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Azure AD Setup Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create an app registration in Azure AD to connect IntuneManager")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }
}

struct InstructionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Setup Instructions", systemImage: "checklist")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 12) {
                Text("You need to create an app registration in Azure AD:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    InstructionStep(
                        number: "1",
                        title: "Create App Registration",
                        description: "Go to Azure Portal → Azure Active Directory → App registrations → New registration"
                    )

                    InstructionStep(
                        number: "2",
                        title: "Configure Application",
                        description: "Name: 'IntuneManager', Supported account types: 'Multitenant' or 'Single tenant'"
                    )

                    InstructionStep(
                        number: "3",
                        title: "Add Redirect URI",
                        description: "After creation, go to Authentication → Add platform → Mobile/Desktop → Add the redirect URI shown below"
                    )

                    InstructionStep(
                        number: "4",
                        title: "Configure Permissions",
                        description: "Go to API Permissions → Add the required Microsoft Graph permissions listed below"
                    )

                    InstructionStep(
                        number: "5",
                        title: "Enable Public Client",
                        description: "In Authentication settings, set 'Allow public client flows' to 'Yes'"
                    )
                }
            }

            // Required Permissions Section
            VStack(alignment: .leading, spacing: 8) {
                Label("Required Microsoft Graph Permissions", systemImage: "lock.shield")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    PermissionRow(permission: "User.Read", description: "Sign in and read user profile", required: true)
                    PermissionRow(permission: "DeviceManagementManagedDevices.Read.All", description: "Read Microsoft Intune devices", required: true)
                    PermissionRow(permission: "DeviceManagementApps.Read.All", description: "Read Microsoft Intune apps", required: true)
                    PermissionRow(permission: "Group.Read.All", description: "Read all groups", required: true)
                    PermissionRow(permission: "DeviceManagementConfiguration.Read.All", description: "Read device configurations", required: false)
                    PermissionRow(permission: "DeviceManagementManagedDevices.PrivilegedOperations.All", description: "Perform user actions on devices", required: false)
                }
                .padding(12)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct InstructionStep: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PermissionRow: View {
    let permission: String
    let description: String
    let required: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(permission)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)

                Button(action: {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(permission, forType: .string)
                    #else
                    UIPasteboard.general.string = permission
                    #endif
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Copy permission name")

                if required {
                    Text("(Required)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }

            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct ConfigField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<ConfigurationView.Field?>.Binding
    let field: ConfigurationView.Field
    let helpText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused(focused, equals: field)
                .font(.system(.body, design: .monospaced))

            Text(helpText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DocumentationLinks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Documentation", systemImage: "book.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Link(destination: URL(string: "https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app")!) {
                    Label("Register an application in Azure AD", systemImage: "arrow.up.right.square")
                        .font(.subheadline)
                }

                Link(destination: URL(string: "https://docs.microsoft.com/en-us/graph/permissions-reference")!) {
                    Label("Microsoft Graph permissions reference", systemImage: "arrow.up.right.square")
                        .font(.subheadline)
                }

                Link(destination: URL(string: "https://docs.microsoft.com/en-us/azure/active-directory/develop/msal-overview")!) {
                    Label("MSAL documentation", systemImage: "arrow.up.right.square")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    ConfigurationView()
}