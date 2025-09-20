import SwiftUI

struct ConfigurationView: View {
    @StateObject private var credentialManager = CredentialManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var clientId = ""
    @State private var tenantId = ""
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

                    // Required Fields
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Required Information")
                            .font(.headline)

                        ConfigField(
                            title: "Client ID",
                            placeholder: "00000000-0000-0000-0000-000000000000",
                            text: $clientId,
                            focused: $focusedField,
                            field: .clientId,
                            helpText: "Application (client) ID from Azure AD app registration"
                        )

                        ConfigField(
                            title: "Tenant ID",
                            placeholder: "common, organizations, or tenant ID",
                            text: $tenantId,
                            focused: $focusedField,
                            field: .tenantId,
                            helpText: "Directory (tenant) ID or 'common' for multi-tenant"
                        )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)

                    // Optional Fields
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Optional Configuration")
                            .font(.headline)

                        // Native apps use PKCE flow - no client secret needed
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No Client Secret Required")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("This native app uses PKCE (Proof Key for Code Exchange) for secure authentication. Your app never sees user passwords.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 8)

                        Toggle("Custom Redirect URI", isOn: $useCustomRedirectUri)
                            .toggleStyle(SwitchToggleStyle())

                        if useCustomRedirectUri {
                            TextField("Redirect URI", text: $customRedirectUri)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .redirectUri)
                                .help("Leave empty to use default: msauth.bundleId://auth")
                        } else {
                            HStack {
                                Text("Default:")
                                    .foregroundColor(.secondary)
                                Text(defaultRedirectUri)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)

                    // Documentation Links
                    DocumentationLinks()
                }
                .padding()
            }

            // Action Buttons
            HStack(spacing: 16) {
                if credentialManager.isConfigured {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

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
        #if os(macOS)
        .frame(width: 600, height: 700)
        #else
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Configuration Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Configuration Saved", isPresented: $showingSuccess) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Your configuration has been saved successfully. You can now sign in with your Microsoft account.")
        }
        .onAppear {
            loadExistingConfiguration()
        }
    }

    private var isValid: Bool {
        !clientId.isEmpty && !tenantId.isEmpty &&
        (!useClientSecret || !clientSecret.isEmpty) &&
        (!useCustomRedirectUri || !customRedirectUri.isEmpty)
    }

    private var defaultRedirectUri: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.intunemanager"
        return "msauth.\(bundleId)://auth"
    }

    private func loadExistingConfiguration() {
        if let config = credentialManager.configuration {
            clientId = config.clientId
            tenantId = config.tenantId
            if let secret = config.clientSecret, !secret.isEmpty {
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

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.icloud.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Configure IntuneManager")
                .font(.title)
                .fontWeight(.bold)

            Text("Enter your Microsoft Azure AD application credentials")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
    }
}

struct InstructionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Setup Instructions", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 8) {
                InstructionStep(number: 1, text: "Register an app in Azure AD")
                InstructionStep(number: 2, text: "Configure API permissions for Microsoft Graph")
                InstructionStep(number: 3, text: "Copy the Client ID and Tenant ID")
                #if os(macOS)
                InstructionStep(number: 4, text: "Create a client secret (only for server apps)")
                InstructionStep(number: 5, text: "Configure redirect URI in Azure AD")
                #else
                InstructionStep(number: 4, text: "Configure redirect URI in Azure AD")
                #endif
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
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
            Text("Documentation")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Link(destination: URL(string: "https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app")!) {
                    Label("Register an application", systemImage: "arrow.up.right.square")
                        .font(.subheadline)
                }

                Link(destination: URL(string: "https://docs.microsoft.com/en-us/graph/permissions-reference")!) {
                    Label("Microsoft Graph permissions", systemImage: "arrow.up.right.square")
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