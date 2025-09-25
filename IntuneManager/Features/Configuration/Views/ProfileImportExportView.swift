import SwiftUI
import UniformTypeIdentifiers

struct ProfileImportExportView: View {
    @StateObject private var viewModel = ConfigurationViewModel()
    @State private var selectedProfiles = Set<ConfigurationProfile>()
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportData: Data?
    @State private var showingImportConfirmation = false
    @State private var profilesToImport: [ConfigurationProfile] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Export Section
                exportSection

                Divider()

                // Import Section
                importSection
            }
            .navigationTitle("Import/Export Profiles")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: ProfileExportDocument(data: exportData),
                contentType: .json,
                defaultFilename: exportFilename
            ) { result in
                handleExportResult(result)
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Import Profiles", isPresented: $showingImportConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Import") {
                    Task {
                        await importProfiles()
                    }
                }
            } message: {
                Text("Import \(profilesToImport.count) profile(s)? They will be added as new profiles with new IDs.")
            }
            .alert("Import/Export", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Export Profiles", systemImage: "square.and.arrow.up")
                .font(.headline)

            Text("Select profiles to export as JSON for backup or sharing")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.profiles.isEmpty {
                        ContentUnavailableView(
                            "No Profiles",
                            systemImage: "doc.text",
                            description: Text("No profiles available to export")
                        )
                        .frame(height: 200)
                    } else {
                        ForEach(viewModel.profiles) { profile in
                            ProfileSelectionRow(
                                profile: profile,
                                isSelected: selectedProfiles.contains(profile)
                            ) {
                                if selectedProfiles.contains(profile) {
                                    selectedProfiles.remove(profile)
                                } else {
                                    selectedProfiles.insert(profile)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: 300)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            HStack {
                Button("Select All") {
                    selectedProfiles = Set(viewModel.profiles)
                }
                .buttonStyle(.bordered)

                Button("Clear Selection") {
                    selectedProfiles.removeAll()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: exportSelectedProfiles) {
                    Label("Export Selected (\(selectedProfiles.count))", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedProfiles.isEmpty)
            }
        }
        .padding()
        .task {
            await viewModel.loadProfiles()
        }
    }

    var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Import Profiles", systemImage: "square.and.arrow.down")
                .font(.headline)

            Text("Import profiles from a JSON file exported from IntuneManager")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack {
                Image(systemName: "doc.badge.arrow.up.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Drop JSON file here or click to browse")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { showingImporter = true }) {
                    Label("Choose File...", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(.gray.opacity(0.3))
            )
            .onDrop(of: [.json], isTargeted: nil) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
        .padding()
    }

    var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = formatter.string(from: Date())

        if selectedProfiles.count == 1, let profile = selectedProfiles.first {
            return "profile-\(profile.displayName.replacingOccurrences(of: " ", with: "_"))-\(dateString).json"
        } else {
            return "profiles-export-\(dateString).json"
        }
    }

    func exportSelectedProfiles() {
        do {
            let profiles = Array(selectedProfiles)
            if profiles.count == 1 {
                exportData = try ProfileExportService.shared.exportProfile(profiles[0])
            } else {
                exportData = try ProfileExportService.shared.exportProfiles(profiles)
            }
            showingExporter = true
        } catch {
            alertMessage = "Failed to export profiles: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertMessage = "Successfully exported \(selectedProfiles.count) profile(s) to \(url.lastPathComponent)"
            showingAlert = true
            selectedProfiles.removeAll()
        case .failure(let error):
            alertMessage = "Export failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importFromURL(url)
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: UTType.json.identifier, options: nil) { data, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.alertMessage = "Drop failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
                return
            }

            guard let data = data as? Data else { return }

            DispatchQueue.main.async {
                self.processImportData(data)
            }
        }
    }

    func importFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            processImportData(data)
        } catch {
            alertMessage = "Failed to read file: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func processImportData(_ data: Data) {
        let validationResult = ProfileExportService.shared.validateProfileData(data)

        if !validationResult.isValid {
            alertMessage = "Invalid file format: \(validationResult.errors.joined(separator: ", "))"
            showingAlert = true
            return
        }

        do {
            // Try single profile first
            if let profile = try? ProfileExportService.shared.importProfile(from: data) {
                profilesToImport = [profile]
            } else {
                // Try batch import
                profilesToImport = try ProfileExportService.shared.importProfiles(from: data)
            }

            showingImportConfirmation = true
        } catch {
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func importProfiles() async {
        for profile in profilesToImport {
            // Add to configuration service
            viewModel.profiles.append(profile)
        }

        alertMessage = "Successfully imported \(profilesToImport.count) profile(s)"
        showingAlert = true
        profilesToImport.removeAll()

        // Refresh the list
        await viewModel.loadProfiles()
    }
}

struct ProfileSelectionRow: View {
    let profile: ConfigurationProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    HStack {
                        Label(profile.platformType.displayName, systemImage: profile.platformType.icon)
                        Text("•")
                        Label(profile.profileType.displayName, systemImage: profile.profileType.icon)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if let assignmentCount = profile.assignments?.count, assignmentCount > 0 {
                    Label("\(assignmentCount)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Document Type

struct ProfileExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data?

    init(data: Data?) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = data else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}