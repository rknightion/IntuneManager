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
            case .selectApps: return "Select Applications"
            case .selectGroups: return "Select Groups"
            case .configureSettings: return "Configure Settings"
            case .review: return "Review & Confirm"
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
                    GroupSelectionView(selectedGroups: $viewModel.selectedGroups)
                case .configureSettings:
                    AssignmentSettingsView(
                        intent: $viewModel.assignmentIntent,
                        settings: $viewModel.assignmentSettings
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

                Text("\(viewModel.totalAssignments) assignments")
                    .font(.caption)
                    .foregroundColor(.secondary)

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
        .navigationTitle("Bulk Assignment")
        #if os(macOS)
        .navigationSubtitle("\(currentStep.title)")
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
                currentStep = nextStep
            }
        }
    }

    private func previousStep() {
        withAnimation {
            if let previousStep = AssignmentStep(rawValue: currentStep.rawValue - 1) {
                currentStep = previousStep
            }
        }
    }

    private func performAssignment() {
        showingConfirmation = true
    }

    private func executeAssignment() {
        showingProgress = true
        Task {
            await viewModel.executeAssignment()
            showingProgress = false
            resetAssignment()
        }
    }

    private func resetAssignment() {
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
    @State private var sortOrder: SortOrder = .name

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
        case modified = "Modified"

        var comparator: (Application, Application) -> Bool {
            switch self {
            case .name:
                return { $0.displayName < $1.displayName }
            case .type:
                return { $0.appType.displayName < $1.appType.displayName }
            case .modified:
                return { $0.lastModifiedDateTime > $1.lastModifiedDateTime }
            }
        }
    }

    var filteredApps: [Application] {
        var apps = appService.applications

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
            // Toolbar
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
                .frame(width: 100)

                Spacer()

                Text("\(selectedApps.count) selected")
                    .foregroundColor(.secondary)

                Button("Select All") {
                    selectedApps = Set(filteredApps)
                }

                Button("Clear") {
                    selectedApps.removeAll()
                }
                .disabled(selectedApps.isEmpty)
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
        .onAppear {
            Task {
                if appService.applications.isEmpty {
                    do {
                        _ = try await appService.fetchApplications()
                    } catch {
                        Logger.shared.error("Failed to load applications: \(error)")
                    }
                }
            }
        }
    }
}

struct ApplicationRowView: View {
    let application: Application
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(application.displayName)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)

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
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onTapGesture {
            onToggle()
        }
    }
}
