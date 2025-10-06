import SwiftUI

struct AddAndroidStoreAppView: View {
    @ObservedObject var viewModel: AddApplicationViewModel
    let onComplete: () -> Void

    // Required fields
    @State private var displayName = ""
    @State private var description = ""
    @State private var publisher = ""
    @State private var appStoreUrl = ""

    // Optional fields
    @State private var minimumOS = "4.0"
    @State private var isFeatured = false
    @State private var informationUrl = ""
    @State private var privacyInformationUrl = ""
    @State private var developer = ""
    @State private var owner = ""
    @State private var notes = ""

    // UI state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var packageIdError: String?
    @State private var appStoreUrlError: String?
    @State private var extractedPackageId = ""

    let androidVersions = [
        "4.0", "4.1", "4.2", "4.3", "4.4",
        "5.0", "5.1", "6.0", "7.0", "7.1",
        "8.0", "8.1", "9.0", "10.0", "11.0",
        "12.0", "13.0", "14.0", "15.0"
    ]

    var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !publisher.trimmingCharacters(in: .whitespaces).isEmpty &&
        !appStoreUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        extractedPackageId.isEmpty == false &&
        packageIdError == nil &&
        appStoreUrlError == nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $displayName, prompt: Text("Enter app name"))
                    .textFieldStyle(.roundedBorder)
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif

                TextField("Description", text: $description, prompt: Text("Enter app description"), axis: .vertical)
                    .lineLimit(3...6)
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif

                TextField("Publisher", text: $publisher, prompt: Text("Enter publisher name"))
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif

                VStack(alignment: .leading, spacing: 4) {
                    TextField("App Store URL", text: $appStoreUrl, prompt: Text("https://play.google.com/store/apps/details?id=..."))
                    #if os(iOS)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    #endif
                    #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                    #endif
                        .onChange(of: appStoreUrl) { oldValue, newValue in
                            validateAppStoreUrl(newValue)
                        }

                    if let error = appStoreUrlError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if !extractedPackageId.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Package ID: \(extractedPackageId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Required Information")
                    .font(.headline)
            }

            Section {
                Picker("Minimum Operating System", selection: $minimumOS) {
                    ForEach(androidVersions, id: \.self) { version in
                        Text("Android \(version)").tag(version)
                    }
                }

                Toggle("Show as featured app in Company Portal", isOn: $isFeatured)
            } header: {
                Text("Configuration")
                    .font(.headline)
            }

            Section {
                TextField("Information URL", text: $informationUrl, prompt: Text("https://..."))
                #if os(iOS)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                #endif
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif

                TextField("Privacy URL", text: $privacyInformationUrl, prompt: Text("https://..."))
                #if os(iOS)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                #endif
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif

                TextField("Developer", text: $developer, prompt: Text("Optional"))
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif

                TextField("Owner", text: $owner, prompt: Text("Optional"))
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif

                TextField("Notes", text: $notes, prompt: Text("Optional notes"), axis: .vertical)
                    .lineLimit(3...6)
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif
            } header: {
                Text("Optional Information")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Android Store App")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Create") {
                    createApp()
                }
                .disabled(!isFormValid || viewModel.isLoading)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Creating app...")
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func validateAppStoreUrl(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            appStoreUrlError = nil
            extractedPackageId = ""
            return
        }

        // Validate URL format
        if let error = viewModel.validateURL(trimmed, fieldName: "App Store URL") {
            appStoreUrlError = error
            extractedPackageId = ""
            return
        }

        // Try to extract package ID from Play Store URL
        if let packageId = viewModel.extractPackageIdFromURL(trimmed) {
            extractedPackageId = packageId

            // Validate the extracted package ID
            if let error = viewModel.validatePackageId(packageId) {
                packageIdError = error
                appStoreUrlError = "Invalid package ID in URL"
            } else {
                packageIdError = nil
                appStoreUrlError = nil
            }
        } else {
            appStoreUrlError = "Could not extract package ID from URL. Expected format: https://play.google.com/store/apps/details?id=com.example.app"
            extractedPackageId = ""
        }
    }

    private func createApp() {
        Task {
            do {
                _ = try await viewModel.createAndroidStoreApp(
                    displayName: displayName,
                    description: description,
                    publisher: publisher,
                    packageId: extractedPackageId,
                    appStoreUrl: appStoreUrl,
                    minimumOS: minimumOS,
                    isFeatured: isFeatured,
                    informationUrl: informationUrl,
                    privacyInformationUrl: privacyInformationUrl,
                    developer: developer,
                    owner: owner,
                    notes: notes
                )

                // Success - dismiss the view
                onComplete()
            } catch {
                errorMessage = viewModel.errorMessage(from: error)
                showingError = true
            }
        }
    }
}
