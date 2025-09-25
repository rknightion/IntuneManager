import SwiftUI
import UniformTypeIdentifiers
import Combine

struct AssignmentBackupRestoreView: View {
    @StateObject private var viewModel = AssignmentBackupViewModel()
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportData: Data?
    @State private var selectedApplications = Set<String>()
    @State private var selectedGroups = Set<String>()
    @State private var showingImportConfirmation = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Backup Section
                    backupSection

                    Divider()

                    // Restore Section
                    restoreSection

                    // Validation Results
                    if let validation = viewModel.importValidation {
                        validationResultsSection(validation)
                    }
                }
                .padding()
            }
            .navigationTitle("Backup & Restore Assignments")
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
                document: AssignmentExportDocument(data: exportData),
                contentType: .json,
                defaultFilename: viewModel.generateFilename()
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
            .alert("Restore Assignments", isPresented: $showingImportConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Restore") {
                    Task {
                        await restoreAssignments()
                    }
                }
            } message: {
                if let validation = viewModel.importValidation {
                    Text("Restore \(validation.summary.importableAssignments) assignments? This will create new assignments without affecting existing ones.")
                }
            }
            .alert("Backup & Restore", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    var backupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Backup Assignments", systemImage: "square.and.arrow.up")
                .font(.headline)

            Text("Export app assignments for backup or migration")
                .font(.caption)
                .foregroundColor(.secondary)

            // Application Selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Applications (\(selectedApplications.count))")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Button(selectedApplications.count == viewModel.applications.count ? "Clear All" : "Select All") {
                        if selectedApplications.count == viewModel.applications.count {
                            selectedApplications.removeAll()
                        } else {
                            selectedApplications = Set(viewModel.applications.map { $0.id })
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.applications) { app in
                            ApplicationSelectionRow(
                                application: app,
                                isSelected: selectedApplications.contains(app.id)
                            ) {
                                if selectedApplications.contains(app.id) {
                                    selectedApplications.remove(app.id)
                                } else {
                                    selectedApplications.insert(app.id)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 200)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }

            // Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected: \(selectedApplications.count) apps")
                        .font(.caption)
                    Text("Total assignments: \(viewModel.getTotalAssignments(for: selectedApplications))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: exportAssignments) {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedApplications.isEmpty)
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var restoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Restore Assignments", systemImage: "square.and.arrow.down")
                .font(.headline)

            Text("Import assignments from a backup file")
                .font(.caption)
                .foregroundColor(.secondary)

            // Drop Zone
            VStack {
                Image(systemName: "doc.badge.arrow.up.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Drop backup file here or click to browse")
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
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    func validationResultsSection(_ validation: AssignmentImportService.ImportValidation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Import Validation", systemImage: validation.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(validation.isValid ? .green : .orange)

            // Summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Assignments:")
                    Spacer()
                    Text("\(validation.summary.totalAssignments)")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Importable:")
                    Spacer()
                    Text("\(validation.summary.importableAssignments)")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }

                if validation.summary.conflicts > 0 {
                    HStack {
                        Text("Conflicts:")
                        Spacer()
                        Text("\(validation.summary.conflicts)")
                            .foregroundColor(.orange)
                    }
                }

                if validation.summary.duplicates > 0 {
                    HStack {
                        Text("Duplicates:")
                        Spacer()
                        Text("\(validation.summary.duplicates)")
                            .foregroundColor(.yellow)
                    }
                }
            }
            .font(.caption)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            // Errors and Warnings
            if !validation.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors:")
                        .font(.caption)
                        .fontWeight(.medium)

                    ForEach(validation.errors, id: \.message) { error in
                        HStack(alignment: .top) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text(error.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if !validation.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warnings:")
                        .font(.caption)
                        .fontWeight(.medium)

                    ForEach(validation.warnings, id: \.message) { warning in
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text(warning.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Action Buttons
            HStack {
                Button("Cancel") {
                    viewModel.importValidation = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: { showingImportConfirmation = true }) {
                    Label("Restore \(validation.summary.importableAssignments) Assignments", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(validation.summary.importableAssignments == 0)
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    func exportAssignments() {
        do {
            exportData = try AssignmentExportService.shared.exportAssignments(
                applications: viewModel.applications.filter { selectedApplications.contains($0.id) }
            )
            showingExporter = true
        } catch {
            alertMessage = "Failed to export assignments: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let count = viewModel.getTotalAssignments(for: selectedApplications)
            alertMessage = "Successfully exported \(count) assignments to \(url.lastPathComponent)"
            showingAlert = true
            selectedApplications.removeAll()
        case .failure(let error):
            alertMessage = "Export failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importFromURL(url)
            }
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

            Task {
                await self.processImportData(data)
            }
        }
    }

    func importFromURL(_ url: URL) async {
        do {
            let data = try Data(contentsOf: url)
            await processImportData(data)
        } catch {
            alertMessage = "Failed to read file: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func processImportData(_ data: Data) async {
        do {
            let validation = try await AssignmentImportService.shared.validateImport(data: data)
            await MainActor.run {
                viewModel.importValidation = validation
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to validate import: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }

    func restoreAssignments() async {
        guard let validation = viewModel.importValidation else { return }

        do {
            let result = try await AssignmentImportService.shared.executeImport(validation: validation)

            await MainActor.run {
                alertMessage = "Successfully restored \(result.successCount) assignments"
                if result.failedCount > 0 {
                    alertMessage += " (\(result.failedCount) failed)"
                }
                showingAlert = true
                viewModel.importValidation = nil

                // Reload data
                Task {
                    await viewModel.loadData()
                }
            }
        } catch {
            await MainActor.run {
                alertMessage = "Restore failed: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

struct ApplicationSelectionRow: View {
    let application: Application
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(application.displayName)
                        .font(.caption)
                        .foregroundColor(.primary)

                    Text("\(application.assignments?.count ?? 0) assignments")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model

@MainActor
final class AssignmentBackupViewModel: ObservableObject {
    @Published var applications: [Application] = []
    @Published var groups: [DeviceGroup] = []
    @Published var importValidation: AssignmentImportService.ImportValidation?
    @Published var isLoading = false

    private let applicationService = ApplicationService.shared
    private let groupService = GroupService.shared

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        applications = applicationService.applications.filter { !($0.assignments?.isEmpty ?? true) }
        groups = groupService.groups
    }

    func getTotalAssignments(for applicationIds: Set<String>) -> Int {
        applications
            .filter { applicationIds.contains($0.id) }
            .compactMap { $0.assignments?.count }
            .reduce(0, +)
    }

    func generateFilename() -> String {
        AssignmentExportService.shared.generateExportFilename()
    }
}

// MARK: - Document Type

struct AssignmentExportDocument: FileDocument {
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