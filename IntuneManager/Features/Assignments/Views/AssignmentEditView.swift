import SwiftUI
import Combine

extension Notification.Name {
    static let assignmentsDidChange = Notification.Name("assignmentsDidChange")
}

struct AssignmentEditView: View {
    let applications: [Application]
    @StateObject private var viewModel = AssignmentEditViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveConfirmation = false
    @State private var showingBulkIntentMenu = false
    @State private var selectedBulkIntent: AppAssignment.AssignmentIntent = .required
    @State private var assignmentSearchText = ""
    @State private var expandedApps: Set<String> = []
    @State private var showingCopyAssignments = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var defaultIntentForNewGroups: AppAssignment.AssignmentIntent = .required
    @State private var useDefaultIntent = true

    var filteredAssignments: [AssignmentWithApp] {
        if assignmentSearchText.isEmpty {
            return viewModel.currentAssignmentsWithApp
        }
        return viewModel.currentAssignmentsWithApp.filter { item in
            item.appName.localizedCaseInsensitiveContains(assignmentSearchText) ||
            (item.assignment.target.groupName?.localizedCaseInsensitiveContains(assignmentSearchText) ?? false)
        }
    }

    var assignmentsByApp: [String: [AssignmentWithApp]] {
        Dictionary(grouping: filteredAssignments) { $0.appName }
    }

    var bulkActionsBar: some View {
        HStack {
            if !viewModel.selectedAssignments.isEmpty {
                Text("\(viewModel.selectedAssignments.count) selected")
                    .font(.caption)
                    .foregroundColor(.accentColor)

                Button("Change Intent") {
                    showingBulkIntentMenu = true
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $showingBulkIntentMenu) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set Intent for Selected")
                            .font(.headline)
                            .padding(.bottom, 4)

                        ForEach(AppAssignment.AssignmentIntent.allCases, id: \.self) { intent in
                            Button(action: {
                                viewModel.bulkUpdateIntent(intent)
                                showingBulkIntentMenu = false
                            }) {
                                Label(intent.displayName, systemImage: intent.icon)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                    }
                    .padding()
                    .frame(width: 200)
                }

                Button("Delete Selected") {
                    viewModel.bulkDelete()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }

            Spacer()

            // Quick actions
            if applications.count > 1 {
                Button(action: {
                    if expandedApps.count == applications.count {
                        expandedApps.removeAll()
                    } else {
                        expandedApps = Set(applications.map { $0.displayName })
                    }
                }) {
                    Label(expandedApps.isEmpty ? "Expand All" : "Collapse All",
                          systemImage: expandedApps.isEmpty ? "chevron.down.square" : "chevron.up.square")
                }
                .buttonStyle(.bordered)
            }

            if viewModel.currentAssignmentsWithApp.count > 0 {
                Button("Delete All") {
                    viewModel.markAllAssignmentsForDeletion()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
    }

    var currentAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with search and actions
            VStack(spacing: 12) {
                HStack {
                    Label("Current Assignments", systemImage: "person.2.square.stack")
                        .font(.headline)

                    Spacer()

                    Text("\(filteredAssignments.count) of \(viewModel.currentAssignmentsWithApp.count) shown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search groups or apps...", text: $assignmentSearchText)
                        .textFieldStyle(.plain)
                    if !assignmentSearchText.isEmpty {
                        Button(action: { assignmentSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)

                // Bulk actions bar
                bulkActionsBar
            }

            // Assignments list
            if applications.count > 1 {
                // Group by app for multiple apps
                ForEach(assignmentsByApp.keys.sorted(), id: \.self) { appName in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedApps.contains(appName) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedApps.insert(appName)
                                } else {
                                    expandedApps.remove(appName)
                                }
                            }
                        )
                    ) {
                        ForEach(assignmentsByApp[appName] ?? []) { item in
                            CurrentAssignmentRow(
                                assignmentWithApp: item,
                                appType: applications.first(where: { $0.id == item.appId })?.appType ?? .unknown,
                                isPendingDeletion: viewModel.isMarkedForDeletion(item),
                                isPendingUpdate: viewModel.hasPendingUpdate(item),
                                isSelected: viewModel.selectedAssignments.contains(item.id),
                                showAppName: false,
                                onToggleSelection: {
                                    viewModel.toggleSelection(item)
                                },
                                onToggleDelete: {
                                    viewModel.toggleAssignmentDeletion(item)
                                },
                                onEditIntent: { newIntent in
                                    viewModel.updateAssignmentIntent(item, intent: newIntent)
                                }
                            )
                        }
                    } label: {
                        HStack {
                            Label(appName, systemImage: "app.badge")
                                .font(.system(.body, weight: .medium))
                            Spacer()
                            Text("\(assignmentsByApp[appName]?.count ?? 0) assignments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                // Flat list for single app
                ForEach(filteredAssignments) { item in
                    CurrentAssignmentRow(
                        assignmentWithApp: item,
                        appType: applications.first(where: { $0.id == item.appId })?.appType ?? .unknown,
                        isPendingDeletion: viewModel.isMarkedForDeletion(item),
                        isPendingUpdate: viewModel.hasPendingUpdate(item),
                        isSelected: viewModel.selectedAssignments.contains(item.id),
                        showAppName: false,
                        onToggleSelection: {
                            viewModel.toggleSelection(item)
                        },
                        onToggleDelete: {
                            viewModel.toggleAssignmentDeletion(item)
                        },
                        onEditIntent: { newIntent in
                            viewModel.updateAssignmentIntent(item, intent: newIntent)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(8)
    }

    @ViewBuilder
    var conflictWarningsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            conflictHeader
            conflictsList
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var conflictHeader: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Assignment Conflicts Detected")
                .font(.headline)
                .foregroundColor(.orange)

            Spacer()

            Text("\(viewModel.assignmentConflicts.count) conflict(s)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var conflictsList: some View {
        ForEach(viewModel.assignmentConflicts) { conflict in
            conflictRow(for: conflict)
        }
    }

    @ViewBuilder
    private func conflictRow(for conflict: AssignmentConflictDetector.AssignmentConflict) -> some View {
        HStack(alignment: .top) {
            conflictIcon(for: conflict)
            conflictDetails(for: conflict)
            Spacer()
        }
        .padding(8)
        .background(Color(conflict.severity.color).opacity(0.1))
        .cornerRadius(6)
    }

    private func conflictIcon(for conflict: AssignmentConflictDetector.AssignmentConflict) -> some View {
        Image(systemName: conflict.conflictType.icon)
            .foregroundColor(Color(conflict.severity.color))
            .frame(width: 20)
    }

    @ViewBuilder
    private func conflictDetails(for conflict: AssignmentConflictDetector.AssignmentConflict) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conflict.groupName)
                    .fontWeight(.medium)
                Text("(\(conflict.conflictType.displayName))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(conflict.assignments, id: \.applicationName) { assignment in
                conflictAssignmentRow(assignment)
            }

            Text(conflict.resolution)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }

    private func conflictAssignmentRow(_ assignment: AssignmentConflictDetector.AssignmentConflict.ConflictingAssignment) -> some View {
        HStack {
            Text("• \(assignment.applicationName):")
                .font(.caption)
            Label(assignment.intent.displayName, systemImage: assignment.intent.icon)
                .font(.caption)
                .foregroundColor(assignment.intent == .required ? .green : .orange)
            if assignment.isExisting {
                Text("(existing)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("(new)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }

    var newAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Add New Assignments", systemImage: "plus.circle")
                    .font(.headline)

                Spacer()

                Button("Copy from App") {
                    showingCopyAssignments = true
                }
                .buttonStyle(.bordered)

                Button("Add Groups") {
                    viewModel.showingGroupSelector = true
                }
                .buttonStyle(.bordered)
            }

            // Default intent selector for batch operations
            if !viewModel.pendingAssignments.isEmpty {
                HStack {
                    Toggle("Use default intent for all", isOn: $useDefaultIntent)
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #endif
                        .help("Apply the same intent to all new assignments")

                    if useDefaultIntent {
                        Picker("Default Intent", selection: $defaultIntentForNewGroups) {
                            ForEach(AppAssignment.AssignmentIntent.allCases, id: \.self) { intent in
                                Label(intent.displayName, systemImage: intent.icon)
                                    .tag(intent)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .onChange(of: defaultIntentForNewGroups) { _, newIntent in
                            // Apply to all pending assignments
                            if useDefaultIntent {
                                viewModel.applyIntentToAllPending(newIntent)
                            }
                        }

                        Button("Apply to All") {
                            viewModel.applyIntentToAllPending(defaultIntentForNewGroups)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.accentColor.opacity(0.05))
                .cornerRadius(6)
            }

            if !viewModel.pendingAssignments.isEmpty {
                ForEach(viewModel.pendingAssignments) { pending in
                    PendingAssignmentRow(
                        assignment: pending,
                        applicationNames: viewModel.applicationNames,
                        applicationTypes: applications.map { $0.appType },
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
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(8)
    }

    var headerView: some View {
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
                        showingSaveConfirmation = true
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
        .background(Theme.Colors.secondaryBackground)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            if !viewModel.isLoading {
                ScrollView {
                    VStack(spacing: 16) {
                        // Conflict Warnings Section
                        if !viewModel.assignmentConflicts.isEmpty {
                            conflictWarningsSection
                        }

                        // Current Assignments Section
                        if !viewModel.currentAssignmentsWithApp.isEmpty {
                            currentAssignmentsSection
                        }

                        // Add New Assignments Section
                        newAssignmentsSection

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
                                        Label("\(viewModel.pendingAssignments.count * applications.count) assignments to add",
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
            // Start with all apps expanded for better UX
            if applications.count > 1 {
                expandedApps = Set(applications.map { $0.displayName })
            }
        }
        .sheet(isPresented: $viewModel.showingGroupSelector) {
            GroupSelectorSheet(
                selectedGroups: $viewModel.selectedGroupsForNewAssignment,
                existingGroups: viewModel.currentAssignmentGroups,
                defaultIntent: useDefaultIntent ? defaultIntentForNewGroups : .required,
                onAddGroups: { intent in
                    viewModel.addPendingAssignments(withIntent: intent)
                }
            )
        }
        .alert("Confirm Changes", isPresented: $showingSaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Save Changes", role: .destructive) {
                Task {
                    let errorSummary = await viewModel.saveChanges()
                    if let error = errorSummary {
                        errorMessage = error
                        showingErrorAlert = true
                        // Reload assignments even on error to show current state
                        await viewModel.loadAssignments(for: applications)
                    } else {
                        dismiss()
                    }
                }
            }
        } message: {
            Text(viewModel.confirmationMessage)
        }
        .alert("Assignment Errors", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
            if errorMessage.contains("CRITICAL") {
                Button("Open Intune", role: .none) {
                    if let url = URL(string: "https://intune.microsoft.com") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
            }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingCopyAssignments) {
            CopyAssignmentsSheet(
                isPresented: $showingCopyAssignments,
                targetApplications: applications,
                onCopyAssignments: { copyableAssignments in
                    viewModel.addCopiedAssignments(copyableAssignments)
                }
            )
        }
    }
}

struct CurrentAssignmentRow: View {
    let assignmentWithApp: AssignmentWithApp
    let appType: Application.AppType
    let isPendingDeletion: Bool
    let isPendingUpdate: Bool
    let isSelected: Bool
    let showAppName: Bool
    let onToggleSelection: () -> Void
    let onToggleDelete: () -> Void
    let onEditIntent: (AppAssignment.AssignmentIntent) -> Void
    @State private var selectedIntent: AppAssignment.AssignmentIntent
    @State private var showingInvalidIntentWarning = false

    init(assignmentWithApp: AssignmentWithApp,
         appType: Application.AppType,
         isPendingDeletion: Bool,
         isPendingUpdate: Bool,
         isSelected: Bool = false,
         showAppName: Bool = true,
         onToggleSelection: @escaping () -> Void = {},
         onToggleDelete: @escaping () -> Void,
         onEditIntent: @escaping (AppAssignment.AssignmentIntent) -> Void) {
        self.assignmentWithApp = assignmentWithApp
        self.appType = appType
        self.isPendingDeletion = isPendingDeletion
        self.isPendingUpdate = isPendingUpdate
        self.isSelected = isSelected
        self.showAppName = showAppName
        self.onToggleSelection = onToggleSelection
        self.onToggleDelete = onToggleDelete
        self.onEditIntent = onEditIntent
        self._selectedIntent = State(initialValue: assignmentWithApp.assignment.intent)
    }

    // Get valid intents for this app type and target
    var validIntents: [AppAssignment.AssignmentIntent] {
        let targetType = assignmentWithApp.assignment.target.type
        return AssignmentIntentValidator.validIntents(for: appType, targetType: targetType)
    }

    var backgroundColor: Color {
        if isPendingDeletion {
            return Color.red.opacity(0.1)
        } else if isPendingUpdate {
            return Color.yellow.opacity(0.1)
        } else if isSelected {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color.gray.opacity(0.05)
        }
    }

    var body: some View {
        HStack {
            // Selection checkbox
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture {
                    onToggleSelection()
                }

            Image(systemName: "person.2.fill")
                .foregroundColor(isPendingDeletion ? .red : .accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignmentWithApp.assignment.target.groupName ?? assignmentWithApp.assignment.target.type.displayName)
                    .fontWeight(.medium)
                    .strikethrough(isPendingDeletion)
                    .foregroundColor(isPendingDeletion ? .secondary : .primary)

                HStack {
                    Text(assignmentWithApp.assignment.target.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if showAppName {
                        Text("• \(assignmentWithApp.appName)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if let groupId = assignmentWithApp.assignment.target.groupId {
                        Text("• \(groupId.prefix(8))...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Text("Intent")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("", selection: $selectedIntent) {
                ForEach(validIntents, id: \.self) { intent in
                    Label(intent.displayName, systemImage: intent.icon)
                        .tag(intent)
                        .help(intent.detailedDescription)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .disabled(isPendingDeletion || validIntents.isEmpty)
            .help(validIntents.isEmpty ? "No valid intents available for this app type and target" : "Assignment intent determines how the app will be deployed to devices")
            .onChange(of: selectedIntent) { _, newValue in
                if validIntents.contains(newValue) {
                    onEditIntent(newValue)
                } else {
                    // Reset to a valid intent if current selection is invalid
                    if let firstValid = validIntents.first {
                        selectedIntent = firstValid
                        onEditIntent(firstValid)
                    }
                }
            }
            .onAppear {
                // Validate current intent on appear and adjust if needed
                if !validIntents.contains(selectedIntent) {
                    if let firstValid = validIntents.first {
                        selectedIntent = firstValid
                        // Don't trigger onEditIntent here to avoid marking unchanged assignments as updated
                    }
                }
            }

            Button(action: onToggleDelete) {
                Image(systemName: isPendingDeletion ? "arrow.uturn.backward" : "trash")
                    .foregroundColor(isPendingDeletion ? .orange : .red)
            }
            .buttonStyle(.plain)
            .help(isPendingDeletion ? "Undo deletion" : "Mark for deletion")
        }
        .padding(8)
        .background(backgroundColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isPendingDeletion ? Color.red.opacity(0.3) :
                       isPendingUpdate ? Color.yellow.opacity(0.3) :
                       isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct PendingAssignmentRow: View {
    let assignment: PendingAssignment
    let applicationNames: [String]
    let applicationTypes: [Application.AppType]
    let onRemove: () -> Void
    let onEditIntent: (AppAssignment.AssignmentIntent) -> Void
    @State private var selectedIntent: AppAssignment.AssignmentIntent
    @State private var showingInvalidIntentAlert = false
    @State private var invalidIntentMessage = ""

    init(assignment: PendingAssignment,
         applicationNames: [String],
         applicationTypes: [Application.AppType],
         onRemove: @escaping () -> Void,
         onEditIntent: @escaping (AppAssignment.AssignmentIntent) -> Void) {
        self.assignment = assignment
        self.applicationNames = applicationNames
        self.applicationTypes = applicationTypes
        self.onRemove = onRemove
        self.onEditIntent = onEditIntent
        self._selectedIntent = State(initialValue: assignment.intent)
    }

    // Get valid intents for this combination of app types and target
    var validIntents: [AppAssignment.AssignmentIntent] {
        let targetType = assignment.group.assignmentTargetType

        // Find the most restrictive set of intents across all app types
        var commonIntents = Set(AppAssignment.AssignmentIntent.allCases)

        for appType in applicationTypes {
            let validForApp = AssignmentIntentValidator.validIntents(for: appType, targetType: targetType)
            commonIntents = commonIntents.intersection(validForApp)
        }

        return Array(commonIntents).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        HStack {
            Image(systemName: assignment.isCopied ? "doc.on.doc.fill" : "plus.circle.fill")
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.group.displayName)
                    .fontWeight(.medium)

                HStack {
                    if assignment.isCopied {
                        Label("Copied", systemImage: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.orange)
                        if assignment.copySettings {
                            Text("• with settings")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    } else {
                        Text("New assignment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if applicationNames.count > 1 {
                        Text("• \(applicationNames.count) apps")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else if let appName = applicationNames.first {
                        Text("• \(appName)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Text("Intent")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("", selection: $selectedIntent) {
                ForEach(validIntents, id: \.self) { intent in
                    Label(intent.displayName, systemImage: intent.icon)
                        .tag(intent)
                        .help(intent.detailedDescription)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .onChange(of: selectedIntent) { _, newValue in
                // Double-check the intent is valid before applying
                if validIntents.contains(newValue) {
                    onEditIntent(newValue)
                } else {
                    // Show error if somehow an invalid intent was selected
                    if let firstAppType = applicationTypes.first {
                        invalidIntentMessage = AssignmentIntentValidator.validationMessage(
                            for: newValue,
                            appType: firstAppType,
                            targetType: assignment.group.assignmentTargetType
                        ) ?? "This intent is not supported for the selected apps and target"
                        showingInvalidIntentAlert = true
                    }
                    // Reset to a valid intent
                    if let firstValid = validIntents.first {
                        selectedIntent = firstValid
                        onEditIntent(firstValid)
                    }
                }
            }
            .help("Assignment intent determines how the app will be deployed to devices")
            .disabled(validIntents.isEmpty)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.green.opacity(0.05))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .alert("Invalid Assignment Intent", isPresented: $showingInvalidIntentAlert) {
            Button("OK") { }
        } message: {
            Text(invalidIntentMessage)
        }
        .onAppear {
            // Validate current intent on appear and adjust if needed
            if !validIntents.contains(selectedIntent) {
                if let suggested = AssignmentIntentValidator.suggestedIntents(
                    for: applicationTypes.first ?? .unknown,
                    targetType: assignment.group.assignmentTargetType,
                    preferredIntent: selectedIntent
                ).first {
                    selectedIntent = suggested
                    onEditIntent(suggested)
                }
            }
        }
    }
}

struct GroupSelectorSheet: View {
    @Binding var selectedGroups: Set<DeviceGroup>
    let existingGroups: Set<DeviceGroup>
    let defaultIntent: AppAssignment.AssignmentIntent
    let onAddGroups: (AppAssignment.AssignmentIntent) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupService = GroupService.shared
    @State private var searchText = ""
    @State private var selectedIntent: AppAssignment.AssignmentIntent = .required

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
                    onAddGroups(selectedIntent)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedGroups.isEmpty)
            }
            .padding()

            Divider()

            // Intent selector for new groups
            HStack {
                Label("Assignment Intent", systemImage: "arrow.triangle.branch")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedIntent) {
                    ForEach(AppAssignment.AssignmentIntent.allCases, id: \.self) { intent in
                        Label(intent.displayName, systemImage: intent.icon)
                            .tag(intent)
                    }
                }
                .pickerStyle(.segmented)
                .help("Select the intent for all selected groups")

                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.05))

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
        .onAppear {
            selectedIntent = defaultIntent
        }
        .task {
            if groupService.groups.isEmpty {
                _ = try? await groupService.fetchGroups()
            }
        }
    }
}

// MARK: - View Model

struct AssignmentWithApp: Identifiable {
    let id: String
    let assignment: AppAssignment
    let appId: String
    let appName: String
}

struct PendingAssignment: Identifiable {
    let id = UUID()
    let group: DeviceGroup
    var intent: AppAssignment.AssignmentIntent
    var copySettings: Bool = false
    var sourceAssignmentId: String? = nil

    var isCopied: Bool {
        sourceAssignmentId != nil
    }
}

@MainActor
class AssignmentEditViewModel: ObservableObject {
    // IMPORTANT: All assignment tracking is session-only. Assignment IDs come from Intune's API
    // and are only used temporarily during editing. Intune is always the source of truth.
    // Composite keys (appId_assignmentId) allow independent editing of the same group across different apps.
    @Published var currentAssignmentsWithApp: [AssignmentWithApp] = []
    @Published var pendingAssignments: [PendingAssignment] = []
    // Use composite keys (appId_assignmentId) for app-specific tracking during this edit session
    @Published var assignmentsToDelete: Set<String> = []
    @Published var assignmentsToUpdate: [String: AppAssignment.AssignmentIntent] = [:]
    @Published var selectedAssignments: Set<String> = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var showingGroupSelector = false
    @Published var selectedGroupsForNewAssignment: Set<DeviceGroup> = []
    @Published var assignmentConflicts: [AssignmentConflictDetector.AssignmentConflict] = []

    private let assignmentService = AssignmentService.shared
    private let apiClient = GraphAPIClient.shared
    private var applicationIds: [String] = []
    private var applicationData: [(id: String, displayName: String, appType: Application.AppType)] = []

    var applicationNames: [String] {
        applicationData.map { $0.displayName }
    }

    var hasChanges: Bool {
        !assignmentsToDelete.isEmpty ||
        !assignmentsToUpdate.isEmpty ||
        !pendingAssignments.isEmpty
    }

    // Helper to create composite key for tracking
    private func compositeKey(appId: String, assignmentId: String) -> String {
        "\(appId)_\(assignmentId)"
    }

    var confirmationMessage: String {
        var messages: [String] = []

        // Count actual deletions (composite keys already include app-specific info)
        if assignmentsToDelete.count > 0 {
            messages.append("\(assignmentsToDelete.count) assignment(s) will be removed")
        }

        // Count actual updates (composite keys already include app-specific info)
        if assignmentsToUpdate.count > 0 {
            messages.append("\(assignmentsToUpdate.count) assignment(s) will be updated")
        }

        if pendingAssignments.count > 0 {
            let totalNew = pendingAssignments.count * applicationIds.count
            messages.append("\(totalNew) new assignment(s) will be created")
        }

        if messages.isEmpty {
            return "No changes to save"
        }

        return messages.joined(separator: "\n") + "\n\nThis action cannot be undone."
    }

    var currentAssignmentGroups: Set<DeviceGroup> {
        Set(currentAssignmentsWithApp.compactMap { item in
            if let groupId = item.assignment.target.groupId,
               let groupName = item.assignment.target.groupName {
                return DeviceGroup(
                    id: groupId,
                    displayName: groupName
                )
            }
            return nil
        })
    }

    func loadAssignments(for applications: [Application]) {
        // Extract all data synchronously before any async operations to avoid SwiftData context issues
        var appData: [(id: String, displayName: String, appType: Application.AppType, assignments: [AppAssignment])] = []

        for app in applications {
            // Force immediate evaluation of the lazy assignments relationship
            let assignmentsCopy: [AppAssignment]
            if let assignments = app.assignments {
                // Create a copy of assignments array to avoid lazy loading issues
                assignmentsCopy = Array(assignments)
            } else {
                assignmentsCopy = []
            }

            appData.append((
                id: app.id,
                displayName: app.displayName,
                appType: app.appType,
                assignments: assignmentsCopy
            ))
        }

        // Store extracted data
        self.applicationIds = appData.map { $0.id }
        self.applicationData = appData.map { (id: $0.id, displayName: $0.displayName, appType: $0.appType) }

        isLoading = true

        Task {
            defer { isLoading = false }

            var allAssignmentsWithApp: [AssignmentWithApp] = []

            // Work only with the extracted data, not the original Application objects
            for data in appData {
                let assignmentsCopy = data.assignments.map { assignment in
                    AssignmentWithApp(
                        id: "\(data.id)_\(assignment.id)",
                        assignment: assignment,
                        appId: data.id,
                        appName: data.displayName
                    )
                }
                allAssignmentsWithApp.append(contentsOf: assignmentsCopy)
            }

            currentAssignmentsWithApp = allAssignmentsWithApp.sorted {
                if $0.appName != $1.appName {
                    return $0.appName < $1.appName
                }
                return ($0.assignment.target.groupName ?? "") < ($1.assignment.target.groupName ?? "")
            }

            // Detect conflicts after loading
            detectConflicts()
        }
    }

    // Helper methods to check status using composite keys
    func isMarkedForDeletion(_ item: AssignmentWithApp) -> Bool {
        let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
        return assignmentsToDelete.contains(key)
    }

    func hasPendingUpdate(_ item: AssignmentWithApp) -> Bool {
        let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
        return assignmentsToUpdate[key] != nil
    }

    func toggleSelection(_ item: AssignmentWithApp) {
        if selectedAssignments.contains(item.id) {
            selectedAssignments.remove(item.id)
        } else {
            selectedAssignments.insert(item.id)
        }
    }

    func bulkUpdateIntent(_ intent: AppAssignment.AssignmentIntent) {
        for itemId in selectedAssignments {
            if let item = currentAssignmentsWithApp.first(where: { $0.id == itemId }) {
                let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
                // Skip if marked for deletion
                if !assignmentsToDelete.contains(key) {
                    if intent != item.assignment.intent {
                        assignmentsToUpdate[key] = intent
                    } else {
                        assignmentsToUpdate.removeValue(forKey: key)
                    }
                }
            }
        }
        // Clear selection after bulk action
        selectedAssignments.removeAll()
    }

    func bulkDelete() {
        for itemId in selectedAssignments {
            if let item = currentAssignmentsWithApp.first(where: { $0.id == itemId }) {
                let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
                assignmentsToDelete.insert(key)
                assignmentsToUpdate.removeValue(forKey: key)
            }
        }
        // Clear selection after bulk action
        selectedAssignments.removeAll()
    }

    func toggleAssignmentDeletion(_ item: AssignmentWithApp) {
        let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
        if assignmentsToDelete.contains(key) {
            assignmentsToDelete.remove(key)
        } else {
            assignmentsToDelete.insert(key)
            // If marking for deletion, remove any pending updates
            assignmentsToUpdate.removeValue(forKey: key)
        }
        detectConflicts()
    }

    func markAllAssignmentsForDeletion() {
        for item in currentAssignmentsWithApp {
            let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
            assignmentsToDelete.insert(key)
            assignmentsToUpdate.removeValue(forKey: key)
        }
        // Clear selection when doing a bulk delete all
        selectedAssignments.removeAll()
        detectConflicts()
    }

    func updateAssignmentIntent(_ item: AssignmentWithApp, intent: AppAssignment.AssignmentIntent) {
        let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
        // Don't allow updates on items marked for deletion
        if assignmentsToDelete.contains(key) {
            return
        }

        if intent != item.assignment.intent {
            assignmentsToUpdate[key] = intent
        } else {
            assignmentsToUpdate.removeValue(forKey: key)
        }
        detectConflicts()
    }

    func removePendingAssignment(_ assignment: PendingAssignment) {
        pendingAssignments.removeAll { $0.id == assignment.id }
        detectConflicts()
    }

    func updatePendingIntent(_ assignment: PendingAssignment, intent: AppAssignment.AssignmentIntent) {
        if let index = pendingAssignments.firstIndex(where: { $0.id == assignment.id }) {
            pendingAssignments[index].intent = intent
        }
        detectConflicts()
    }

    func addPendingAssignments(withIntent intent: AppAssignment.AssignmentIntent = .required) {
        for group in selectedGroupsForNewAssignment {
            // Check if this group already has an assignment (not deleted) for any app
            let hasExisting = currentAssignmentsWithApp.contains { item in
                if item.assignment.target.groupId != group.id {
                    return false
                }
                let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
                return !assignmentsToDelete.contains(key)
            }

            // Check if already in pending
            let hasPending = pendingAssignments.contains { $0.group.id == group.id }

            if !hasExisting && !hasPending {
                pendingAssignments.append(PendingAssignment(
                    group: group,
                    intent: intent
                ))
            }
        }
        selectedGroupsForNewAssignment.removeAll()
        detectConflicts()
    }

    func applyIntentToAllPending(_ intent: AppAssignment.AssignmentIntent) {
        for index in pendingAssignments.indices {
            pendingAssignments[index].intent = intent
        }
        detectConflicts()
    }

    func detectConflicts() {
        assignmentConflicts = AssignmentConflictDetector.detectConflicts(
            currentAssignments: currentAssignmentsWithApp,
            pendingAssignments: pendingAssignments,
            deletedAssignmentKeys: assignmentsToDelete,
            applicationNames: applicationNames
        )
    }

    func addCopiedAssignments(_ copyableAssignments: [CopyableAssignment]) {
        for copyable in copyableAssignments {
            let assignment = copyable.assignment

            // Create a DeviceGroup from the assignment target
            guard let groupId = assignment.target.groupId,
                  let groupName = assignment.target.groupName else {
                continue
            }

            let group = DeviceGroup(
                id: groupId,
                displayName: groupName
            )

            // Check if this group already has an assignment (not deleted) for any app
            let hasExisting = currentAssignmentsWithApp.contains { item in
                if item.assignment.target.groupId != groupId {
                    return false
                }
                let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
                return !assignmentsToDelete.contains(key)
            }

            // Check if already in pending
            let hasPending = pendingAssignments.contains { $0.group.id == groupId }

            if !hasExisting && !hasPending {
                let intent = copyable.copyIntent ? assignment.intent : .required
                pendingAssignments.append(PendingAssignment(
                    group: group,
                    intent: intent,
                    copySettings: copyable.copySettings,
                    sourceAssignmentId: assignment.id
                ))
            }
        }
    }

    func saveChanges() async -> String? {
        isSaving = true
        defer { isSaving = false }

        var deleteErrors: [(app: String, group: String, error: String)] = []
        var updateErrors: [(app: String, group: String, error: String, wasDeleted: Bool)] = []
        var createErrors: [(app: String, group: String, error: String)] = []

        // PHASE 1: Process all deletions first (including those for updates)
        var deletedForUpdate: [(item: AssignmentWithApp, newIntent: AppAssignment.AssignmentIntent)] = []

        for item in currentAssignmentsWithApp {
            let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
            let groupName = item.assignment.target.groupName ?? item.assignment.target.type.displayName

            if assignmentsToDelete.contains(key) {
                // Simple deletion
                do {
                    try await deleteAssignment(item.assignment, fromAppId: item.appId)
                    Logger.shared.info("Deleted assignment for \(item.appName) - \(groupName)")
                } catch {
                    deleteErrors.append((app: item.appName, group: groupName, error: error.localizedDescription))
                    Logger.shared.error("Failed to delete assignment for \(item.appName): \(error)")
                }
            } else if let newIntent = assignmentsToUpdate[key] {
                // Delete for update (will recreate later)
                do {
                    try await deleteAssignment(item.assignment, fromAppId: item.appId)
                    deletedForUpdate.append((item: item, newIntent: newIntent))
                    Logger.shared.info("Deleted assignment for update: \(item.appName) - \(groupName)")
                } catch {
                    updateErrors.append((
                        app: item.appName,
                        group: groupName,
                        error: error.localizedDescription,
                        wasDeleted: false
                    ))
                    Logger.shared.error("Failed to delete assignment for update in \(item.appName): \(error)")
                }
            }
        }

        // PHASE 2: Recreate assignments that were deleted for updates
        for (item, newIntent) in deletedForUpdate {
            let groupName = item.assignment.target.groupName ?? item.assignment.target.type.displayName

            do {
                // Create new assignment with updated intent
                // For built-in targets, use the special IDs
                let groupId: String
                let targetType: AppAssignment.AssignmentTarget.TargetType
                switch item.assignment.target.type {
                case .allDevices:
                    groupId = DeviceGroup.allDevicesGroupID
                    targetType = .allDevices
                case .allUsers:
                    groupId = DeviceGroup.allUsersGroupID
                    targetType = .allUsers
                case .group:
                    groupId = item.assignment.target.groupId ?? ""
                    targetType = .group
                default:
                    groupId = item.assignment.target.groupId ?? ""
                    targetType = item.assignment.target.type
                }

                // Find the app to get its type from our stored application data
                let appType = applicationData.first(where: { $0.id == item.appId })?.appType ?? .unknown

                // Validate the intent before trying to create the assignment
                var finalIntent = newIntent
                if !AssignmentIntentValidator.isIntentValid(intent: newIntent, appType: appType, targetType: targetType) {
                    // Get a valid alternative intent
                    let validIntents = AssignmentIntentValidator.validIntents(for: appType, targetType: targetType)
                    if let suggestedIntent = validIntents.first {
                        Logger.shared.warning("Intent '\(newIntent.rawValue)' is not valid for \(appType.displayName) apps with \(targetType.displayName) target. Using '\(suggestedIntent.rawValue)' instead.")
                        finalIntent = suggestedIntent
                    } else {
                        // No valid intents available - skip this assignment
                        Logger.shared.error("No valid intents available for \(appType.displayName) apps with \(targetType.displayName) target. Skipping assignment.")
                        updateErrors.append((
                            app: item.appName,
                            group: groupName,
                            error: "No valid assignment intents available for this app type and target combination",
                            wasDeleted: true
                        ))
                        continue
                    }
                }

                let pending = PendingAssignment(
                    group: DeviceGroup(
                        id: groupId,
                        displayName: groupName
                    ),
                    intent: finalIntent
                )
                try await createAssignment(pending, forAppId: item.appId)
                Logger.shared.info("Recreated assignment with intent '\(finalIntent.rawValue)' for \(item.appName) - \(groupName)")
            } catch {
                // This is critical - the assignment was deleted but couldn't be recreated
                updateErrors.append((
                    app: item.appName,
                    group: groupName,
                    error: "Assignment was deleted but recreation failed: \(error.localizedDescription)",
                    wasDeleted: true
                ))
                Logger.shared.error("CRITICAL: Failed to recreate assignment for \(item.appName) - \(groupName): \(error)")
            }
        }

        // PHASE 3: Create new assignments
        for appId in applicationIds {
            let appName = applicationData.first(where: { $0.id == appId })?.displayName ?? appId

            for pending in pendingAssignments {
                do {
                    try await createAssignment(pending, forAppId: appId)
                    Logger.shared.info("Created new assignment for \(appName) - \(pending.group.displayName)")
                } catch {
                    createErrors.append((
                        app: appName,
                        group: pending.group.displayName,
                        error: error.localizedDescription
                    ))
                    Logger.shared.error("Failed to create assignment for \(appName): \(error)")
                }
            }
        }

        // Report errors to user
        if !deleteErrors.isEmpty || !updateErrors.isEmpty || !createErrors.isEmpty {
            var errorSummary = "Assignment operation completed with errors:\n\n"

            if !deleteErrors.isEmpty {
                errorSummary += "❌ Failed Deletions:\n"
                for error in deleteErrors {
                    errorSummary += "• \(error.app) - \(error.group)\n"
                }
                errorSummary += "\n"
            }

            let criticalUpdates = updateErrors.filter { $0.wasDeleted }
            let failedUpdates = updateErrors.filter { !$0.wasDeleted }

            if !criticalUpdates.isEmpty {
                errorSummary += "⚠️ CRITICAL - Assignments in inconsistent state (deleted but not recreated):\n"
                for error in criticalUpdates {
                    errorSummary += "• \(error.app) - \(error.group)\n"
                }
                errorSummary += "Please manually check these assignments in Intune!\n\n"
            }

            if !failedUpdates.isEmpty {
                errorSummary += "❌ Failed Updates:\n"
                for error in failedUpdates {
                    errorSummary += "• \(error.app) - \(error.group)\n"
                }
                errorSummary += "\n"
            }

            if !createErrors.isEmpty {
                errorSummary += "❌ Failed Creations:\n"
                for error in createErrors {
                    errorSummary += "• \(error.app) - \(error.group)\n"
                }
            }

            Logger.shared.error(errorSummary)

            // Post notification for other views to refresh
            NotificationCenter.default.post(name: .assignmentsDidChange, object: nil)

            // Also explicitly refresh the applications to ensure assignments are updated (even on partial success)
            Task { @MainActor in
                do {
                    _ = try await ApplicationService.shared.fetchApplications(forceRefresh: true)
                    Logger.shared.info("Successfully refreshed applications after assignment changes (with errors)")
                } catch {
                    Logger.shared.error("Failed to refresh applications after assignment changes: \(error)")
                }
            }

            return errorSummary
        }

        // Post notification for other views to refresh
        NotificationCenter.default.post(name: .assignmentsDidChange, object: nil)

        // Also explicitly refresh the applications to ensure assignments are updated
        Task { @MainActor in
            do {
                _ = try await ApplicationService.shared.fetchApplications(forceRefresh: true)
                Logger.shared.info("Successfully refreshed applications after assignment changes")
            } catch {
                Logger.shared.error("Failed to refresh applications after assignment changes: \(error)")
            }
        }

        return nil
    }

    private func deleteAssignment(_ assignment: AppAssignment, fromAppId appId: String) async throws {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments/\(assignment.id)"
        try await apiClient.delete(endpoint)
    }


    private func createAssignment(_ pending: PendingAssignment, forAppId appId: String) async throws {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments"

        struct CreateRequest: Encodable {
            let intent: String
            let target: TargetRequest

            struct TargetRequest: Encodable {
                let type: String
                let groupId: String?

                enum CodingKeys: String, CodingKey {
                    case type = "@odata.type"
                    case groupId
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(type, forKey: .type)
                    // Only encode groupId if it's present and not a built-in target
                    if let groupId = groupId {
                        try container.encode(groupId, forKey: .groupId)
                    }
                }
            }
        }

        // Determine the target type based on the group
        let targetType = pending.group.assignmentTargetType

        let createRequest = CreateRequest(
            intent: pending.intent.rawValue,
            target: CreateRequest.TargetRequest(
                type: targetType.rawValue,
                // Only include groupId for regular groups, not built-in targets
                groupId: targetType.requiresGroupId ? pending.group.id : nil
            )
        )

        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: createRequest)
    }
}