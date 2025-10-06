import SwiftUI

struct AddAndroidEnterpriseSystemAppView: View {
    @ObservedObject var viewModel: AddApplicationViewModel
    let onComplete: () -> Void

    // Required fields
    @State private var displayName = ""
    @State private var publisher = ""
    @State private var packageName = ""

    // UI state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var packageNameError: String?

    var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !publisher.trimmingCharacters(in: .whitespaces).isEmpty &&
        !packageName.trimmingCharacters(in: .whitespaces).isEmpty &&
        packageNameError == nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $displayName, prompt: Text("Enter app name"))
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif

                TextField("Publisher", text: $publisher, prompt: Text("Enter publisher name"))
                #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                #endif

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Package Name", text: $packageName, prompt: Text("com.example.app"))
                    #if os(iOS)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    #endif
                    #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                    #endif
                        .onChange(of: packageName) { oldValue, newValue in
                            validatePackageName(newValue)
                        }

                    if let error = packageNameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if !packageName.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Valid package name format")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Example: com.google.android.gm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Required Information")
                    .font(.headline)
            } footer: {
                Text("Package name must follow the format: lowercase letters, numbers, and dots (e.g., com.example.app)")
                    .font(.caption)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Enterprise System App", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundColor(.blue)

                    Text("This option is for pre-installed Android system apps that are part of the device's firmware. The app must already exist on the device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Android Enterprise System App")
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

    private func validatePackageName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            packageNameError = nil
            return
        }

        packageNameError = viewModel.validatePackageId(trimmed)
    }

    private func createApp() {
        Task {
            do {
                _ = try await viewModel.createAndroidEnterpriseSystemApp(
                    displayName: displayName,
                    publisher: publisher,
                    packageId: packageName
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
