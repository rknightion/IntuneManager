import SwiftUI
import UniformTypeIdentifiers
import Combine

struct MobileConfigUploadView: View {
    @StateObject private var viewModel = MobileConfigUploadViewModel()
    @State private var selectedPlatform: ConfigurationProfile.PlatformType = .iOS
    @State private var showingFilePicker = false
    @State private var showingAssignments = false
    @State private var dragOver = false
    @State private var uploadedConfigInfo: MobileConfigInfo?
    @State private var selectedGroups = Set<String>()
    @State private var includeAllUsers = false
    @State private var includeAllDevices = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Platform Selection
                    platformSelectionCard

                    // Upload Section
                    uploadSection

                    // Config Details (if uploaded)
                    if let configInfo = uploadedConfigInfo {
                        configDetailsCard(configInfo)
                    }

                    // Assignment Section
                    if uploadedConfigInfo != nil {
                        assignmentSection
                    }

                    // Deploy Button
                    if uploadedConfigInfo != nil {
                        deploySection
                    }
                }
                .padding()
            }
            .navigationTitle("Deploy .mobileconfig Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.propertyList, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showingAssignments) {
                assignmentSelectionSheet
            }
            .alert("Deploy Profile", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
            .task {
                await viewModel.loadGroups()
            }
        }
    }

    var platformSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Select Platform", systemImage: "apps.iphone")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach([ConfigurationProfile.PlatformType.iOS, .macOS], id: \.self) { platform in
                    PlatformSelectionButton(
                        platform: platform,
                        isSelected: selectedPlatform == platform
                    ) {
                        selectedPlatform = platform
                    }
                }
            }

            Text("Choose the platform this profile targets")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var uploadSection: some View {
        VStack(spacing: 16) {
            Label("Upload Configuration Profile", systemImage: "doc.badge.arrow.up")
                .font(.headline)

            // Drop Zone
            VStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(dragOver ? .accentColor : .secondary)

                Text("Drop .mobileconfig file here or click to browse")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { showingFilePicker = true }) {
                    Label("Choose File...", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(dragOver ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: dragOver ? [] : [5]
                        )
                    )
                    .foregroundColor(dragOver ? .accentColor : .gray.opacity(0.3))
            )
            .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
                handleDrop(providers: providers)
                return true
            }

            if viewModel.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing profile...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    func configDetailsCard(_ configInfo: MobileConfigInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Profile Validated")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ConfigDetailRow(label: "Name", value: configInfo.displayName)
                ConfigDetailRow(label: "Identifier", value: configInfo.identifier)
                if !configInfo.description.isEmpty {
                    ConfigDetailRow(label: "Description", value: configInfo.description)
                }
                ConfigDetailRow(label: "Organization", value: configInfo.organization)
                ConfigDetailRow(label: "Payloads", value: "\(configInfo.payloadCount)")
                ConfigDetailRow(label: "Version", value: "\(configInfo.version)")
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Assignments", systemImage: "person.2")
                .font(.headline)

            // Quick Assignment Options
            VStack(spacing: 12) {
                Toggle("All Users", isOn: $includeAllUsers)
                    .onChange(of: includeAllUsers) { newValue in
                        if newValue {
                            includeAllDevices = false
                        }
                    }

                Toggle("All Devices", isOn: $includeAllDevices)
                    .onChange(of: includeAllDevices) { newValue in
                        if newValue {
                            includeAllUsers = false
                        }
                    }
            }

            if !includeAllUsers && !includeAllDevices {
                Button(action: { showingAssignments = true }) {
                    HStack {
                        Image(systemName: "person.2.badge.plus")
                        Text("Select Groups (\(selectedGroups.count))")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.bordered)

                if !selectedGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(selectedGroups), id: \.self) { groupId in
                            if let group = viewModel.groups.first(where: { $0.id == groupId }) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(group.displayName)
                                        .font(.caption)
                                    Spacer()
                                    Button(action: {
                                        selectedGroups.remove(groupId)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var deploySection: some View {
        VStack(spacing: 12) {
            if viewModel.uploadProgress > 0 && viewModel.uploadProgress < 1 {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.uploadProgress)
                    Text("Deploying profile...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: deployProfile) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Deploy Profile")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isUploading || !hasValidAssignment)
        }
    }

    var assignmentSelectionSheet: some View {
        NavigationStack {
            List(viewModel.groups) { group in
                HStack {
                    VStack(alignment: .leading) {
                        Text(group.displayName)
                            .font(.body)
                        if let description = group.groupDescription {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if selectedGroups.contains(group.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedGroups.contains(group.id) {
                        selectedGroups.remove(group.id)
                    } else {
                        selectedGroups.insert(group.id)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search groups")
            .navigationTitle("Select Groups")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingAssignments = false
                    }
                }
            }
        }
    }

    var hasValidAssignment: Bool {
        includeAllUsers || includeAllDevices || !selectedGroups.isEmpty
    }

    // MARK: - Actions

    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await processFile(url: url)
            }
        case .failure(let error):
            alertMessage = "Failed to import file: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.alertMessage = "Drop failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
                return
            }

            guard let url = item as? URL else { return }

            Task {
                await self.processFile(url: url)
            }
        }
    }

    func processFile(url: URL) async {
        do {
            let data = try Data(contentsOf: url)
            let configInfo = try await viewModel.processConfigFile(data: data)
            await MainActor.run {
                self.uploadedConfigInfo = configInfo
            }
        } catch {
            await MainActor.run {
                self.alertMessage = "Failed to process file: \(error.localizedDescription)"
                self.showingAlert = true
            }
        }
    }

    func deployProfile() {
        guard let configInfo = uploadedConfigInfo else { return }

        Task {
            do {
                // Build assignments
                var assignments: [ConfigurationAssignment] = []

                if includeAllUsers {
                    assignments.append(ConfigurationAssignment(
                        profileId: "", // Will be set by the service
                        target: ConfigurationAssignment.AssignmentTarget(
                            type: .allUsers,
                            groupId: nil,
                            groupName: "All Users"
                        )
                    ))
                } else if includeAllDevices {
                    assignments.append(ConfigurationAssignment(
                        profileId: "", // Will be set by the service
                        target: ConfigurationAssignment.AssignmentTarget(
                            type: .allDevices,
                            groupId: nil,
                            groupName: "All Devices"
                        )
                    ))
                } else {
                    for groupId in selectedGroups {
                        if let group = viewModel.groups.first(where: { $0.id == groupId }) {
                            assignments.append(ConfigurationAssignment(
                                profileId: "", // Will be set by the service
                                target: ConfigurationAssignment.AssignmentTarget(
                                    type: .group,
                                    groupId: groupId,
                                    groupName: group.displayName
                                )
                            ))
                        }
                    }
                }

                let profile = try await viewModel.deployConfig(
                    configInfo: configInfo,
                    platform: selectedPlatform,
                    assignments: assignments
                )

                await MainActor.run {
                    self.alertMessage = "Successfully deployed '\(profile.displayName)'"
                    self.showingAlert = true

                    // Dismiss after alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Deployment failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
}

struct PlatformSelectionButton: View {
    let platform: ConfigurationProfile.PlatformType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: platformIcon)
                    .font(.title2)
                Text(platform.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    var platformIcon: String {
        switch platform {
        case .iOS:
            return "iphone"
        case .macOS:
            return "desktopcomputer"
        default:
            return "apps.iphone"
        }
    }
}

struct ConfigDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

// MARK: - View Model

@MainActor
final class MobileConfigUploadViewModel: ObservableObject {
    @Published var groups: [DeviceGroup] = []
    @Published var isProcessing = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var searchText = ""

    private let mobileConfigService = MobileConfigService.shared
    private let groupService = GroupService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe upload progress from service
        mobileConfigService.$uploadProgress
            .assign(to: &$uploadProgress)

        mobileConfigService.$isUploading
            .assign(to: &$isUploading)
    }

    var filteredGroups: [DeviceGroup] {
        if searchText.isEmpty {
            return groups
        }
        return groups.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadGroups() async {
        do {
            groups = try await groupService.fetchGroups()
        } catch {
            Logger.shared.error("Failed to load groups: \(error)", category: .data)
        }
    }

    func processConfigFile(data: Data) async throws -> MobileConfigInfo {
        isProcessing = true
        defer { isProcessing = false }

        return try mobileConfigService.validateMobileConfig(data: data)
    }

    func deployConfig(
        configInfo: MobileConfigInfo,
        platform: ConfigurationProfile.PlatformType,
        assignments: [ConfigurationAssignment]
    ) async throws -> ConfigurationProfile {
        return try await mobileConfigService.createCustomProfile(
            from: configInfo,
            platform: platform,
            assignments: assignments
        )
    }
}