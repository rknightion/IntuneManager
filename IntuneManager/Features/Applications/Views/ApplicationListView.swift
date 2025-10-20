import SwiftUI

struct ApplicationListView: View {
    @StateObject private var appService = ApplicationService.shared
    @State private var searchText = ""
    @State private var assignmentFilter: AssignmentFilter = .all
    @State private var selectedAssignmentIntent: AssignmentIntentFilter = .any
    @State private var showFilters = false

    // Filter states
    @State private var selectedAppType: Application.AppType?
    @State private var selectedPublisher: String?
    @State private var selectedOwner: String?
    @State private var selectedDeveloper: String?
    @State private var selectedPublishingState: Application.PublishingState?
    @State private var isFeaturedFilter: Bool?
    @State private var selectedPlatform: Application.DevicePlatform?
    @State private var showingBackupRestore = false
    @State private var showingAddApplication = false

    // Multi-selection and bulk delete
    @State private var isSelecting = false
    @State private var selectedApplications = Set<String>()
    @State private var showingBulkDeleteConfirmation = false
    @State private var isDeletingBulk = false
    @State private var bulkDeleteError: String?
    @State private var bulkDeleteResult: (successful: [String], failed: [(id: String, error: String)])?

    enum AssignmentFilter: String, CaseIterable {
        case all = "All"
        case unassigned = "Unassigned"
        case assigned = "Assigned"

        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .unassigned: return "square"
            case .assigned: return "checkmark.square"
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
            case .any: return "Any"
            case .install: return "Install (Required)"
            case .uninstall: return "Uninstall"
            case .available: return "Available"
            case .availableWithoutEnrollment: return "Available w/o Enrollment"
            }
        }

        var chipLabel: String {
            switch self {
            case .any: return "Any"
            default: return displayName
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

    var availablePublishers: [String] {
        var publishers = Set<String>()
        publishers.insert("All")
        appService.applications.compactMap { $0.publisher }.forEach { publishers.insert($0) }
        return Array(publishers).sorted()
    }

    var availableOwners: [String] {
        var owners = Set<String>()
        owners.insert("All")
        appService.applications.compactMap { $0.owner }.forEach { owners.insert($0) }
        return Array(owners).sorted()
    }

    var availableDevelopers: [String] {
        var developers = Set<String>()
        developers.insert("All")
        appService.applications.compactMap { $0.developer }.forEach { developers.insert($0) }
        return Array(developers).sorted()
    }

    var activeFilterCount: Int {
        var count = 0
        if assignmentFilter != .all { count += 1 }
        if selectedAssignmentIntent != .any { count += 1 }
        if selectedAppType != nil { count += 1 }
        if selectedPublisher != nil && selectedPublisher != "All" { count += 1 }
        if selectedOwner != nil && selectedOwner != "All" { count += 1 }
        if selectedDeveloper != nil && selectedDeveloper != "All" { count += 1 }
        if selectedPublishingState != nil { count += 1 }
        if isFeaturedFilter != nil { count += 1 }
        if selectedPlatform != nil { count += 1 }
        return count
    }

    func clearFilters() {
        assignmentFilter = .all
        selectedAssignmentIntent = .any
        selectedAppType = nil
        selectedPublisher = nil
        selectedOwner = nil
        selectedDeveloper = nil
        selectedPublishingState = nil
        isFeaturedFilter = nil
        selectedPlatform = nil
        searchText = ""
    }

    var filteredApplications: [Application] {
        var apps = appService.searchApplications(query: searchText)

        // Assignment filter
        switch assignmentFilter {
        case .all:
            break
        case .unassigned:
            apps = apps.filter { !$0.hasAssignments }
        case .assigned:
            apps = apps.filter { $0.hasAssignments }
        }

        if selectedAssignmentIntent != .any {
            let intents = selectedAssignmentIntent.matchingIntents
            let requireGroup = selectedAssignmentIntent.requiresGroupTarget
            apps = apps.filter { app in
                intents.first(where: { app.hasAssignment(intent: $0, groupOnly: requireGroup) }) != nil
            }
        }

        // App type filter
        if let appType = selectedAppType {
            apps = apps.filter { $0.appType == appType }
        }

        // Publisher filter
        if let publisher = selectedPublisher, publisher != "All" {
            apps = apps.filter { $0.publisher == publisher }
        }

        // Owner filter
        if let owner = selectedOwner, owner != "All" {
            apps = apps.filter { $0.owner == owner }
        }

        // Developer filter
        if let developer = selectedDeveloper, developer != "All" {
            apps = apps.filter { $0.developer == developer }
        }

        // Publishing state filter
        if let publishingState = selectedPublishingState {
            apps = apps.filter { $0.publishingState == publishingState }
        }

        // Featured filter
        if let featured = isFeaturedFilter {
            apps = apps.filter { $0.isFeatured == featured }
        }

        // Platform filter
        if let platform = selectedPlatform {
            apps = apps.filter { $0.supportedPlatforms.contains(platform) }
        }

        return apps
    }

    @ViewBuilder
    var mainContent: some View {
        VStack(spacing: 0) {
            // Filters view
            if showFilters {
                filtersSection
            }

            // Status bar
            statusBar

            // Applications list
            applicationsList
                .searchable(text: $searchText, prompt: "Search by name or publisher")
        }
    }

    @ViewBuilder
    var filtersSection: some View {
        ApplicationFiltersView(
            assignmentFilter: $assignmentFilter,
            selectedAssignmentIntent: $selectedAssignmentIntent,
            selectedAppType: $selectedAppType,
            selectedPublisher: $selectedPublisher,
            selectedOwner: $selectedOwner,
            selectedDeveloper: $selectedDeveloper,
            selectedPublishingState: $selectedPublishingState,
            isFeaturedFilter: $isFeaturedFilter,
            selectedPlatform: $selectedPlatform,
            availablePublishers: availablePublishers,
            availableOwners: availableOwners,
            availableDevelopers: availableDevelopers,
            activeFilterCount: activeFilterCount,
            clearFilters: clearFilters
        )
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .border(Color.secondary.opacity(0.2), width: 0.5)
        .onChange(of: selectedPlatform) { _, newPlatform in
            // Clear app type if it doesn't match the new platform
            if let appType = selectedAppType,
               let platform = newPlatform,
               appType.platformCategory != platform && appType != .webApp {
                selectedAppType = nil
            }
        }
        .onChange(of: selectedAssignmentIntent) { _, newValue in
            if newValue == .any {
                // leave assignment filter as-is
            } else if assignmentFilter == .unassigned {
                assignmentFilter = .assigned
            }
        }
    }

    var statusBar: some View {
        HStack {
            Text("\(filteredApplications.count) of \(appService.applications.count) applications")
                .font(.caption)
                .foregroundColor(.secondary)
            if isSelecting {
                Divider()
                    .frame(height: 12)
                Text("\(selectedApplications.count) selected")
                    .font(.caption)
                    .foregroundColor(selectedApplications.isEmpty ? .secondary : .accentColor)
            }
            Spacer()
            HStack(spacing: 12) {
                let unassignedCount = appService.applications.filter { !$0.hasAssignments }.count
                let assignedCount = appService.applications.filter { $0.hasAssignments }.count
                let installGroupCount = appService.applications.filter {
                    $0.hasAssignment(intent: .required, groupOnly: true)
                }.count
                let uninstallGroupCount = appService.applications.filter {
                    $0.hasAssignment(intent: .uninstall, groupOnly: true)
                }.count
                Label("\(unassignedCount) unassigned", systemImage: "square")
                    .font(.caption)
                    .foregroundColor(.orange)
                Label("\(assignedCount) assigned", systemImage: "checkmark.square")
                    .font(.caption)
                    .foregroundColor(.green)
                Label("\(installGroupCount) install", systemImage: AppAssignment.AssignmentIntent.required.icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                Label("\(uninstallGroupCount) uninstall", systemImage: AppAssignment.AssignmentIntent.uninstall.icon)
                    .font(.caption)
                    .foregroundColor(.red)
                Text("(\(appService.applications.count) total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    var applicationsList: some View {
        if isSelecting {
            List(filteredApplications, selection: $selectedApplications) { app in
                ApplicationListRowView(application: app)
                    .tag(app.id)
            }
        } else {
            List(filteredApplications) { app in
                NavigationLink(destination: ApplicationDetailView(application: app)) {
                    ApplicationListRowView(application: app)
                }
            }
        }
    }

    var body: some View {
        Group {
            if appService.isLoading && appService.applications.isEmpty {
                ProgressView("Loading applications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainContent
            }
        }
        .navigationTitle("Applications")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                if isSelecting {
                    Button(action: {
                        if selectedApplications.count == filteredApplications.count {
                            selectedApplications.removeAll()
                        } else {
                            selectedApplications = Set(filteredApplications.map { $0.id })
                        }
                    }) {
                        Label(selectedApplications.count == filteredApplications.count ? "Deselect All" : "Select All",
                              systemImage: selectedApplications.count == filteredApplications.count ? "checkmark.square" : "square")
                    }
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                if isSelecting && !selectedApplications.isEmpty {
                    Button(role: .destructive) {
                        showingBulkDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete (\(selectedApplications.count))")
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(isDeletingBulk)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddApplication = true }) {
                    Label("Add Application", systemImage: "plus")
                }
                .help("Add a new application")
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    withAnimation {
                        isSelecting.toggle()
                        selectedApplications.removeAll()
                    }
                }) {
                    Text(isSelecting ? "Done" : "Select")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingBackupRestore = true }) {
                    Label("Backup/Restore", systemImage: "arrow.up.arrow.down.circle")
                }
                .help("Backup or restore assignment configurations")
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: { showFilters.toggle() }) {
                    Label("Filters", systemImage: "line.horizontal.3.decrease.circle")
                        .symbolVariant(showFilters ? .fill : .none)
                }
                .help("Toggle application filters")
                .overlay(alignment: .topTrailing) {
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.caption2)
                            .padding(2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
        .task {
            Logger.shared.info("ApplicationListView appeared", category: .ui)
            do {
                Logger.shared.info("Loading applications list...", category: .ui)
                _ = try await appService.fetchApplications()
                Logger.shared.info("Applications list loaded successfully", category: .ui)
            } catch {
                Logger.shared.error("Failed to load applications: \(error.localizedDescription)", category: .ui)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .assignmentsDidChange)) { _ in
            // Refresh when assignments change
            Task {
                _ = try? await appService.fetchApplications(forceRefresh: true)
            }
        }
        .sheet(isPresented: $showingBackupRestore) {
            AssignmentBackupRestoreView()
        }
        .sheet(isPresented: $showingAddApplication) {
            AddApplicationView()
        }
        .confirmationDialog(
            "Delete Applications",
            isPresented: $showingBulkDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(selectedApplications.count) Applications", role: .destructive) {
                Task {
                    await performBulkDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(selectedApplications.count) applications? This action cannot be undone. All assignments will be removed but the apps will not be uninstalled from devices.")
        }
        .overlay {
            if isDeletingBulk {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Deleting \(selectedApplications.count) applications...")
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
            "Bulk Delete Complete",
            isPresented: .constant(bulkDeleteResult != nil),
            presenting: bulkDeleteResult
        ) { result in
            Button("OK") {
                bulkDeleteResult = nil
                // Exit selection mode after successful deletion
                if !result.successful.isEmpty {
                    isSelecting = false
                    selectedApplications.removeAll()
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
                            Text("• \(getAppName(for: failedApp.id)): \(errorMessage)")
                                .font(.caption)
                        } else {
                            // Group multiple apps with same error
                            Text("• \(count) apps: \(errorMessage)")
                                .font(.caption)
                            // If there are few enough apps, list them
                            if count <= 3, let failedApps = errorGroups[errorMessage] {
                                ForEach(failedApps, id: \.id) { failure in
                                    Text("  - \(getAppName(for: failure.id))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .applicationsDeleted)) { notification in
            // Refresh the list after bulk deletion
            if let deletedIds = notification.object as? [String], !deletedIds.isEmpty {
                Task {
                    _ = try? await appService.fetchApplications(forceRefresh: true)
                }
            }
        }
    }

    // MARK: - Bulk Delete Helper

    private func performBulkDelete() async {
        isDeletingBulk = true
        bulkDeleteError = nil

        do {
            let appIdsToDelete = Array(selectedApplications)
            Logger.shared.info("Starting bulk deletion of \(appIdsToDelete.count) applications", category: .ui)

            let result = try await appService.deleteBatchApplications(appIdsToDelete)

            Logger.shared.info("Bulk deletion completed: \(result.successful.count) successful, \(result.failed.count) failed", category: .ui)

            bulkDeleteResult = result
        } catch {
            Logger.shared.error("Bulk delete failed: \(error.localizedDescription)", category: .ui)
            bulkDeleteError = error.localizedDescription
            bulkDeleteResult = (successful: [], failed: selectedApplications.map { ($0, error.localizedDescription) })
        }

        isDeletingBulk = false
    }

    private func getAppName(for id: String) -> String {
        appService.applications.first { $0.id == id }?.displayName ?? id
    }
}

// MARK: - Application Filters View

struct ApplicationFiltersView: View {
    @Binding var assignmentFilter: ApplicationListView.AssignmentFilter
    @Binding var selectedAssignmentIntent: ApplicationListView.AssignmentIntentFilter
    @Binding var selectedAppType: Application.AppType?
    @Binding var selectedPublisher: String?
    @Binding var selectedOwner: String?
    @Binding var selectedDeveloper: String?
    @Binding var selectedPublishingState: Application.PublishingState?
    @Binding var isFeaturedFilter: Bool?
    @Binding var selectedPlatform: Application.DevicePlatform?

    let availablePublishers: [String]
    let availableOwners: [String]
    let availableDevelopers: [String]
    let activeFilterCount: Int
    let clearFilters: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // First row: Assignment filter and main filters
            HStack(spacing: 12) {
                // Assignment Filter
                Picker("Assignment", selection: $assignmentFilter) {
                    ForEach(ApplicationListView.AssignmentFilter.allCases, id: \.self) { filter in
                        Label(filter.rawValue, systemImage: filter.systemImage).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Spacer()
            }

            // Second row: Filter chips that can wrap
            FlowLayout(spacing: 8) {
                Menu {
                    Picker("Assignment Intent", selection: $selectedAssignmentIntent) {
                        ForEach(ApplicationListView.AssignmentIntentFilter.allCases) { intent in
                            Label(intent.displayName, systemImage: intent.systemImage)
                                .tag(intent)
                        }
                    }
                } label: {
                    AppFilterChip(title: "Intent", value: selectedAssignmentIntent.chipLabel)
                }

                // App Type Filter
                Menu {
                    Button("Any", action: { selectedAppType = nil })

                    // Filter types based on selected platform
                    let typesToShow = Application.AppType.types(for: selectedPlatform)

                    if selectedPlatform == nil {
                        // Group by platform when no platform is selected
                        ForEach(Application.AppType.groupedByPlatform, id: \.platform) { group in
                            if !group.types.isEmpty {
                                Section(header: Text(group.platform.displayName)) {
                                    ForEach(group.types, id: \.self) { type in
                                        Button(action: { selectedAppType = type }) {
                                            if selectedAppType == type {
                                                Label(type.displayName, systemImage: "checkmark")
                                            } else {
                                                Text(type.displayName)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        // Add web apps separately as they're cross-platform
                        Divider()
                        Button(action: { selectedAppType = .webApp }) {
                            if selectedAppType == .webApp {
                                Label(Application.AppType.webApp.displayName, systemImage: "checkmark")
                            } else {
                                Text(Application.AppType.webApp.displayName)
                            }
                        }
                    } else {
                        // Show filtered types when platform is selected
                        ForEach(typesToShow, id: \.self) { type in
                            Button(action: { selectedAppType = type }) {
                                if selectedAppType == type {
                                    Label(type.displayName, systemImage: "checkmark")
                                } else {
                                    Text(type.displayName)
                                }
                            }
                        }
                    }
                } label: {
                    AppFilterChip(title: "Type", value: selectedAppType?.displayName)
                }

                // Platform Filter
                Menu {
                    Button("Any", action: { selectedPlatform = nil })
                    ForEach(Application.DevicePlatform.allCases.filter { $0 != .unknown }, id: \.self) { platform in
                        Button(action: { selectedPlatform = platform }) {
                            if selectedPlatform == platform {
                                Label(platform.displayName, systemImage: "checkmark")
                            } else {
                                Text(platform.displayName)
                            }
                        }
                    }
                } label: {
                    AppFilterChip(title: "Platform", value: selectedPlatform?.displayName)
                }

                // Publishing State Filter
                Menu {
                    Button("Any", action: { selectedPublishingState = nil })
                    ForEach(Application.PublishingState.allCases, id: \.self) { state in
                        Button(action: { selectedPublishingState = state }) {
                            if selectedPublishingState == state {
                                Label(state.displayName, systemImage: "checkmark")
                            } else {
                                Text(state.displayName)
                            }
                        }
                    }
                } label: {
                    AppFilterChip(title: "Publishing State", value: selectedPublishingState?.displayName)
                }

                // Featured Filter
                FilterToggle(title: "Featured", value: $isFeaturedFilter)

                // Publisher Filter (only show if there are multiple publishers)
                if availablePublishers.count > 2 {
                    Menu {
                        ForEach(availablePublishers, id: \.self) { publisher in
                            Button(action: {
                                selectedPublisher = publisher == "All" ? nil : publisher
                            }) {
                                if (publisher == "All" && selectedPublisher == nil) ||
                                   selectedPublisher == publisher {
                                    Label(publisher, systemImage: "checkmark")
                                } else {
                                    Text(publisher)
                                }
                            }
                        }
                    } label: {
                        AppFilterChip(title: "Publisher", value: selectedPublisher)
                    }
                }

                // Owner Filter (only show if there are multiple owners)
                if availableOwners.count > 2 {
                    Menu {
                        ForEach(availableOwners, id: \.self) { owner in
                            Button(action: {
                                selectedOwner = owner == "All" ? nil : owner
                            }) {
                                if (owner == "All" && selectedOwner == nil) ||
                                   selectedOwner == owner {
                                    Label(owner, systemImage: "checkmark")
                                } else {
                                    Text(owner)
                                }
                            }
                        }
                    } label: {
                        AppFilterChip(title: "Owner", value: selectedOwner)
                    }
                }

                // Developer Filter (only show if there are multiple developers)
                if availableDevelopers.count > 2 {
                    Menu {
                        ForEach(availableDevelopers, id: \.self) { developer in
                            Button(action: {
                                selectedDeveloper = developer == "All" ? nil : developer
                            }) {
                                if (developer == "All" && selectedDeveloper == nil) ||
                                   selectedDeveloper == developer {
                                    Label(developer, systemImage: "checkmark")
                                } else {
                                    Text(developer)
                                }
                            }
                        }
                    } label: {
                        AppFilterChip(title: "Developer", value: selectedDeveloper)
                    }
                }

                // Clear All Filters
                if activeFilterCount > 0 {
                    Button(action: clearFilters) {
                        Label("Clear All", systemImage: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

// Simple row view for the application list (without selection/toggle functionality)
struct ApplicationListRowView: View {
    let application: Application

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(application.displayName)
                        .font(.system(.body, design: .default))
                        .lineLimit(1)

                    // Assignment indicator badge
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
                    }
                }

                HStack {
                    Label(application.appType.displayName, systemImage: application.appType.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)

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
                    assignmentIntentBadges
                }
            }

            Spacer()

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

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var assignmentIntentBadges: some View {
        let intents = application.assignmentIntents().sorted { lhs, rhs in
            lhs.displayOrder < rhs.displayOrder
        }

        if !intents.isEmpty {
            HStack(spacing: 6) {
                ForEach(intents, id: \.self) { intent in
                    let colors = intent.badgeColors
                    Label(intent.badgeTitle, systemImage: intent.icon)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(colors.background)
                        .foregroundColor(colors.foreground)
                        .cornerRadius(6)
                        .help(intent.detailedDescription)
                }
            }
        }
    }
}

struct AppFilterChip: View {
    let title: String
    let value: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if let value = value {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Helpers

private extension Application {
    func assignmentIntents(groupOnly: Bool = false) -> [AppAssignment.AssignmentIntent] {
        guard let assignments = assignments else { return [] }
        let intents = assignments.compactMap { assignment -> AppAssignment.AssignmentIntent? in
            if groupOnly && assignment.target.type != .group {
                return nil
            }
            return assignment.intent
        }
        let unique = Set(intents)
        return AppAssignment.AssignmentIntent.allCases.filter { unique.contains($0) }
    }

    func hasAssignment(intent: AppAssignment.AssignmentIntent, groupOnly: Bool = false) -> Bool {
        assignments?.contains(where: { assignment in
            (!groupOnly || assignment.target.type == .group) && assignment.intent == intent
        }) ?? false
    }
}

private extension AppAssignment.AssignmentIntent {
    var badgeTitle: String {
        switch self {
        case .required: return "Install"
        case .available: return "Available"
        case .uninstall: return "Uninstall"
        case .availableWithoutEnrollment: return "Optional"
        }
    }

    var displayOrder: Int {
        switch self {
        case .required: return 0
        case .available: return 1
        case .availableWithoutEnrollment: return 2
        case .uninstall: return 3
        }
    }

    var badgeColors: (background: Color, foreground: Color) {
        switch self {
        case .required:
            return (Color.green.opacity(0.15), Color.green)
        case .available:
            return (Color.blue.opacity(0.15), Color.blue)
        case .availableWithoutEnrollment:
            return (Color.purple.opacity(0.15), Color.purple)
        case .uninstall:
            return (Color.red.opacity(0.15), Color.red)
        }
    }
}
