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
    @State private var showingChangeAllIntentMenu = false
    @State private var selectedBulkIntent: AppAssignment.AssignmentIntent = .required
    @State private var assignmentSearchText = ""
    @State private var expandedApps: Set<String> = []
    @State private var showingCopyAssignments = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var defaultIntentForNewGroups: AppAssignment.AssignmentIntent = .required
    @State private var useDefaultIntent = true
    @State private var showingProgressView = false

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

    var sharedAssignmentGroups: [SharedAssignmentGroup] {
        struct Builder {
            var groupName: String
            var assignments: [AssignmentWithApp] = []
            var appIds: Set<String> = []
            var appNames: Set<String> = []
            var appTypes: Set<Application.AppType> = []
            var referenceFilterId: String?
            var referenceFilterMode: AssignmentFilterMode?
            var filterIsMixed = false
            var referenceInitialized = false
        }

        var groups: [SharedAssignmentKey: Builder] = [:]
        let appTypeLookup = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0.appType) })

        for item in filteredAssignments {
            if viewModel.isMarkedForDeletion(item) { continue }
            guard let groupId = item.assignment.target.groupId,
                  let groupName = item.assignment.target.groupName else { continue }

            let assignmentKey = viewModel.compositeKey(appId: item.appId, assignmentId: item.assignment.id)
            let effectiveIntent = viewModel.assignmentsToUpdate[assignmentKey] ?? item.assignment.intent

            let builderKey = SharedAssignmentKey(
                groupId: groupId,
                intent: effectiveIntent,
                targetType: item.assignment.target.type
            )

            var builder = groups[builderKey] ?? Builder(groupName: groupName)
            builder.assignments.append(item)
            builder.appIds.insert(item.appId)
            builder.appNames.insert(item.appName)
            let appType = appTypeLookup[item.appId] ?? .unknown
            builder.appTypes.insert(appType)

            let filterId = viewModel.effectiveFilterId(for: item)
            let filterMode = viewModel.effectiveFilterMode(for: item)

            if !builder.referenceInitialized {
                builder.referenceFilterId = filterId
                builder.referenceFilterMode = filterMode
                builder.referenceInitialized = true
            } else if !builder.filterIsMixed {
                switch (builder.referenceFilterId, filterId) {
                case (nil, nil):
                    break
                case (nil, .some), (.some, nil):
                    builder.filterIsMixed = true
                case let (.some(reference), .some(current)):
                    if reference != current {
                        builder.filterIsMixed = true
                    } else {
                        let refMode = builder.referenceFilterMode ?? .include
                        let currentMode = filterMode ?? .include
                        if refMode != currentMode {
                            builder.filterIsMixed = true
                        }
                    }
                }
            }

            groups[builderKey] = builder
        }

        let sharedGroups = groups.compactMap { entry -> SharedAssignmentGroup? in
            let (key, builder) = entry
            guard builder.assignments.count > 1 else { return nil }
            guard builder.appIds.count > 1 else { return nil }
            guard builder.appTypes.count == 1,
                  let appType = builder.appTypes.first,
                  appType != .unknown else { return nil }

            let filterId = builder.filterIsMixed ? nil : builder.referenceFilterId
            let filterMode = builder.filterIsMixed ? nil : builder.referenceFilterMode

            return SharedAssignmentGroup(
                key: key,
                groupName: builder.groupName,
                appType: appType,
                assignments: builder.assignments,
                appNames: builder.appNames.sorted(),
                filterId: filterId,
                filterMode: filterMode,
                filterIsMixed: builder.filterIsMixed
            )
        }

        return sharedGroups.sorted {
            $0.groupName.localizedCaseInsensitiveCompare($1.groupName) == .orderedAscending
        }
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
                Button("Change All Intents") {
                    showingChangeAllIntentMenu = true
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $showingChangeAllIntentMenu) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set Intent for All Assignments")
                            .font(.headline)
                            .padding(.bottom, 4)

                        ForEach(AppAssignment.AssignmentIntent.allCases, id: \.self) { intent in
                            Button(action: {
                                viewModel.changeAllIntents(to: intent)
                                showingChangeAllIntentMenu = false
                            }) {
                                Label(intent.displayName, systemImage: intent.icon)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                    }
                    .padding()
                    .frame(width: 250)
                }

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
            assignmentsHeader
            assignmentsList
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(8)
    }

    @ViewBuilder
    var assignmentsHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Current Assignments", systemImage: "person.2.square.stack")
                    .font(.headline)

                Spacer()

                Text("\(filteredAssignments.count) of \(viewModel.currentAssignmentsWithApp.count) shown")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            searchBar
            bulkActionsBar
        }
    }

    @ViewBuilder
    var searchBar: some View {
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
    }

    @ViewBuilder
    var assignmentsList: some View {
        let sharedGroups = sharedAssignmentGroups

        if !sharedGroups.isEmpty {
            sharedAssignmentsSection(for: sharedGroups)
        }

        if applications.count > 1 {
            groupedAssignmentsList
        } else {
            flatAssignmentsList
        }
    }

    @ViewBuilder
    func sharedAssignmentsSection(for groups: [SharedAssignmentGroup]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Shared Group Assignments", systemImage: "square.stack.3d.up.fill")
                    .font(.headline)
                Spacer()
                Text("\(groups.count) group(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("These groups are assigned to multiple apps with the same intent. Update the filter once to apply it everywhere.")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(groups) { group in
                SharedAssignmentGroupRow(
                    group: group,
                    onUpdateFilter: { filterId, mode in
                        viewModel.updateFilters(for: group.assignments, filterId: filterId, mode: mode)
                    }
                )

                if group.id != groups.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground.opacity(0.6))
        .cornerRadius(8)
    }

    @ViewBuilder
    var groupedAssignmentsList: some View {
        ForEach(assignmentsByApp.keys.sorted(), id: \.self) { appName in
            DisclosureGroup(
                isExpanded: expandedAppBinding(for: appName)
            ) {
                ForEach(assignmentsByApp[appName] ?? []) { item in
                    assignmentRow(for: item, showAppName: false)
                }
            } label: {
                appGroupLabel(for: appName)
            }
        }
    }

    @ViewBuilder
    var flatAssignmentsList: some View {
        ForEach(filteredAssignments) { item in
            assignmentRow(for: item, showAppName: false)
        }
    }

    func expandedAppBinding(for appName: String) -> Binding<Bool> {
        Binding(
            get: { expandedApps.contains(appName) },
            set: { isExpanded in
                if isExpanded {
                    expandedApps.insert(appName)
                } else {
                    expandedApps.remove(appName)
                }
            }
        )
    }

    @ViewBuilder
    func appGroupLabel(for appName: String) -> some View {
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

    @ViewBuilder
    func assignmentRow(for item: AssignmentWithApp, showAppName: Bool) -> some View {
        let appType = applications.first(where: { $0.id == item.appId })?.appType ?? .unknown
        let key = viewModel.compositeKey(appId: item.appId, assignmentId: item.assignment.id)
        let filterId = viewModel.effectiveFilterId(for: item)
        let filterMode = viewModel.effectiveFilterMode(for: item)

        CurrentAssignmentRow(
            assignmentWithApp: item,
            appType: appType,
            isPendingDeletion: viewModel.isMarkedForDeletion(item),
            isPendingUpdate: viewModel.hasPendingUpdate(item),
            pendingIntent: viewModel.assignmentsToUpdate[key],
            isSelected: viewModel.selectedAssignments.contains(item.id),
            showAppName: showAppName,
            filterId: filterId,
            filterMode: filterMode,
            onToggleSelection: {
                viewModel.toggleSelection(item)
            },
            onToggleDelete: {
                viewModel.toggleAssignmentDeletion(item)
            },
            onEditIntent: { newIntent in
                viewModel.updateAssignmentIntent(item, intent: newIntent)
            },
            onUpdateFilter: { newFilterId, newMode in
                viewModel.updateAssignmentFilter(item, filterId: newFilterId, mode: newMode)
            }
        )
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
                        },
                        onUpdateFilter: { newFilterId, newMode in
                            viewModel.updatePendingFilter(pending, filterId: newFilterId, mode: newMode)
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
        .overlay {
            if viewModel.isSaving, let progress = viewModel.saveProgress {
                SaveProgressView(progress: progress)
            }
        }
    }
}

// MARK: - Progress View
struct SaveProgressView: View {
    let progress: AssignmentEditViewModel.SaveProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)

                VStack(spacing: 8) {
                    Text(progress.phase)
                        .font(.headline)

                    Text(progress.currentOperation)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("\(progress.completedOperations + progress.failedOperations) of \(progress.totalOperations)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if progress.failedOperations > 0 {
                            Text("(\(progress.failedOperations) failed)")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }

                    ProgressView(value: progress.percentComplete, total: 100)
                        .frame(width: 250)
                }
            }
            .padding(30)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

struct CurrentAssignmentRow: View {
    let assignmentWithApp: AssignmentWithApp
    let appType: Application.AppType
    let isPendingDeletion: Bool
    let isPendingUpdate: Bool
    let pendingIntent: AppAssignment.AssignmentIntent?
    let isSelected: Bool
    let showAppName: Bool
    let filterId: String?
    let filterMode: AssignmentFilterMode?
    let onToggleSelection: () -> Void
    let onToggleDelete: () -> Void
    let onEditIntent: (AppAssignment.AssignmentIntent) -> Void
    let onUpdateFilter: (String?, AssignmentFilterMode?) -> Void
    @State private var selectedIntent: AppAssignment.AssignmentIntent
    @State private var showingInvalidIntentWarning = false
    @State private var currentFilterMode: AssignmentFilterMode
    @State private var showingFilterPicker = false
    @ObservedObject private var filterService = AssignmentFilterService.shared

    init(assignmentWithApp: AssignmentWithApp,
         appType: Application.AppType,
         isPendingDeletion: Bool,
         isPendingUpdate: Bool,
         pendingIntent: AppAssignment.AssignmentIntent? = nil,
         isSelected: Bool = false,
         showAppName: Bool = true,
         filterId: String? = nil,
         filterMode: AssignmentFilterMode? = nil,
         onToggleSelection: @escaping () -> Void = {},
         onToggleDelete: @escaping () -> Void,
         onEditIntent: @escaping (AppAssignment.AssignmentIntent) -> Void,
         onUpdateFilter: @escaping (String?, AssignmentFilterMode?) -> Void) {
        self.assignmentWithApp = assignmentWithApp
        self.appType = appType
        self.isPendingDeletion = isPendingDeletion
        self.isPendingUpdate = isPendingUpdate
        self.pendingIntent = pendingIntent
        self.isSelected = isSelected
        self.showAppName = showAppName
        self.filterId = filterId
        self.filterMode = filterMode
        self.onToggleSelection = onToggleSelection
        self.onToggleDelete = onToggleDelete
        self.onEditIntent = onEditIntent
        self.onUpdateFilter = onUpdateFilter
        // Use pending intent if available, otherwise use the original intent
        self._selectedIntent = State(initialValue: pendingIntent ?? assignmentWithApp.assignment.intent)
        self._currentFilterMode = State(initialValue: filterMode ?? .include)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 16))
                    .onTapGesture { onToggleSelection() }

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
                    } else if let firstValid = validIntents.first {
                        selectedIntent = firstValid
                        onEditIntent(firstValid)
                    }
                }
                .onAppear {
                    if !validIntents.contains(selectedIntent), let firstValid = validIntents.first {
                        selectedIntent = firstValid
                    }
                }

                Button(action: onToggleDelete) {
                    Image(systemName: isPendingDeletion ? "arrow.uturn.backward" : "trash")
                        .foregroundColor(isPendingDeletion ? .orange : .red)
                }
                .buttonStyle(.plain)
                .help(isPendingDeletion ? "Undo deletion" : "Mark for deletion")
            }

            if !isPendingDeletion {
                filterControls
            }
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
        .task { await filterService.fetchFilters() }
        .sheet(isPresented: $showingFilterPicker) {
            AssignmentFilterPickerView(
                appType: appType,
                selectedFilterId: filterId
            ) { filter in
                currentFilterMode = filterMode ?? currentFilterMode
                onUpdateFilter(filter.id, currentFilterMode)
            }
            .frame(minWidth: 360, minHeight: 420)
        }
        .onChange(of: pendingIntent) { newValue in
            if let newIntent = newValue {
                selectedIntent = newIntent
            }
        }
        .onChange(of: filterMode) { newValue in
            currentFilterMode = newValue ?? .include
        }
    }

    private var filterControls: some View {
        HStack(alignment: .center, spacing: 8) {
            Label("Filter", systemImage: "line.horizontal.3.decrease.circle")
                .font(.caption)
                .foregroundColor(.secondary)

            if let filterId = filterId, let filter = filterService.filter(withId: filterId) {
                Text(filter.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            } else if let filterId = filterId {
                Text(filterId)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(6)
            } else {
                Text("None")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if filterId != nil {
                Text("Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Filter mode", selection: Binding(
                    get: { currentFilterMode },
                    set: { newValue in
                        currentFilterMode = newValue
                        onUpdateFilter(filterId, newValue)
                    }
                )) {
                    Text("Include").tag(AssignmentFilterMode.include)
                    Text("Exclude").tag(AssignmentFilterMode.exclude)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: 160, idealWidth: 200)
                .accessibilityLabel("Filter mode")
            }

            Menu {
                Button("Select Filter…") {
                    showingFilterPicker = true
                }
                if filterId != nil {
                    Button("Clear Filter", role: .destructive) {
                        currentFilterMode = .include
                        onUpdateFilter(nil, nil)
                    }
                }
            } label: {
                Label("Manage", systemImage: "slider.horizontal.3")
                    .font(.caption)
            }
            .disabled(isPendingDeletion)
        }
        .padding(.horizontal, 4)
    }
}

struct PendingAssignmentRow: View {
    let assignment: PendingAssignment
    let applicationNames: [String]
    let applicationTypes: [Application.AppType]
    let onRemove: () -> Void
    let onEditIntent: (AppAssignment.AssignmentIntent) -> Void
    let onUpdateFilter: (String?, AssignmentFilterMode?) -> Void
    @State private var selectedIntent: AppAssignment.AssignmentIntent
    @State private var showingInvalidIntentAlert = false
    @State private var invalidIntentMessage = ""
    @State private var currentFilterMode: AssignmentFilterMode
    @State private var showingFilterPicker = false
    @ObservedObject private var filterService = AssignmentFilterService.shared

    init(assignment: PendingAssignment,
         applicationNames: [String],
         applicationTypes: [Application.AppType],
         onRemove: @escaping () -> Void,
         onEditIntent: @escaping (AppAssignment.AssignmentIntent) -> Void,
         onUpdateFilter: @escaping (String?, AssignmentFilterMode?) -> Void) {
        self.assignment = assignment
        self.applicationNames = applicationNames
        self.applicationTypes = applicationTypes
        self.onRemove = onRemove
        self.onEditIntent = onEditIntent
        self.onUpdateFilter = onUpdateFilter
        self._selectedIntent = State(initialValue: assignment.intent)
        self._currentFilterMode = State(initialValue: assignment.assignmentFilterMode ?? .include)
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
        VStack(alignment: .leading, spacing: 8) {
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
                .disabled(validIntents.isEmpty)
                .help("Assignment intent determines how the app will be deployed to devices")
                .onChange(of: selectedIntent) { _, newValue in
                    if validIntents.contains(newValue) {
                        onEditIntent(newValue)
                    } else if let firstAppType = applicationTypes.first {
                        invalidIntentMessage = AssignmentIntentValidator.validationMessage(
                            for: newValue,
                            appType: firstAppType,
                            targetType: assignment.group.assignmentTargetType
                        ) ?? "This intent is not supported for the selected apps and target"
                        showingInvalidIntentAlert = true
                        if let firstValid = validIntents.first {
                            selectedIntent = firstValid
                            onEditIntent(firstValid)
                        }
                    }
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            filterControls
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
        .task { await filterService.fetchFilters() }
        .sheet(isPresented: $showingFilterPicker) {
            AssignmentFilterPickerView(
                appType: applicationTypes.first ?? .unknown,
                selectedFilterId: assignment.assignmentFilterId
            ) { filter in
                onUpdateFilter(filter.id, currentFilterMode)
            }
            .frame(minWidth: 360, minHeight: 420)
        }
        .onAppear {
            if !validIntents.contains(selectedIntent),
               let suggested = AssignmentIntentValidator.suggestedIntents(
                    for: applicationTypes.first ?? .unknown,
                    targetType: assignment.group.assignmentTargetType,
                    preferredIntent: selectedIntent
               ).first {
                selectedIntent = suggested
                onEditIntent(suggested)
            }
        }
        .onChange(of: assignment.assignmentFilterMode) { newMode in
            currentFilterMode = newMode ?? .include
        }
    }

    private var filterControls: some View {
        HStack(spacing: 8) {
            Label("Filter", systemImage: "line.horizontal.3.decrease.circle")
                .font(.caption)
                .foregroundColor(.secondary)

            if let filterId = assignment.assignmentFilterId,
               let filter = filterService.filter(withId: filterId) {
                Text(filter.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            } else if let filterId = assignment.assignmentFilterId {
                Text(filterId)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(6)
            } else {
                Text("None")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if assignment.assignmentFilterId != nil {
                Text("Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Filter mode", selection: Binding(
                    get: { currentFilterMode },
                    set: { newValue in
                        currentFilterMode = newValue
                        onUpdateFilter(assignment.assignmentFilterId, newValue)
                    }
                )) {
                    Text("Include").tag(AssignmentFilterMode.include)
                    Text("Exclude").tag(AssignmentFilterMode.exclude)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: 160, idealWidth: 200)
                .accessibilityLabel("Filter mode")
            }

            Menu {
                Button("Select Filter…") {
                    showingFilterPicker = true
                }
                if assignment.assignmentFilterId != nil {
                    Button("Clear Filter", role: .destructive) {
                        currentFilterMode = .include
                        onUpdateFilter(nil, nil)
                    }
                }
            } label: {
                Label("Manage", systemImage: "slider.horizontal.3")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct SharedAssignmentGroupRow: View {
    let group: SharedAssignmentGroup
    let onUpdateFilter: (String?, AssignmentFilterMode?) -> Void

    @ObservedObject private var filterService = AssignmentFilterService.shared
    @State private var showingFilterPicker = false
    @State private var workingMode: AssignmentFilterMode

    init(group: SharedAssignmentGroup,
         onUpdateFilter: @escaping (String?, AssignmentFilterMode?) -> Void) {
        self.group = group
        self.onUpdateFilter = onUpdateFilter
        _workingMode = State(initialValue: group.filterMode ?? .include)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            appSummary
            filterControls
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showingFilterPicker) {
            AssignmentFilterPickerView(
                appType: group.appType,
                selectedFilterId: group.filterIsMixed ? nil : group.filterId
            ) { filter in
                if group.filterId == nil || group.filterIsMixed {
                    workingMode = .include
                }
                onUpdateFilter(filter.id, workingMode)
            }
            .frame(minWidth: 360, minHeight: 420)
        }
        .onChange(of: group.filterMode) { _, newMode in
            if let newMode {
                workingMode = newMode
            }
        }
        .onChange(of: group.filterId) { _, newId in
            if newId == nil {
                workingMode = .include
            }
        }
    }

    private var header: some View {
        HStack {
            Label(group.groupName, systemImage: "person.2")
                .font(.subheadline)

            Spacer()

            Label(group.intent.displayName, systemImage: group.intent.icon)
                .font(.subheadline)

            Text("\(group.assignments.count) apps")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var appSummary: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "app.badge")
                .foregroundColor(.secondary)
            Text(group.appNames.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var filterControls: some View {
        HStack(alignment: .center, spacing: 10) {
            Label("Filter", systemImage: "line.horizontal.3.decrease.circle")
                .font(.caption)
                .foregroundColor(.secondary)

            if group.filterIsMixed {
                Text("Mixed filters")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
            } else if let filterId = group.filterId {
                let displayName = filterService.filter(withId: filterId)?.displayName ?? filterId
                Text(displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            } else {
                Text("None")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !group.filterIsMixed, group.filterId != nil {
                Picker("Filter mode", selection: Binding(
                    get: { workingMode },
                    set: { newMode in
                        workingMode = newMode
                        onUpdateFilter(group.filterId, newMode)
                    }
                )) {
                    Text("Include").tag(AssignmentFilterMode.include)
                    Text("Exclude").tag(AssignmentFilterMode.exclude)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: 160, idealWidth: 200)
                .accessibilityLabel("Filter mode")
            }

            Menu {
                Button("Select Filter…") {
                    showingFilterPicker = true
                }
                Button("Clear Filters", role: .destructive) {
                    workingMode = .include
                    onUpdateFilter(nil, nil)
                }
            } label: {
                Label("Manage", systemImage: "slider.horizontal.3")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 4)
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

struct SharedAssignmentKey: Hashable {
    let groupId: String
    let intent: AppAssignment.AssignmentIntent
    let targetType: AppAssignment.AssignmentTarget.TargetType
}

struct SharedAssignmentGroup: Identifiable {
    let key: SharedAssignmentKey
    let groupName: String
    let appType: Application.AppType
    let assignments: [AssignmentWithApp]
    let appNames: [String]
    let filterId: String?
    let filterMode: AssignmentFilterMode?
    let filterIsMixed: Bool

    var id: String {
        "\(key.groupId)_\(key.intent.rawValue)_\(key.targetType.rawValue)"
    }

    var intent: AppAssignment.AssignmentIntent {
        key.intent
    }

    var groupId: String {
        key.groupId
    }

    var targetType: AppAssignment.AssignmentTarget.TargetType {
        key.targetType
    }
}

struct PendingAssignment: Identifiable {
    let id = UUID()
    let group: DeviceGroup
    var intent: AppAssignment.AssignmentIntent
    var copySettings: Bool = false
    var sourceAssignmentId: String? = nil
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

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
    struct FilterOverride: Equatable {
        var filterId: String?
        var filterMode: AssignmentFilterMode?
    }
    @Published var assignmentFilterOverrides: [String: FilterOverride] = [:]
    @Published var selectedAssignments: Set<String> = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var showingGroupSelector = false
    @Published var selectedGroupsForNewAssignment: Set<DeviceGroup> = []
    @Published var assignmentConflicts: [AssignmentConflictDetector.AssignmentConflict] = []
    @Published var saveProgress: SaveProgress?

    private let assignmentService = AssignmentService.shared
    private let apiClient = GraphAPIClient.shared
    private var applicationIds: [String] = []
    private var applicationData: [(id: String, displayName: String, appType: Application.AppType)] = []
    private let maxBatchSize = 20  // Graph API batch limit

    // Helper to create composite key for tracking
    func compositeKey(appId: String, assignmentId: String) -> String {
        "\(appId)_\(assignmentId)"
    }

    struct SaveProgress {
        var phase: String
        var totalOperations: Int
        var completedOperations: Int
        var failedOperations: Int
        var currentOperation: String

        var percentComplete: Double {
            guard totalOperations > 0 else { return 0 }
            return Double(completedOperations + failedOperations) / Double(totalOperations) * 100
        }
    }

    var applicationNames: [String] {
        applicationData.map { $0.displayName }
    }

    var hasChanges: Bool {
        !assignmentsToDelete.isEmpty ||
        !assignmentsToUpdate.isEmpty ||
        !pendingAssignments.isEmpty ||
        !assignmentFilterOverrides.isEmpty
    }

    private var assignmentsRequiringRecreation: Set<String> {
        Set(assignmentsToUpdate.keys).union(assignmentFilterOverrides.keys)
    }


    var confirmationMessage: String {
        var messages: [String] = []

        // Count actual deletions (composite keys already include app-specific info)
        if assignmentsToDelete.count > 0 {
            messages.append("\(assignmentsToDelete.count) assignment(s) will be removed")
        }

        // Count actual updates (composite keys already include app-specific info)
        if !assignmentsRequiringRecreation.isEmpty {
            messages.append("\(assignmentsRequiringRecreation.count) assignment(s) will be updated")
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
        return assignmentsRequiringRecreation.contains(key)
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
                assignmentFilterOverrides.removeValue(forKey: key)
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
            assignmentFilterOverrides.removeValue(forKey: key)
        }
        detectConflicts()
    }

    func changeAllIntents(to intent: AppAssignment.AssignmentIntent) {
        for item in currentAssignmentsWithApp {
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
        detectConflicts()
    }

    func markAllAssignmentsForDeletion() {
        for item in currentAssignmentsWithApp {
            let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
            assignmentsToDelete.insert(key)
            assignmentsToUpdate.removeValue(forKey: key)
            assignmentFilterOverrides.removeValue(forKey: key)
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

    func updateAssignmentFilter(_ item: AssignmentWithApp, filterId: String?, mode: AssignmentFilterMode?) {
        _ = applyFilterOverride(for: item, filterId: filterId, mode: mode)
        detectConflicts()
    }

    func updateFilters(for items: [AssignmentWithApp], filterId: String?, mode: AssignmentFilterMode?) {
        var didChange = false
        for item in items {
            if applyFilterOverride(for: item, filterId: filterId, mode: mode) {
                didChange = true
            }
        }
        if didChange {
            detectConflicts()
        }
    }

    @discardableResult
    private func applyFilterOverride(for item: AssignmentWithApp, filterId: String?, mode: AssignmentFilterMode?) -> Bool {
        let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)

        guard !assignmentsToDelete.contains(key) else { return false }

        let originalId = item.assignment.target.deviceAndAppManagementAssignmentFilterId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalType = item.assignment.target.deviceAndAppManagementAssignmentFilterType?.lowercased()
        let originalMode = originalType.flatMap { AssignmentFilterMode(rawValue: $0) }

        let normalizedId = filterId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedId = (normalizedId?.isEmpty ?? true) ? nil : normalizedId
        let effectiveMode = cleanedId == nil ? nil : (mode ?? .include)

        let matchesOriginal: Bool = {
            if let newId = cleanedId {
                guard let currentId = originalId, currentId == newId else { return false }
                let newModeRaw = (effectiveMode ?? .include).rawValue
                let originalModeRaw = (originalMode ?? .include).rawValue
                return newModeRaw == originalModeRaw
            } else {
                return originalId == nil || originalId?.isEmpty == true
            }
        }()

        let previous = assignmentFilterOverrides[key]

        if matchesOriginal {
            if previous != nil {
                assignmentFilterOverrides.removeValue(forKey: key)
                return true
            }
            return false
        }

        let newOverride = FilterOverride(filterId: cleanedId, filterMode: effectiveMode)
        if previous == newOverride {
            return false
        }

        assignmentFilterOverrides[key] = newOverride
        return true
    }

    func effectiveFilterId(for item: AssignmentWithApp) -> String? {
        let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
        if let override = assignmentFilterOverrides[key] {
            return override.filterId
        }
        let original = item.assignment.target.deviceAndAppManagementAssignmentFilterId?.trimmingCharacters(in: .whitespacesAndNewlines)
        return original?.isEmpty == true ? nil : original
    }

    func effectiveFilterMode(for item: AssignmentWithApp) -> AssignmentFilterMode? {
        let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)
        if let override = assignmentFilterOverrides[key] {
            guard let filterId = override.filterId else { return nil }
            return override.filterMode ?? .include
        }
        guard let type = item.assignment.target.deviceAndAppManagementAssignmentFilterType?.lowercased(),
              let id = item.assignment.target.deviceAndAppManagementAssignmentFilterId,
              !id.isEmpty else {
            return nil
        }
        return AssignmentFilterMode(rawValue: type) ?? .include
    }

    private func resolveFilter(for assignment: AssignmentWithApp, override: FilterOverride?) -> (String?, String?) {
        if let override = override {
            if let filterId = override.filterId, !filterId.isEmpty {
                let mode = override.filterMode ?? .include
                return (filterId, mode.rawValue)
            } else {
                return (nil, nil)
            }
        }

        let existingId = assignment.assignment.target.deviceAndAppManagementAssignmentFilterId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedId = (existingId?.isEmpty ?? true) ? nil : existingId
        let existingType = assignment.assignment.target.deviceAndAppManagementAssignmentFilterType?.lowercased()
        let cleanedType = cleanedId == nil ? nil : (existingType ?? AssignmentFilterMode.include.rawValue)
        return (cleanedId, cleanedType)
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

    func updatePendingFilter(_ assignment: PendingAssignment, filterId: String?, mode: AssignmentFilterMode?) {
        guard let index = pendingAssignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        pendingAssignments[index].assignmentFilterId = filterId
        pendingAssignments[index].assignmentFilterMode = filterId == nil ? nil : (mode ?? .include)
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
                var pending = PendingAssignment(
                    group: group,
                    intent: intent,
                    copySettings: copyable.copySettings,
                    sourceAssignmentId: assignment.id
                )

                if let sourceFilterId = assignment.target.deviceAndAppManagementAssignmentFilterId,
                   !sourceFilterId.isEmpty {
                    pending.assignmentFilterId = sourceFilterId
                    let sourceType = assignment.target.deviceAndAppManagementAssignmentFilterType?.lowercased()
                    pending.assignmentFilterMode = AssignmentFilterMode(rawValue: sourceType ?? "") ?? .include
                }

                pendingAssignments.append(pending)
            }
        }
    }

    func saveChanges() async -> String? {
        isSaving = true
        defer {
            isSaving = false
            saveProgress = nil
        }

        var deleteErrors: [(app: String, group: String, error: String)] = []
        var updateErrors: [(app: String, group: String, error: String, wasDeleted: Bool)] = []
        var createErrors: [(app: String, group: String, error: String)] = []

        // Calculate total operations for progress tracking
        let recreationCount = assignmentsRequiringRecreation.count
        let totalDeletes = assignmentsToDelete.count + recreationCount
        let totalCreates = recreationCount + (pendingAssignments.count * applicationIds.count)
        let totalOps = totalDeletes + totalCreates

        saveProgress = SaveProgress(
            phase: "Preparing",
            totalOperations: totalOps,
            completedOperations: 0,
            failedOperations: 0,
            currentOperation: "Calculating changes..."
        )

        // PHASE 1: Batch process all deletions first (including those for updates)
        struct AssignmentRecreation {
            let item: AssignmentWithApp
            let newIntent: AppAssignment.AssignmentIntent?
            let filterOverride: FilterOverride?
        }

        var deletedForUpdate: [AssignmentRecreation] = []
        var deleteRequests: [BatchRequest] = []
        var deleteMetadata: [(item: AssignmentWithApp, recreation: AssignmentRecreation?)] = []

        // Build delete requests for batching
        for item in currentAssignmentsWithApp {
            let key = compositeKey(appId: item.appId, assignmentId: item.assignment.id)

            if assignmentsToDelete.contains(key) {
                // Simple deletion
                let request = BatchRequest(
                    id: key,
                    method: "DELETE",
                    url: "/deviceAppManagement/mobileApps/\(item.appId)/assignments/\(item.assignment.id)"
                )
                deleteRequests.append(request)
                deleteMetadata.append((item: item, recreation: nil))
            } else if assignmentsRequiringRecreation.contains(key) {
                let recreation = AssignmentRecreation(
                    item: item,
                    newIntent: assignmentsToUpdate[key],
                    filterOverride: assignmentFilterOverrides[key]
                )
                let request = BatchRequest(
                    id: key,
                    method: "DELETE",
                    url: "/deviceAppManagement/mobileApps/\(item.appId)/assignments/\(item.assignment.id)"
                )
                deleteRequests.append(request)
                deleteMetadata.append((item: item, recreation: recreation))
            }
        }

        // Process deletions in batches
        if !deleteRequests.isEmpty {
            saveProgress?.phase = "Deleting assignments"
            saveProgress?.currentOperation = "Processing \(deleteRequests.count) deletions..."

            let deleteBatches = deleteRequests.chunked(into: maxBatchSize)
            let metadataBatches = deleteMetadata.chunked(into: maxBatchSize)

            for (batchIndex, (requests, metadata)) in zip(deleteBatches, metadataBatches).enumerated() {
                saveProgress?.currentOperation = "Delete batch \(batchIndex + 1) of \(deleteBatches.count)"

                do {
                    let responses: [BatchResponse<EmptyResponse>] = try await apiClient.batchModels(requests)

                    // Process responses
                    for (index, response) in responses.enumerated() {
                        let meta = metadata[index]
                        let groupName = meta.item.assignment.target.groupName ?? meta.item.assignment.target.type.displayName

                        if response.status >= 200 && response.status < 300 || response.status == 404 {
                            // Success or already deleted
                            saveProgress?.completedOperations += 1

                            if let recreation = meta.recreation {
                                deletedForUpdate.append(recreation)
                                Logger.shared.info("Deleted assignment for update: \(meta.item.appName) - \(groupName)")
                            } else {
                                Logger.shared.info("Deleted assignment for \(meta.item.appName) - \(groupName)")
                            }
                        } else {
                            saveProgress?.failedOperations += 1
                            let errorMsg = "HTTP \(response.status)"

                            if meta.recreation != nil {
                                updateErrors.append((
                                    app: meta.item.appName,
                                    group: groupName,
                                    error: errorMsg,
                                    wasDeleted: false
                                ))
                            } else {
                                deleteErrors.append((app: meta.item.appName, group: groupName, error: errorMsg))
                            }
                            Logger.shared.error("Failed to delete assignment for \(meta.item.appName): \(errorMsg)")
                        }
                    }
                } catch {
                    // Batch failed - mark all as failed
                    for meta in metadata {
                        saveProgress?.failedOperations += 1
                        let groupName = meta.item.assignment.target.groupName ?? meta.item.assignment.target.type.displayName

                        if meta.recreation != nil {
                            updateErrors.append((
                                app: meta.item.appName,
                                group: groupName,
                                error: error.localizedDescription,
                                wasDeleted: false
                            ))
                        } else {
                            deleteErrors.append((app: meta.item.appName, group: groupName, error: error.localizedDescription))
                        }
                    }
                    Logger.shared.error("Batch delete failed: \(error)")
                }
            }
        }

        // PHASE 2: Batch recreate assignments that were deleted for updates
        if !deletedForUpdate.isEmpty {
            saveProgress?.phase = "Creating updated assignments"
            saveProgress?.currentOperation = "Processing \(deletedForUpdate.count) updates..."

            // Group updates by app ID for efficient batching with /assign endpoint
            var updatesByApp: [String: [AssignmentRecreation]] = [:]
            for update in deletedForUpdate {
                updatesByApp[update.item.appId, default: []].append(update)
            }

            // Process each app's assignments as a batch
            for (appId, updates) in updatesByApp {
                // Build batch request for this app
                struct AssignRequest: Encodable {
                    let mobileAppAssignments: [AssignmentBody]

                    struct AssignmentBody: Encodable {
                        let id: String
                        let intent: String
                        let target: Target
                        let settings: Settings?

                        struct Target: Encodable {
                            let type: String
                            let groupId: String?
                            let deviceAndAppManagementAssignmentFilterId: String?
                            let deviceAndAppManagementAssignmentFilterType: String?

                            enum CodingKeys: String, CodingKey {
                                case type = "@odata.type"
                                case groupId
                                case deviceAndAppManagementAssignmentFilterId
                                case deviceAndAppManagementAssignmentFilterType
                            }

                            func encode(to encoder: Encoder) throws {
                                var container = encoder.container(keyedBy: CodingKeys.self)
                                try container.encode(type, forKey: .type)
                                if let groupId = groupId {
                                    try container.encode(groupId, forKey: .groupId)
                                }
                                if let filterId = deviceAndAppManagementAssignmentFilterId {
                                    try container.encode(filterId, forKey: .deviceAndAppManagementAssignmentFilterId)
                                }
                                if let filterType = deviceAndAppManagementAssignmentFilterType {
                                    try container.encode(filterType, forKey: .deviceAndAppManagementAssignmentFilterType)
                                }
                            }
                        }

                        struct Settings: Encodable {
                            let type: String
                            let useDeviceLicensing: Bool?
                            let uninstallOnDeviceRemoval: Bool?

                            enum CodingKeys: String, CodingKey {
                                case type = "@odata.type"
                                case useDeviceLicensing
                                case uninstallOnDeviceRemoval
                            }
                        }
                    }
                }

                var assignments: [AssignRequest.AssignmentBody] = []
                let appType = applicationData.first(where: { $0.id == appId })?.appType ?? .unknown
                let appName = updates.first?.item.appName ?? appId

                for recreation in updates {
                    let item = recreation.item
                    let groupName = item.assignment.target.groupName ?? item.assignment.target.type.displayName
                    let targetType = item.assignment.target.type

                    var finalIntent = recreation.newIntent ?? item.assignment.intent
                    if !AssignmentIntentValidator.isIntentValid(intent: finalIntent, appType: appType, targetType: targetType) {
                        let validIntents = AssignmentIntentValidator.validIntents(for: appType, targetType: targetType)
                        if let suggestedIntent = validIntents.first {
                            Logger.shared.warning("Intent '\(finalIntent.rawValue)' not valid for \(appType.displayName). Using '\(suggestedIntent.rawValue)'.")
                            finalIntent = suggestedIntent
                        } else {
                            updateErrors.append((
                                app: item.appName,
                                group: groupName,
                                error: "No valid intents available",
                                wasDeleted: true
                            ))
                            continue
                        }
                    }

                    var settings: AssignRequest.AssignmentBody.Settings? = nil
                    if finalIntent != .uninstall {
                        // Only include settings for non-uninstall intents
                        // TODO: Add settings configuration for other intents if needed
                    }

                    let (filterId, filterType) = resolveFilter(for: item, override: recreation.filterOverride)

                    let assignment = AssignRequest.AssignmentBody(
                        id: UUID().uuidString,
                        intent: finalIntent.rawValue,
                        target: AssignRequest.AssignmentBody.Target(
                            type: targetType.rawValue,
                            groupId: targetType.requiresGroupId ? item.assignment.target.groupId : nil,
                            deviceAndAppManagementAssignmentFilterId: filterId,
                            deviceAndAppManagementAssignmentFilterType: filterType
                        ),
                        settings: settings
                    )
                    assignments.append(assignment)
                    saveProgress?.completedOperations += 1
                }

                // Send batch request for this app
                if !assignments.isEmpty {
                    do {
                        let request = AssignRequest(mobileAppAssignments: assignments)
                        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assign"

                        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: request, headers: ["Content-Type": "application/json"])
                        Logger.shared.info("Batch recreated \(assignments.count) assignments for \(appName)")
                    } catch {
                        saveProgress?.failedOperations += assignments.count
                        for recreation in updates {
                            let item = recreation.item
                            let groupName = item.assignment.target.groupName ?? "Unknown"
                            updateErrors.append((
                                app: item.appName,
                                group: groupName,
                                error: "Failed to recreate: \(error.localizedDescription)",
                                wasDeleted: true
                            ))
                        }
                    }
                }
            }
        }

        // PHASE 3: Batch create new assignments
        if !pendingAssignments.isEmpty && !applicationIds.isEmpty {
            saveProgress?.phase = "Creating new assignments"
            let totalNew = pendingAssignments.count * applicationIds.count
            saveProgress?.currentOperation = "Creating \(totalNew) new assignments..."

            struct AssignRequest: Encodable {
                let mobileAppAssignments: [AssignmentBody]

                struct AssignmentBody: Encodable {
                    let id: String
                    let intent: String
                    let target: Target
                    let settings: Settings?

                    struct Target: Encodable {
                        let type: String
                        let groupId: String?
                        let deviceAndAppManagementAssignmentFilterId: String?
                        let deviceAndAppManagementAssignmentFilterType: String?

                        enum CodingKeys: String, CodingKey {
                            case type = "@odata.type"
                            case groupId
                            case deviceAndAppManagementAssignmentFilterId
                            case deviceAndAppManagementAssignmentFilterType
                        }

                        func encode(to encoder: Encoder) throws {
                            var container = encoder.container(keyedBy: CodingKeys.self)
                            try container.encode(type, forKey: .type)
                            if let groupId = groupId {
                                try container.encode(groupId, forKey: .groupId)
                            }
                            if let filterId = deviceAndAppManagementAssignmentFilterId {
                                try container.encode(filterId, forKey: .deviceAndAppManagementAssignmentFilterId)
                            }
                            if let filterType = deviceAndAppManagementAssignmentFilterType {
                                try container.encode(filterType, forKey: .deviceAndAppManagementAssignmentFilterType)
                            }
                        }
                    }

                    struct Settings: Encodable {
                        let type: String
                        let useDeviceLicensing: Bool?
                        let uninstallOnDeviceRemoval: Bool?

                        enum CodingKeys: String, CodingKey {
                            case type = "@odata.type"
                            case useDeviceLicensing
                            case uninstallOnDeviceRemoval
                        }
                    }
                }
            }

            // Process each app
            for appId in applicationIds {
                let appData = applicationData.first(where: { $0.id == appId })
                let appName = appData?.displayName ?? appId
                let appType = appData?.appType ?? .unknown

                saveProgress?.currentOperation = "Creating assignments for \(appName)"

                var assignments: [AssignRequest.AssignmentBody] = []

                for pending in pendingAssignments {
                    let targetType = pending.group.assignmentTargetType

                    // Validate and adjust intent if needed
                    var finalIntent = pending.intent
                    if !AssignmentIntentValidator.isIntentValid(intent: pending.intent, appType: appType, targetType: targetType) {
                        let validIntents = AssignmentIntentValidator.validIntents(for: appType, targetType: targetType)
                        if let suggestedIntent = validIntents.first {
                            Logger.shared.warning("Intent '\(pending.intent.rawValue)' not valid for \(appType.displayName). Using '\(suggestedIntent.rawValue)'.")
                            finalIntent = suggestedIntent
                        } else {
                            createErrors.append((
                                app: appName,
                                group: pending.group.displayName,
                                error: "No valid intents available"
                            ))
                            continue
                        }
                    }

                    // Build settings - IMPORTANT: For VPP apps being uninstalled, use device licensing
                    // For uninstall intent, don't include ANY settings - let Intune use defaults
                    var settings: AssignRequest.AssignmentBody.Settings? = nil
                    if finalIntent != .uninstall {
                        // Only include settings for non-uninstall intents
                        // TODO: Add settings configuration for other intents if needed
                    }

                    let filterId = pending.assignmentFilterId
                    let filterType = filterId == nil ? nil : (pending.assignmentFilterMode ?? .include).rawValue

                    let assignment = AssignRequest.AssignmentBody(
                        id: UUID().uuidString,
                        intent: finalIntent.rawValue,
                        target: AssignRequest.AssignmentBody.Target(
                            type: targetType.rawValue,
                            groupId: targetType.requiresGroupId ? pending.group.id : nil,
                            deviceAndAppManagementAssignmentFilterId: filterId,
                            deviceAndAppManagementAssignmentFilterType: filterType
                        ),
                        settings: settings
                    )
                    assignments.append(assignment)
                }

                // Send batch request for this app
                if !assignments.isEmpty {
                    do {
                        let request = AssignRequest(mobileAppAssignments: assignments)
                        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assign"

                        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: request, headers: ["Content-Type": "application/json"])
                        saveProgress?.completedOperations += assignments.count
                        Logger.shared.info("Batch created \(assignments.count) assignments for \(appName)")
                    } catch {
                        saveProgress?.failedOperations += assignments.count
                        for pending in pendingAssignments {
                            createErrors.append((
                                app: appName,
                                group: pending.group.displayName,
                                error: error.localizedDescription
                            ))
                        }
                    }
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
                let deviceAndAppManagementAssignmentFilterId: String?
                let deviceAndAppManagementAssignmentFilterType: String?

                enum CodingKeys: String, CodingKey {
                    case type = "@odata.type"
                    case groupId
                    case deviceAndAppManagementAssignmentFilterId
                    case deviceAndAppManagementAssignmentFilterType
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(type, forKey: .type)
                    // Only encode groupId if it's present and not a built-in target
                    if let groupId = groupId {
                        try container.encode(groupId, forKey: .groupId)
                    }
                    if let filterId = deviceAndAppManagementAssignmentFilterId {
                        try container.encode(filterId, forKey: .deviceAndAppManagementAssignmentFilterId)
                    }
                    if let filterType = deviceAndAppManagementAssignmentFilterType {
                        try container.encode(filterType, forKey: .deviceAndAppManagementAssignmentFilterType)
                    }
                }
            }
        }

        // Determine the target type based on the group
        let targetType = pending.group.assignmentTargetType
        let filterId = pending.assignmentFilterId
        let filterType = filterId == nil ? nil : (pending.assignmentFilterMode ?? .include).rawValue

        let createRequest = CreateRequest(
            intent: pending.intent.rawValue,
            target: CreateRequest.TargetRequest(
                type: targetType.rawValue,
                // Only include groupId for regular groups, not built-in targets
                groupId: targetType.requiresGroupId ? pending.group.id : nil,
                deviceAndAppManagementAssignmentFilterId: filterId,
                deviceAndAppManagementAssignmentFilterType: filterType
            )
        )

        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: createRequest)
    }
}
