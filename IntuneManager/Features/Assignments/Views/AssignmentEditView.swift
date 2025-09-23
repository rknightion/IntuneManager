import SwiftUI
import Combine

extension Notification.Name {
    static let assignmentsDidChange = Notification.Name("assignmentsDidChange")
}

struct AssignmentEditView: View {
    let applications: [Application]
    @StateObject private var viewModel = AssignmentEditViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var assignmentToDelete: AppAssignment?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Edit Assignments")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(applications.count == 1 ?
                             applications[0].displayName :
                             "\(applications.count) applications selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Button("Save Changes") {
                            Task {
                                await viewModel.saveChanges()
                                // Always dismiss after save to avoid stale context issues
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.hasChanges || viewModel.isSaving)
                    }
                }
                .padding()

                if viewModel.isLoading {
                    ProgressView("Loading assignments...")
                        .padding(.horizontal)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            if !viewModel.isLoading {
                ScrollView {
                    VStack(spacing: 16) {
                        // Current Assignments Section
                        if !viewModel.currentAssignments.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Current Assignments", systemImage: "person.2.square.stack")
                                        .font(.headline)

                                    Spacer()

                                    Text("\(viewModel.currentAssignments.count) assignments")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                ForEach(viewModel.currentAssignments) { assignment in
                                    CurrentAssignmentRow(
                                        assignment: assignment,
                                        onDelete: {
                                            assignmentToDelete = assignment
                                            showingDeleteConfirmation = true
                                        },
                                        onEditIntent: { newIntent in
                                            viewModel.updateAssignmentIntent(assignment, intent: newIntent)
                                        }
                                    )
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }

                        // Add New Assignments Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Add New Assignments", systemImage: "plus.circle")
                                    .font(.headline)

                                Spacer()

                                Button("Add Groups") {
                                    viewModel.showingGroupSelector = true
                                }
                                .buttonStyle(.bordered)
                            }

                            if !viewModel.pendingAssignments.isEmpty {
                                ForEach(viewModel.pendingAssignments) { pending in
                                    PendingAssignmentRow(
                                        assignment: pending,
                                        onRemove: {
                                            viewModel.removePendingAssignment(pending)
                                        },
                                        onEditIntent: { newIntent in
                                            viewModel.updatePendingIntent(pending, intent: newIntent)
                                        }
                                    )
                                }
                            } else {
                                Text("No new assignments added")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                        // Summary
                        if viewModel.hasChanges {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Changes Summary", systemImage: "doc.badge.ellipsis")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 4) {
                                    if viewModel.assignmentsToDelete.count > 0 {
                                        Label("\(viewModel.assignmentsToDelete.count) assignments to remove",
                                              systemImage: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    if viewModel.assignmentsToUpdate.count > 0 {
                                        Label("\(viewModel.assignmentsToUpdate.count) assignments to update",
                                              systemImage: "arrow.triangle.2.circlepath")
                                            .foregroundColor(.orange)
                                    }
                                    if viewModel.pendingAssignments.count > 0 {
                                        Label("\(viewModel.pendingAssignments.count) assignments to add",
                                              systemImage: "plus.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .font(.caption)
                            }
                            .padding()
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            viewModel.loadAssignments(for: applications)
        }
        .sheet(isPresented: $viewModel.showingGroupSelector) {
            GroupSelectorSheet(
                selectedGroups: $viewModel.selectedGroupsForNewAssignment,
                existingGroups: viewModel.currentAssignmentGroups
            )
        }
        .alert("Remove Assignment?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let assignment = assignmentToDelete {
                    viewModel.markAssignmentForDeletion(assignment)
                }
            }
        } message: {
            if let assignment = assignmentToDelete {
                Text("Remove assignment to \(assignment.target.groupName ?? "this group")?")
            }
        }
    }
}

struct CurrentAssignmentRow: View {
    let assignment: AppAssignment
    let onDelete: () -> Void
    let onEditIntent: (AppAssignment.AssignmentIntent) -> Void
    @State private var selectedIntent: AppAssignment.AssignmentIntent

    init(assignment: AppAssignment, onDelete: @escaping () -> Void, onEditIntent: @escaping (AppAssignment.AssignmentIntent) -> Void) {
        self.assignment = assignment
        self.onDelete = onDelete
        self.onEditIntent = onEditIntent
        self._selectedIntent = State(initialValue: assignment.intent)
    }

    var body: some View {
        HStack {
            Image(systemName: "person.2.fill")
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.target.groupName ?? assignment.target.type.displayName)
                    .fontWeight(.medium)

                HStack {
                    Text(assignment.target.type.displayName)
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

            Picker("Intent", selection: $selectedIntent) {
                ForEach(AppAssignment.AssignmentIntent.allCases, id: \.self) { intent in
                    Label(intent.displayName, systemImage: intent.icon)
                        .tag(intent)
                        .help(intent.detailedDescription)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            .help("Assignment intent determines how the app will be deployed to devices")
            .onChange(of: selectedIntent) { _, newValue in
                onEditIntent(newValue)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

struct PendingAssignmentRow: View {
    let assignment: PendingAssignment
    let onRemove: () -> Void
    let onEditIntent: (AppAssignment.AssignmentIntent) -> Void

    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.group.displayName)
                    .fontWeight(.medium)

                Text("New assignment")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("Intent", selection: .constant(assignment.intent)) {
                ForEach(AppAssignment.AssignmentIntent.allCases, id: \.self) { intent in
                    Label(intent.displayName, systemImage: intent.icon)
                        .tag(intent)
                        .help(intent.detailedDescription)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            .onChange(of: assignment.intent) { _, newValue in
                onEditIntent(newValue)
            }
            .help("Assignment intent determines how the app will be deployed to devices")

            Button(action: onRemove) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.green.opacity(0.05))
        .cornerRadius(6)
    }
}

struct GroupSelectorSheet: View {
    @Binding var selectedGroups: Set<DeviceGroup>
    let existingGroups: Set<DeviceGroup>
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupService = GroupService.shared
    @State private var searchText = ""

    var availableGroups: [DeviceGroup] {
        let allGroups = DeviceGroup.builtInAssignmentTargets + groupService.groups
        return allGroups.filter { group in
            !existingGroups.contains(group) &&
            (searchText.isEmpty || group.displayName.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Groups to Assign")
                    .font(.headline)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Add Selected") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedGroups.isEmpty)
            }
            .padding()

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search groups...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(availableGroups) { group in
                        HStack {
                            Image(systemName: selectedGroups.contains(group) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedGroups.contains(group) ? .accentColor : .secondary)

                            VStack(alignment: .leading) {
                                Text(group.displayName)
                                if let description = group.groupDescription {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()
                        }
                        .padding(8)
                        .background(selectedGroups.contains(group) ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                        .cornerRadius(6)
                        .onTapGesture {
                            if selectedGroups.contains(group) {
                                selectedGroups.remove(group)
                            } else {
                                selectedGroups.insert(group)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .task {
            if groupService.groups.isEmpty {
                try? await groupService.fetchGroups()
            }
        }
    }
}

@MainActor
class AssignmentEditViewModel: ObservableObject {
    @Published var currentAssignments: [AppAssignment] = []
    @Published var pendingAssignments: [PendingAssignment] = []
    @Published var assignmentsToDelete: Set<String> = []
    @Published var assignmentsToUpdate: [String: AppAssignment.AssignmentIntent] = [:]
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var showingGroupSelector = false
    @Published var selectedGroupsForNewAssignment: Set<DeviceGroup> = []

    private let assignmentService = AssignmentService.shared
    private let apiClient = GraphAPIClient.shared
    // Store just the app IDs to avoid SwiftData context issues
    private var applicationIds: [String] = []
    private var applicationData: [(id: String, displayName: String)] = []

    var hasChanges: Bool {
        !assignmentsToDelete.isEmpty ||
        !assignmentsToUpdate.isEmpty ||
        !pendingAssignments.isEmpty
    }

    var currentAssignmentGroups: Set<DeviceGroup> {
        Set(currentAssignments.compactMap { assignment in
            if let groupId = assignment.target.groupId,
               let groupName = assignment.target.groupName {
                return DeviceGroup(
                    id: groupId,
                    displayName: groupName
                )
            }
            return nil
        })
    }

    func loadAssignments(for applications: [Application]) {
        // Store IDs and data upfront to avoid SwiftData context issues
        self.applicationIds = applications.map { $0.id }
        self.applicationData = applications.map { (id: $0.id, displayName: $0.displayName) }
        isLoading = true

        Task {
            defer { isLoading = false }

            // Copy all assignment data upfront before any context changes
            var allAssignments: [AppAssignment] = []
            for app in applications {
                // Safely access assignments and copy the data
                if let assignments = app.assignments {
                    // Force evaluation of the lazy relationship now
                    let assignmentsCopy = assignments.map { $0 }
                    allAssignments.append(contentsOf: assignmentsCopy)
                }
            }

            currentAssignments = allAssignments.sorted {
                ($0.target.groupName ?? "") < ($1.target.groupName ?? "")
            }
        }
    }

    func markAssignmentForDeletion(_ assignment: AppAssignment) {
        assignmentsToDelete.insert(assignment.id)
    }

    func updateAssignmentIntent(_ assignment: AppAssignment, intent: AppAssignment.AssignmentIntent) {
        if intent != assignment.intent {
            assignmentsToUpdate[assignment.id] = intent
        } else {
            assignmentsToUpdate.removeValue(forKey: assignment.id)
        }
    }

    func removePendingAssignment(_ assignment: PendingAssignment) {
        pendingAssignments.removeAll { $0.id == assignment.id }
    }

    func updatePendingIntent(_ assignment: PendingAssignment, intent: AppAssignment.AssignmentIntent) {
        if let index = pendingAssignments.firstIndex(where: { $0.id == assignment.id }) {
            pendingAssignments[index].intent = intent
        }
    }

    func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        // Work with IDs only to avoid SwiftData context issues
        for appId in applicationIds {
            // Delete assignments marked for deletion
            for assignmentId in assignmentsToDelete {
                if let assignment = currentAssignments.first(where: { $0.id == assignmentId }) {
                    do {
                        try await deleteAssignment(assignment, fromAppId: appId)
                    } catch {
                        Logger.shared.error("Failed to delete assignment: \(error)")
                    }
                }
            }

            // Update assignments with changed intents
            for (assignmentId, newIntent) in assignmentsToUpdate {
                if let assignment = currentAssignments.first(where: { $0.id == assignmentId }) {
                    do {
                        try await updateAssignment(assignment, newIntent: newIntent, forAppId: appId)
                    } catch {
                        Logger.shared.error("Failed to update assignment: \(error)")
                    }
                }
            }

            // Create new assignments
            for pending in pendingAssignments {
                do {
                    try await createAssignment(pending, forAppId: appId)
                } catch {
                    Logger.shared.error("Failed to create assignment: \(error)")
                }
            }
        }

        // Post notification that assignments have changed so other views can refresh if needed
        NotificationCenter.default.post(name: .assignmentsDidChange, object: nil)
    }

    private func deleteAssignment(_ assignment: AppAssignment, fromAppId appId: String) async throws {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments/\(assignment.id)"
        try await apiClient.delete(endpoint)
    }

    private func updateAssignment(_ assignment: AppAssignment, newIntent: AppAssignment.AssignmentIntent, forAppId appId: String) async throws {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments/\(assignment.id)"

        struct UpdateRequest: Encodable {
            let intent: String
            let target: TargetRequest

            enum CodingKeys: String, CodingKey {
                case intent
                case target
            }

            struct TargetRequest: Encodable {
                let type: String
                let groupId: String?

                enum CodingKeys: String, CodingKey {
                    case type = "@odata.type"
                    case groupId
                }
            }
        }

        let updateRequest = UpdateRequest(
            intent: newIntent.rawValue,
            target: UpdateRequest.TargetRequest(
                type: assignment.target.type.rawValue,
                groupId: assignment.target.groupId
            )
        )

        let _: EmptyResponse = try await apiClient.patchModel(endpoint, body: updateRequest)
    }

    private func createAssignment(_ pending: PendingAssignment, forAppId appId: String) async throws {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments"

        struct CreateRequest: Encodable {
            let intent: String
            let target: TargetRequest

            struct TargetRequest: Encodable {
                let type: String
                let groupId: String

                enum CodingKeys: String, CodingKey {
                    case type = "@odata.type"
                    case groupId
                }
            }
        }

        let createRequest = CreateRequest(
            intent: pending.intent.rawValue,
            target: CreateRequest.TargetRequest(
                type: AppAssignment.AssignmentTarget.TargetType.group.rawValue,
                groupId: pending.group.id
            )
        )

        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: createRequest)
    }
}

struct PendingAssignment: Identifiable {
    let id = UUID()
    let group: DeviceGroup
    var intent: AppAssignment.AssignmentIntent
}