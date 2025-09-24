import SwiftUI

struct CopyAssignmentsSheet: View {
    @Binding var isPresented: Bool
    let targetApplications: [Application]
    let onCopyAssignments: ([CopyableAssignment]) -> Void

    @State private var selectedSourceApp: Application?
    @State private var selectedAssignments: Set<String> = []
    @State private var copyIntent = true
    @State private var copySettings = true
    @State private var searchText = ""
    @State private var isLoadingAssignments = false
    @State private var sourceAssignments: [AppAssignment] = []
    @StateObject private var appService = ApplicationService.shared

    var availableSourceApps: [Application] {
        // Filter out the target apps and only show apps with assignments
        let targetIds = Set(targetApplications.map { $0.id })
        return appService.applications
            .filter { !targetIds.contains($0.id) && $0.hasAssignments }
            .sorted { $0.displayName < $1.displayName }
    }

    var filteredAssignments: [AppAssignment] {
        if searchText.isEmpty {
            return sourceAssignments
        }
        return sourceAssignments.filter { assignment in
            assignment.target.groupName?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    var selectedCount: Int {
        selectedAssignments.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Copy Assignments from App")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Select an app to copy assignments from")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)

                        Button("Copy Selected") {
                            copySelectedAssignments()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedAssignments.isEmpty)
                    }
                }
                .padding()
            }
            .background(Theme.Colors.secondaryBackground)

            Divider()

            // Content
            HStack(alignment: .top, spacing: 0) {
                // Left side - App selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source Application")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)

                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(availableSourceApps) { app in
                                AppSelectorRow(
                                    app: app,
                                    isSelected: selectedSourceApp?.id == app.id,
                                    onSelect: {
                                        selectSourceApp(app)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .frame(width: 300)
                .background(Color.gray.opacity(0.05))

                Divider()

                // Right side - Assignments list
                VStack(spacing: 0) {
                    if selectedSourceApp != nil {
                        // Options bar
                        VStack(spacing: 12) {
                            HStack {
                                Text("Assignments to Copy")
                                    .font(.headline)

                                Spacer()

                                if selectedCount > 0 {
                                    Text("\(selectedCount) selected")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }

                            // Search
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search groups...", text: $searchText)
                                    .textFieldStyle(.plain)
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)

                            // Copy options
                            HStack {
                                Toggle(isOn: $copyIntent) {
                                    Label("Copy Intent", systemImage: "flag")
                                        .font(.caption)
                                }
                                #if os(macOS)
                                .toggleStyle(.checkbox)
                                #endif

                                Toggle(isOn: $copySettings) {
                                    Label("Copy Settings", systemImage: "gearshape")
                                        .font(.caption)
                                }
                                #if os(macOS)
                                .toggleStyle(.checkbox)
                                #endif

                                Spacer()

                                Button("Select All") {
                                    selectedAssignments = Set(filteredAssignments.map { $0.id })
                                }
                                .buttonStyle(.bordered)
                                .disabled(filteredAssignments.isEmpty)

                                Button("Clear") {
                                    selectedAssignments.removeAll()
                                }
                                .buttonStyle(.bordered)
                                .disabled(selectedAssignments.isEmpty)
                            }
                        }
                        .padding()

                        Divider()

                        // Assignments list
                        if isLoadingAssignments {
                            ProgressView("Loading assignments...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if sourceAssignments.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No assignments found")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 6) {
                                    ForEach(filteredAssignments) { assignment in
                                        CopyableAssignmentRow(
                                            assignment: assignment,
                                            isSelected: selectedAssignments.contains(assignment.id),
                                            onToggle: {
                                                toggleAssignment(assignment)
                                            }
                                        )
                                    }
                                }
                                .padding()
                            }
                        }
                    } else {
                        // No app selected
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.left.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Select an application")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Choose an app from the list to view its assignments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 250)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            // Footer summary
            if !selectedAssignments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    HStack {
                        Label("Summary", systemImage: "doc.text")
                            .font(.headline)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(selectedAssignments.count) assignments will be copied")
                                .font(.caption)

                            if targetApplications.count > 1 {
                                Text("to \(targetApplications.count) applications")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("Total: \(selectedAssignments.count * targetApplications.count) new assignments")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color.yellow.opacity(0.1))
            }
        }
        .frame(width: 900, height: 600)
        .task {
            if appService.applications.isEmpty {
                do {
                    _ = try await appService.fetchApplications()
                } catch {
                    Logger.shared.error("Failed to load applications: \(error)")
                }
            }
        }
    }

    private func selectSourceApp(_ app: Application) {
        selectedSourceApp = app
        selectedAssignments.removeAll()
        searchText = ""

        // Extract assignments synchronously to avoid SwiftData context issues
        let assignmentsCopy: [AppAssignment]
        if let assignments = app.assignments {
            // Create an immediate copy of assignments array
            assignmentsCopy = Array(assignments).sorted {
                ($0.target.groupName ?? "") < ($1.target.groupName ?? "")
            }
        } else {
            assignmentsCopy = []
        }

        isLoadingAssignments = true

        Task {
            defer { isLoadingAssignments = false }
            // Use the extracted copy instead of accessing the app's assignments
            sourceAssignments = assignmentsCopy
        }
    }

    private func toggleAssignment(_ assignment: AppAssignment) {
        if selectedAssignments.contains(assignment.id) {
            selectedAssignments.remove(assignment.id)
        } else {
            selectedAssignments.insert(assignment.id)
        }
    }

    private func copySelectedAssignments() {
        let assignmentsToCopy = sourceAssignments
            .filter { selectedAssignments.contains($0.id) }
            .map { assignment in
                CopyableAssignment(
                    assignment: assignment,
                    copyIntent: copyIntent,
                    copySettings: copySettings
                )
            }

        onCopyAssignments(assignmentsToCopy)
        isPresented = false
    }
}

struct AppSelectorRow: View {
    let app: Application
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .fontWeight(isSelected ? .medium : .regular)
                    .lineLimit(1)

                HStack {
                    Label(app.appType.displayName, systemImage: app.appType.icon)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if app.hasAssignments {
                        Text("• \(app.assignmentCount) assignments")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

struct CopyableAssignmentRow: View {
    let assignment: AppAssignment
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: 16))

            Image(systemName: "person.2.fill")
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.target.groupName ?? assignment.target.type.displayName)
                    .fontWeight(.medium)

                HStack {
                    Label(assignment.intent.displayName, systemImage: assignment.intent.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let groupId = assignment.target.groupId {
                        Text("• \(groupId.prefix(8))...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Show current intent
            HStack(spacing: 4) {
                Image(systemName: assignment.intent.icon)
                    .font(.caption)
                Text(assignment.intent.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(intentColor(for: assignment.intent).opacity(0.1))
            .foregroundColor(intentColor(for: assignment.intent))
            .cornerRadius(4)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }

    func intentColor(for intent: AppAssignment.AssignmentIntent) -> Color {
        switch intent {
        case .required:
            return .red
        case .available:
            return .blue
        case .uninstall:
            return .orange
        case .availableWithoutEnrollment:
            return .purple
        }
    }
}

struct CopyableAssignment {
    let assignment: AppAssignment
    let copyIntent: Bool
    let copySettings: Bool
}