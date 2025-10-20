import SwiftUI

struct BulkImportSystemAppsView: View {
    @ObservedObject var viewModel: AddApplicationViewModel
    let onComplete: () -> Void

    @State private var packageIds: [String] = []
    @State private var newPackageId = ""
    @State private var isProcessing = false
    @State private var progress: ImportProgress?
    @State private var showingResults = false
    @State private var results: ImportResults?
    @State private var showingBulkPaste = false
    @State private var bulkPasteText = ""
    @State private var editingIndex: Int?

    struct ImportProgress {
        var current: Int
        var total: Int
        var currentPackageId: String
    }

    struct ImportResults {
        var successful: [String]
        var failed: [(packageId: String, error: String)]

        var successCount: Int { successful.count }
        var failureCount: Int { failed.count }
        var totalCount: Int { successCount + failureCount }
    }

    var isFormValid: Bool {
        !packageIds.isEmpty && !isProcessing
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    // Add new package ID row
                    HStack(spacing: 8) {
                        TextField("Package ID", text: $newPackageId, prompt: Text("com.example.app"))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit {
                                addPackageId()
                            }

                        Button(action: addPackageId) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .disabled(newPackageId.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
                    }

                    // Bulk paste button
                    Button(action: { showingBulkPaste = true }) {
                        Label("Paste Multiple Package IDs", systemImage: "doc.on.clipboard")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isProcessing)
                }
            } header: {
                Text("Add Package IDs")
                    .font(.headline)
            } footer: {
                Text("Enter package IDs one at a time or paste multiple at once. Format: com.example.app")
                    .font(.caption)
            }

            if !packageIds.isEmpty {
                Section {
                    ForEach(Array(packageIds.enumerated()), id: \.offset) { index, packageId in
                        HStack {
                            if editingIndex == index {
                            TextField("Package ID", text: Binding(
                                get: { packageIds[index] },
                                set: { packageIds[index] = $0 }
                            ))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))

                                Button("Done") {
                                    editingIndex = nil
                                }
                                .buttonStyle(.borderless)
                            } else {
                                Text(packageId)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(validatePackageIdFormat(packageId) ? .primary : .red)

                                Spacer()

                                if !validatePackageIdFormat(packageId) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .help("Invalid package ID format")
                                }

                                Button(action: { editingIndex = index }) {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .disabled(isProcessing)

                                Button(action: { removePackageId(at: index) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                                .disabled(isProcessing)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Package IDs (\(packageIds.count))")
                            .font(.headline)
                        Spacer()
                        Button(action: { packageIds.removeAll() }) {
                            Text("Clear All")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isProcessing)
                    }
                }
            }

            if let progress = progress {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ProgressView(value: Double(progress.current), total: Double(progress.total))
                            Text("\(progress.current) / \(progress.total)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("Creating: \(progress.currentPackageId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Progress")
                        .font(.headline)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Bulk Import System Apps", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundColor(.blue)

                    Text("Each package ID will be used as the app name, publisher, and package name. Apps will be created as Android Enterprise System Apps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Bulk Import System Apps")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onComplete()
                }
                .disabled(isProcessing)
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Import") {
                    importApps()
                }
                .disabled(!isFormValid)
            }
        }
        .alert("Import Results", isPresented: $showingResults) {
            Button("OK") {
                if let results = results, results.failureCount == 0 {
                    onComplete()
                }
            }
        } message: {
            if let results = results {
                Text(resultsMessage(results))
            }
        }
        .sheet(isPresented: $showingBulkPaste) {
            bulkPasteSheet
        }
    }

    private var bulkPasteSheet: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Paste multiple package IDs:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Use TextEditor for proper multi-line input
                        TextEditor(text: $bulkPasteText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150, maxHeight: 300)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .background(
                                // Show placeholder when empty
                                Group {
                                    if bulkPasteText.isEmpty {
                                        VStack(alignment: .leading) {
                                            Text("com.example.app1\ncom.example.app2\ncom.example.app3\n...")
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundColor(.gray.opacity(0.4))
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 4)
                                            Spacer()
                                        }
                                    }
                                }
                            )

                        // Preview of detected IDs
                        if !bulkPasteText.isEmpty {
                            let detectedIds = bulkPasteText
                                .split(separator: "\n")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }

                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("\(detectedIds.count) package ID(s) detected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                } header: {
                    Text("Paste Package IDs")
                        .font(.headline)
                } footer: {
                    Text("Paste one package ID per line. Existing package IDs will be preserved. Empty lines will be ignored.")
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Bulk Paste")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingBulkPaste = false
                        bulkPasteText = ""
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        processBulkPaste()
                    }
                    .disabled(bulkPasteText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 450)
    }

    private func validatePackageIdFormat(_ packageId: String) -> Bool {
        viewModel.validatePackageId(packageId) == nil
    }

    private func addPackageId() {
        let trimmed = newPackageId.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Check for duplicates
        guard !packageIds.contains(trimmed) else {
            newPackageId = ""
            return
        }

        packageIds.append(trimmed)
        newPackageId = ""
    }

    private func removePackageId(at index: Int) {
        packageIds.remove(at: index)
        if editingIndex == index {
            editingIndex = nil
        }
    }

    private func processBulkPaste() {
        let newIds = bulkPasteText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !packageIds.contains($0) }

        packageIds.append(contentsOf: newIds)
        showingBulkPaste = false
        bulkPasteText = ""
    }

    private func resultsMessage(_ results: ImportResults) -> String {
        var message = "Successfully created \(results.successCount) of \(results.totalCount) app(s)."

        if results.failureCount > 0 {
            message += "\n\nFailed:\n"
            message += results.failed.map { "• \($0.packageId): \($0.error)" }.joined(separator: "\n")
        }

        return message
    }

    private func importApps() {
        isProcessing = true
        results = nil

        Task {
            var successful: [String] = []
            var failed: [(String, String)] = []
            let total = packageIds.count

            for (index, packageId) in packageIds.enumerated() {
                // Update progress
                await MainActor.run {
                    progress = ImportProgress(
                        current: index + 1,
                        total: total,
                        currentPackageId: packageId
                    )
                }

                do {
                    // Validate package ID format first
                    if let error = viewModel.validatePackageId(packageId) {
                        failed.append((packageId, error))
                        continue
                    }

                    // Create the app using package ID for all fields
                    _ = try await viewModel.createAndroidEnterpriseSystemApp(
                        displayName: packageId,
                        publisher: packageId,
                        packageId: packageId
                    )
                    successful.append(packageId)

                    // Small delay to avoid rate limiting
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                } catch {
                    let errorMsg = viewModel.errorMessage(from: error)
                    failed.append((packageId, errorMsg))
                }
            }

            // Show results
            await MainActor.run {
                isProcessing = false
                progress = nil
                results = ImportResults(successful: successful, failed: failed)
                showingResults = true
            }
        }
    }
}
