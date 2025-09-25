import SwiftUI

struct ApplicationListView: View {
    @StateObject private var appService = ApplicationService.shared
    @State private var searchText = ""
    @State private var assignmentFilter: AssignmentFilter = .all
    @State private var showFilters = false

    // Filter states
    @State private var selectedAppType: Application.AppType?
    @State private var selectedPublisher: String?
    @State private var selectedOwner: String?
    @State private var selectedDeveloper: String?
    @State private var selectedPublishingState: Application.PublishingState?
    @State private var isFeaturedFilter: Bool?
    @State private var selectedPlatform: Application.DevicePlatform?

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

    var body: some View {
        Group {
            if appService.isLoading && appService.applications.isEmpty {
                ProgressView("Loading applications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Filters view
                    if showFilters {
                        ApplicationFiltersView(
                            assignmentFilter: $assignmentFilter,
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
                    }

                    // Status bar
                    HStack {
                        Text("\(filteredApplications.count) of \(appService.applications.count) applications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 12) {
                            Label("\(appService.applications.filter { !$0.hasAssignments }.count) unassigned", systemImage: "square")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Label("\(appService.applications.filter { $0.hasAssignments }.count) assigned", systemImage: "checkmark.square")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("(\(appService.applications.count) total)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    List(filteredApplications) { app in
                        NavigationLink(destination: ApplicationDetailView(application: app)) {
                            ApplicationListRowView(application: app)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search by name or publisher")
                }
            }
        }
        .navigationTitle("Applications")
        .toolbar {
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
    }
}

// MARK: - Application Filters View

struct ApplicationFiltersView: View {
    @Binding var assignmentFilter: ApplicationListView.AssignmentFilter
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
                // App Type Filter
                Menu {
                    Button("Any", action: { selectedAppType = nil })
                    ForEach(Application.AppType.allCases, id: \.self) { type in
                        Button(action: { selectedAppType = type }) {
                            if selectedAppType == type {
                                Label(type.displayName, systemImage: "checkmark")
                            } else {
                                Text(type.displayName)
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
