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
                    ReviewAssignmentView(viewModel: viewModel)
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
    @State private var sortOrder: SortOrder = .name
    @State private var platformFilter: Application.DevicePlatform?
    @State private var showingBulkEdit = false

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
                    }

                    Button("Select All") {
                        selectedApps = Set(filteredApps)
                    }

                    Button("Clear") {
                        selectedApps.removeAll()
                    }
                    .disabled(selectedApps.isEmpty)
                }

                HStack {
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
                        ForEach(Application.AppType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(Application.AppType?.some(type))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)

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
                        Label("\(appService.applications.filter { !$0.hasAssignments }.count) unassigned", systemImage: "square")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Label("\(appService.applications.filter { $0.hasAssignments }.count) assigned", systemImage: "person.2.square.stack")
                            .font(.caption)
                            .foregroundColor(.green)
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
        .sheet(isPresented: $showingBulkEdit) {
            AssignmentEditView(applications: Array(selectedApps))
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
