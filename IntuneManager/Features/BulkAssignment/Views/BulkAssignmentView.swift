import SwiftUI

struct BulkAssignmentView: View {
    @StateObject private var viewModel = BulkAssignmentViewModel()
    @EnvironmentObject var appState: AppState
    @State private var currentStep: AssignmentStep = .selectApps
    @State private var showingConfirmation = false
    @State private var showingProgress = false

    enum AssignmentStep: Int, CaseIterable {
        case selectApps = 0
        case selectGroups = 1
        case configureSettings = 2
        case review = 3

        var title: String {
            switch self {
            case .selectApps: return "Applications Overview"
            case .selectGroups: return "Select Target Groups"
            case .configureSettings: return "Configure Assignment Settings"
            case .review: return "Review & Deploy"
            }
        }

        var icon: String {
            switch self {
            case .selectApps: return "app.badge"
            case .selectGroups: return "person.3"
            case .configureSettings: return "gearshape"
            case .review: return "checkmark.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            StepProgressView(currentStep: currentStep)
                .padding()

            Divider()

            // Content
            Group {
                switch currentStep {
                case .selectApps:
                    ApplicationSelectionView(selectedApps: $viewModel.selectedApplications)
                case .selectGroups:
                    GroupSelectionView(
                        selectedGroups: $viewModel.selectedGroups,
                        selectedApplications: viewModel.selectedApplications
                    )
                case .configureSettings:
                    GroupAssignmentSettingsView(
                        groupSettings: $viewModel.groupAssignmentSettings,
                        selectedApplications: viewModel.selectedApplications,
                        selectedGroups: viewModel.selectedGroups
                    )
                case .review:
                    ReviewAssignmentView(viewModel: viewModel, currentStep: $currentStep)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation Controls
            HStack {
                Button(action: previousStep) {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(currentStep == .selectApps)
                .buttonStyle(.bordered)

                Spacer()

                VStack(spacing: 2) {
                    if currentStep == .selectApps && !viewModel.selectedApplications.isEmpty {
                        Text("\(viewModel.selectedApplications.count) apps selected")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    Text("\(viewModel.totalExistingAssignments) existing assignments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if currentStep == .review && viewModel.totalNewAssignments > 0 {
                        Text("\(viewModel.totalNewAssignments) new to create")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                }

                Spacer()

                if currentStep == .review {
                    Button(action: performAssignment) {
                        Label("Assign", systemImage: "arrow.right.square.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.isValid)
                } else {
                    Button(action: nextStep) {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isStepValid)
                }
            }
            .padding()
        }
        .navigationTitle("Applications")
        #if os(macOS)
        .navigationSubtitle(currentStep == .selectApps ? "Browse & Manage" : "\(currentStep.title)")
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Cancel") {
                    resetAssignment()
                }
            }
        }
        .sheet(isPresented: $showingProgress) {
            AssignmentProgressView(viewModel: viewModel)
        }
        .alert("Confirm Assignment", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) {
                executeAssignment()
            }
        } message: {
            Text("This will create \(viewModel.totalAssignments) assignments. This action cannot be undone.")
        }
    }

    private var isStepValid: Bool {
        switch currentStep {
        case .selectApps:
            return !viewModel.selectedApplications.isEmpty
        case .selectGroups:
            return !viewModel.selectedGroups.isEmpty
        case .configureSettings:
            return true
        case .review:
            return viewModel.isValid
        }
    }

    private func nextStep() {
        withAnimation {
            if let nextStep = AssignmentStep(rawValue: currentStep.rawValue + 1) {
                Logger.shared.info("Navigating to \(nextStep.title)", category: .ui)
                currentStep = nextStep
            }
        }
    }

    private func previousStep() {
        withAnimation {
            if let previousStep = AssignmentStep(rawValue: currentStep.rawValue - 1) {
                Logger.shared.info("Navigating back to \(previousStep.title)", category: .ui)
                currentStep = previousStep
            }
        }
    }

    private func performAssignment() {
        Logger.shared.info("User initiated assignment confirmation", category: .ui)
        showingConfirmation = true
    }

    private func executeAssignment() {
        Logger.shared.info("Executing bulk assignment with \(viewModel.totalAssignments) assignments", category: .ui)
        showingProgress = true
        Task {
            await viewModel.executeAssignment()
            showingProgress = false
            resetAssignment()
            Logger.shared.info("Bulk assignment completed", category: .ui)
            // Don't refresh applications here to avoid SwiftData context issues
            // The notification posted by the view model will handle updates in other views
        }
    }

    private func resetAssignment() {
        Logger.shared.info("Resetting bulk assignment", category: .ui)
        viewModel.reset()
        currentStep = .selectApps
    }
}

// MARK: - Step Progress View
struct StepProgressView: View {
    let currentStep: BulkAssignmentView.AssignmentStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BulkAssignmentView.AssignmentStep.allCases, id: \.self) { step in
                StepIndicator(
                    step: step,
                    isActive: step.rawValue <= currentStep.rawValue,
                    isCurrent: step == currentStep
                )

                if step != BulkAssignmentView.AssignmentStep.allCases.last {
                    StepConnector(isActive: step.rawValue < currentStep.rawValue)
                        .frame(height: 2)
                }
            }
        }
        .frame(height: 60)
    }
}

struct StepIndicator: View {
    let step: BulkAssignmentView.AssignmentStep
    let isActive: Bool
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 30, height: 30)

                Image(systemName: step.icon)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }

            Text(step.title)
                .font(.caption2)
                .foregroundColor(isActive ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
        .scaleEffect(isCurrent ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }
}

struct StepConnector: View {
    let isActive: Bool

    var body: some View {
        Rectangle()
            .fill(isActive ? Color.accentColor : Color.gray.opacity(0.3))
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Application Selection View
struct ApplicationSelectionView: View {
    @Binding var selectedApps: Set<Application>
    @StateObject private var appService = ApplicationService.shared
    @State private var searchText = ""
    @State private var selectedFilter: Application.AppType?
    @State private var assignmentFilter: AssignmentFilter = .all
    @State private var assignmentIntentFilter: AssignmentIntentFilter = .any
    @State private var sortOrder: SortOrder = .name
    @State private var platformFilter: Application.DevicePlatform?
    @State private var showingBulkEdit = false
    @State private var showingDeleteAssignmentsConfirmation = false
    @State private var showingDeleteAppsConfirmation = false
    @State private var isDeletingApps = false
    @State private var deleteAppsResult: (successful: [String], failed: [(id: String, error: String)])?
    @State private var showingAddApplication = false

    enum AssignmentFilter: String, CaseIterable {
        case all = "All Apps"
        case unassigned = "Unassigned"
        case assigned = "Assigned"

        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .unassigned: return "square"
            case .assigned: return "person.2.square.stack"
            }
        }
    }

    enum AssignmentIntentFilter: String, CaseIterable, Identifiable {
        case any
        case install
        case uninstall
        case available
        case availableWithoutEnrollment

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .any: return "Any Intent"
            case .install: return "Install (Required)"
            case .uninstall: return "Uninstall"
            case .available: return "Available"
            case .availableWithoutEnrollment: return "Available w/o Enrollment"
            }
        }

        var systemImage: String {
            switch self {
            case .any: return "line.3.horizontal.decrease.circle"
            case .install: return AppAssignment.AssignmentIntent.required.icon
            case .uninstall: return AppAssignment.AssignmentIntent.uninstall.icon
            case .available: return AppAssignment.AssignmentIntent.available.icon
            case .availableWithoutEnrollment: return AppAssignment.AssignmentIntent.availableWithoutEnrollment.icon
            }
        }

        var matchingIntents: [AppAssignment.AssignmentIntent] {
            switch self {
            case .any:
                return []
            case .install:
                return [.required]
            case .uninstall:
                return [.uninstall]
            case .available:
                return [.available]
            case .availableWithoutEnrollment:
                return [.availableWithoutEnrollment]
            }
        }

        var requiresGroupTarget: Bool {
            switch self {
            case .install, .uninstall:
                return true
            default:
                return false
            }
        }
    }

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
        case modified = "Modified"
        case assignments = "Assignments"

        var comparator: (Application, Application) -> Bool {
            switch self {
            case .name:
                return { $0.displayName < $1.displayName }
            case .type:
                return { $0.appType.displayName < $1.appType.displayName }
            case .modified:
                return { $0.lastModifiedDateTime > $1.lastModifiedDateTime }
            case .assignments:
                return { $0.assignmentCount > $1.assignmentCount }
            }
        }
    }

    var filteredApps: [Application] {
        var apps = appService.applications

        // Apply assignment filter
        switch assignmentFilter {
        case .all:
            break // No filter
        case .unassigned:
            apps = apps.filter { !$0.hasAssignments }
        case .assigned:
            apps = apps.filter { $0.hasAssignments }
        }

        if assignmentIntentFilter != .any {
            let intents = assignmentIntentFilter.matchingIntents
            let requireGroup = assignmentIntentFilter.requiresGroupTarget
            apps = apps.filter { app in
                guard let assignments = app.assignments else { return false }
                return assignments.contains { assignment in
                    intents.contains(assignment.intent) &&
                    (!requireGroup || assignment.target.type == .group)
                }
            }
        }

        // Apply platform filter
        if let platform = platformFilter {
            apps = apps.filter { $0.supportedPlatforms.contains(platform) }
        }

        if !searchText.isEmpty {
            apps = apps.filter { app in
                app.displayName.localizedCaseInsensitiveContains(searchText) ||
                app.publisher?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        if let filter = selectedFilter {
            apps = apps.filter { $0.appType == filter }
        }

        return apps.sorted(by: sortOrder.comparator)
    }

    var body: some View {
        VStack {
            // Header section
            VStack(alignment: .leading, spacing: 8) {
                Text("Applications Management")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Browse all applications, view details, and manage assignments. Select applications to configure bulk assignments to groups.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            // Toolbar
            VStack(spacing: 12) {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search applications...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    Spacer()

                    // Assignment status filter
                    Picker("", selection: $assignmentFilter) {
                        ForEach(AssignmentFilter.allCases, id: \.self) { filter in
                            Label(filter.rawValue, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)

                    Spacer()

                    Text("\(filteredApps.count) apps • \(selectedApps.count) selected")
                        .foregroundColor(.secondary)

                    if !selectedApps.isEmpty {
                        Button("Edit Selected Assignments") {
                            showingBulkEdit = true
                        }
                        .buttonStyle(.bordered)

                        Button {
                            showingDeleteAssignmentsConfirmation = true
                        } label: {
                            Label("Delete App Assignments", systemImage: "person.2.slash")
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            showingDeleteAppsConfirmation = true
                        } label: {
                            Label("Delete Apps from Intune", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isDeletingApps)
                    }

                    Button {
                        showingAddApplication = true
                    } label: {
                        Label("Add Application", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Select All") {
                        selectedApps = Set(filteredApps)
                    }

                    Button("Clear") {
                        selectedApps.removeAll()
                    }
                    .disabled(selectedApps.isEmpty)
                }

                HStack {
                    Picker("Intent", selection: $assignmentIntentFilter) {
                        ForEach(AssignmentIntentFilter.allCases) { intent in
                            Label(intent.displayName, systemImage: intent.systemImage)
                                .tag(intent)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)
                    .onChange(of: assignmentIntentFilter) { _, newValue in
                        if newValue == .any {
                            return
                        }
                        if assignmentFilter == .unassigned {
                            assignmentFilter = .assigned
                        }
                    }

                    Picker("Platform", selection: $platformFilter) {
                        Text("All Platforms").tag(Application.DevicePlatform?.none)
                        Divider()
                        ForEach(Application.DevicePlatform.allCases.filter { $0 != .unknown }, id: \.self) { platform in
                            Label(platform.displayName, systemImage: platform.icon)
                                .tag(Application.DevicePlatform?.some(platform))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)

                    Picker("Type", selection: $selectedFilter) {
                        Text("All Types").tag(Application.AppType?.none)
                        Divider()

                        // Filter types based on selected platform
                        if platformFilter == nil {
                            // Group by platform when no platform is selected
                            ForEach(Application.AppType.groupedByPlatform, id: \.platform) { group in
                                if !group.types.isEmpty {
                                    Section(header: Text(group.platform.displayName)) {
                                        ForEach(group.types, id: \.self) { type in
                                            Label(type.displayName, systemImage: type.icon)
                                                .tag(Application.AppType?.some(type))
                                        }
                                    }
                                }
                            }
                            // Add web apps separately as they're cross-platform
                            Section(header: Text("Cross-Platform")) {
                                Label(Application.AppType.webApp.displayName, systemImage: Application.AppType.webApp.icon)
                                    .tag(Application.AppType?.some(.webApp))
                            }
                        } else {
                            // Show filtered types when platform is selected
                            let typesToShow = Application.AppType.types(for: platformFilter)
                            ForEach(typesToShow, id: \.self) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(Application.AppType?.some(type))
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)

                    Picker("Sort", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)

                    Spacer()

                    // Summary statistics
                    HStack(spacing: 16) {
                        let unassignedCount = appService.applications.filter { !$0.hasAssignments }.count
                        let assignedCount = appService.applications.filter { $0.hasAssignments }.count
                        let installCount = appService.applications.filter {
                            $0.assignments?.contains(where: { $0.intent == .required && $0.target.type == .group }) == true
                        }.count
                        let uninstallCount = appService.applications.filter {
                            $0.assignments?.contains(where: { $0.intent == .uninstall && $0.target.type == .group }) == true
                        }.count

                        Label("\(unassignedCount) unassigned", systemImage: "square")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Label("\(assignedCount) assigned", systemImage: "person.2.square.stack")
                            .font(.caption)
                            .foregroundColor(.green)
                        Label("\(installCount) install", systemImage: AppAssignment.AssignmentIntent.required.icon)
                            .font(.caption)
                            .foregroundColor(.blue)
                        Label("\(uninstallCount) uninstall", systemImage: AppAssignment.AssignmentIntent.uninstall.icon)
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("(\(appService.applications.count) total)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()

            // App List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredApps) { app in
                        ApplicationRowView(
                            application: app,
                            isSelected: selectedApps.contains(app),
                            onToggle: {
                                if selectedApps.contains(app) {
                                    selectedApps.remove(app)
                                } else {
                                    selectedApps.insert(app)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .task {
            if appService.applications.isEmpty {
                do {
                    _ = try await appService.fetchApplications()
                } catch {
                    Logger.shared.error("Failed to load applications: \(error)")
                }
            }
        }
        .onChange(of: platformFilter) { _, newPlatform in
            // Clear app type filter if it doesn't match the new platform
            if let appType = selectedFilter,
               let platform = newPlatform,
               appType.platformCategory != platform && appType != .webApp {
                selectedFilter = nil
            }
        }
        .sheet(isPresented: $showingBulkEdit) {
            AssignmentEditView(applications: Array(selectedApps))
        }
        .sheet(isPresented: $showingAddApplication) {
            AddApplicationView()
        }
        .confirmationDialog(
            "Delete App Assignments",
            isPresented: $showingDeleteAssignmentsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Assignments for \(selectedApps.count) Apps", role: .destructive) {
                Task {
                    await deleteAssignmentsForSelectedApps()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all assignments for the selected apps but will not delete the apps from Intune.")
        }
        .confirmationDialog(
            "Delete Apps from Intune",
            isPresented: $showingDeleteAppsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(selectedApps.count) Apps", role: .destructive) {
                Task {
                    await deleteSelectedApps()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(selectedApps.count) apps from Intune? This action cannot be undone. All assignments will be removed but the apps will not be uninstalled from devices.")
        }
        .overlay {
            if isDeletingApps {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Deleting \(selectedApps.count) applications...")
                            .font(.headline)
                        Text("Please wait, this may take a moment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(32)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(12)
                }
            }
        }
        .alert(
            "Operation Complete",
            isPresented: .constant(deleteAppsResult != nil),
            presenting: deleteAppsResult
        ) { result in
            Button("OK") {
                deleteAppsResult = nil
                // Clear selection after successful deletion
                if !result.successful.isEmpty {
                    selectedApps.removeAll()
                }
            }
        } message: { result in
            VStack(alignment: .leading, spacing: 8) {
                if !result.successful.isEmpty {
                    Text("Successfully deleted \(result.successful.count) applications")
                        .font(.headline)
                }
                if !result.failed.isEmpty {
                    Text("Failed to delete \(result.failed.count) applications:")
                        .font(.headline)
                        .foregroundColor(.red)

                    // Group errors by message for better display
                    let errorGroups = Dictionary(grouping: result.failed) { $0.error }

                    ForEach(Array(errorGroups.keys).sorted(), id: \.self) { errorMessage in
                        let count = errorGroups[errorMessage]?.count ?? 0
                        if count == 1, let failedApp = errorGroups[errorMessage]?.first {
                            // Show app name for single failures
                            if let app = appService.applications.first(where: { $0.id == failedApp.id }) {
                                Text("• \(app.displayName): \(errorMessage)")
                                    .font(.caption)
                            } else {
                                Text("• \(errorMessage)")
                                    .font(.caption)
                            }
                        } else {
                            // Group multiple apps with same error
                            Text("• \(count) apps: \(errorMessage)")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Delete Functions

    private func deleteAssignmentsForSelectedApps() async {
        // Extract IDs and assignment info before any async operations
        // to avoid accessing detached SwiftData models
        var assignmentsToDelete: [(appId: String, assignmentId: String)] = []

        for app in selectedApps {
            let appId = app.id
            // Safely extract assignments while model is still attached
            if let assignments = app.assignments {
                for assignment in assignments {
                    assignmentsToDelete.append((appId: appId, assignmentId: assignment.id))
                }
            }
        }

        guard !assignmentsToDelete.isEmpty else {
            Logger.shared.info("No assignments to delete for selected apps", category: .ui)
            return
        }

        let appCount = selectedApps.count

        isDeletingApps = true
        defer { isDeletingApps = false }

        do {
            Logger.shared.info("Deleting \(assignmentsToDelete.count) assignments for \(appCount) apps", category: .ui)
            try await appService.deleteBatchAssignments(assignmentsToDelete)

            // Refresh applications
            _ = try? await appService.fetchApplications(forceRefresh: true)

            Logger.shared.info("Successfully deleted assignments", category: .ui)
        } catch {
            Logger.shared.error("Failed to delete assignments: \(error.localizedDescription)", category: .ui)
        }
    }

    private func deleteSelectedApps() async {
        // Extract IDs before any async operations to avoid accessing detached SwiftData models
        let appIds = selectedApps.map { $0.id }

        isDeletingApps = true
        defer { isDeletingApps = false }

        do {
            Logger.shared.info("Starting deletion of \(appIds.count) applications", category: .ui)
            let result = try await appService.deleteBatchApplications(appIds)

            Logger.shared.info("Deletion completed: \(result.successful.count) successful, \(result.failed.count) failed", category: .ui)
            deleteAppsResult = result

            // Refresh the applications list
            _ = try? await appService.fetchApplications(forceRefresh: true)
        } catch {
            Logger.shared.error("Failed to delete apps: \(error.localizedDescription)", category: .ui)
            deleteAppsResult = (successful: [], failed: appIds.map { ($0, error.localizedDescription) })
        }
    }
}

struct ApplicationRowView: View {
    let application: Application
    let isSelected: Bool
    let onToggle: () -> Void
    @State private var showingAssignmentDetails = false
    @State private var showingEditAssignments = false
    @State private var showingAppDetails = false

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(application.displayName)
                        .font(.system(.body, design: .default))
                        .lineLimit(1)

                    // Platform compatibility badges
                    HStack(spacing: 4) {
                        ForEach(Array(application.supportedPlatforms.sorted { $0.rawValue < $1.rawValue }), id: \.self) { platform in
                            Image(systemName: platform.icon)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Assignment indicator badge with popover
                    if application.hasAssignments {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text("\(application.assignmentCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                        .onHover { hovering in
                            showingAssignmentDetails = hovering
                        }
                        .popover(isPresented: $showingAssignmentDetails) {
                            AssignmentDetailsPopover(application: application)
                        }
                    }
                }

                HStack {
                    Label(application.appType.displayName, systemImage: application.appType.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !application.supportedPlatforms.isEmpty {
                        Text("• \(application.supportedPlatformsDescription)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if let publisher = application.publisher {
                        Text("• \(publisher)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if let version = application.version {
                        Text("• v\(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Assignment summary if app has assignments
                if application.hasAssignments {
                    Text(application.assignmentSummary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // App Details button
            Button(action: {
                showingAppDetails = true
            }) {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("View app details")

            // Edit Assignments button
            Button(action: {
                showingEditAssignments = true
            }) {
                Label("Edit", systemImage: "pencil.circle")
                    .labelStyle(.iconOnly)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("Edit assignments for this application")

            if let summary = application.installSummary {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(summary.installedDeviceCount) installed")
                        .font(.caption)
                        .foregroundColor(.green)
                    if summary.failedDeviceCount > 0 {
                        Text("\(summary.failedDeviceCount) failed")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onTapGesture {
            onToggle()
        }
        .sheet(isPresented: $showingEditAssignments) {
            AssignmentEditView(applications: [application])
        }
        .sheet(isPresented: $showingAppDetails) {
            NavigationStack {
                ApplicationDetailView(application: application)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingAppDetails = false
                            }
                        }
                    }
            }
        }
    }
}

struct AssignmentDetailsPopover: View {
    let application: Application

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assigned Groups")
                .font(.headline)
                .padding(.bottom, 4)

            if let assignments = application.assignments, !assignments.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(assignments) { assignment in
                            HStack {
                                Image(systemName: assignment.intent.icon)
                                    .foregroundColor(intentColor(for: assignment.intent))
                                    .font(.caption)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(assignment.target.groupName ?? assignment.target.type.displayName)
                                        .font(.system(.caption, design: .default))
                                        .fontWeight(.medium)

                                    Text(assignment.intent.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(4)
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else {
                Text("No assignments")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 250, maxWidth: 350)
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
