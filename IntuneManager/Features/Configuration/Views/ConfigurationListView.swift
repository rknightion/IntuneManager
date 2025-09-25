import SwiftUI

struct ConfigurationListView: View {
    @StateObject private var viewModel = ConfigurationViewModel()
    @State private var selectedProfile: ConfigurationProfile?
    @State private var showingCreateProfile = false
    @State private var searchText = ""
    @State private var selectedPlatform: ConfigurationProfile.PlatformType? = nil
    @State private var selectedType: ConfigurationProfile.ProfileType? = nil
    @State private var showingEditProfile = false
    @State private var showingDeleteConfirmation = false
    @State private var profileToDelete: ConfigurationProfile?
    @State private var showingImportExport = false
    @State private var showingMobileConfigUpload = false

    var filteredProfiles: [ConfigurationProfile] {
        var profiles = viewModel.profiles

        // Filter by search text
        if !searchText.isEmpty {
            profiles = profiles.filter { profile in
                profile.displayName.localizedCaseInsensitiveContains(searchText) ||
                (profile.profileDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Filter by platform
        if let platform = selectedPlatform {
            profiles = profiles.filter { $0.platformType == platform }
        }

        // Filter by type
        if let profileType = selectedType {
            profiles = profiles.filter { $0.profileType == profileType }
        }

        return profiles.sorted { $0.displayName < $1.displayName }
    }

    var profilesByPlatform: [ConfigurationProfile.PlatformType: [ConfigurationProfile]] {
        Dictionary(grouping: filteredProfiles) { $0.platformType }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 450)
        } detail: {
            if let profile = selectedProfile {
                ConfigurationDetailView(profile: profile)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Select a Configuration Profile",
                    systemImage: "gearshape.2",
                    description: Text("Choose a profile from the list to view its details and assignments")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Configuration Profiles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateProfile = true }) {
                    Label("Create Profile", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { showingMobileConfigUpload = true }) {
                    Label("Upload .mobileconfig", systemImage: "doc.badge.arrow.up")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { showingImportExport = true }) {
                    Label("Import/Export", systemImage: "square.and.arrow.up.on.square")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await viewModel.loadProfiles(forceRefresh: true) } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .sheet(isPresented: $showingCreateProfile) {
            ProfileCreationView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .sheet(isPresented: $showingEditProfile) {
            if let profile = selectedProfile {
                ProfileEditView(profile: profile)
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .sheet(isPresented: $showingImportExport) {
            ProfileImportExportView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .sheet(isPresented: $showingMobileConfigUpload) {
            MobileConfigUploadView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .alert("Delete Configuration Profile", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    Task {
                        await deleteProfile(profile)
                    }
                }
            }
        } message: {
            if let profile = profileToDelete {
                Text("Are you sure you want to delete '\(profile.displayName)'? This action cannot be undone.")
            }
        }
        .task {
            await viewModel.loadProfiles()
        }
    }

    var sidebarContent: some View {
        VStack(spacing: 0) {
            // Search and filters
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search profiles...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // Platform filter with wrapping
                FlowLayout(spacing: 8) {
                    ConfigurationFilterChip(
                        title: "All",
                        isSelected: selectedPlatform == nil,
                        action: { selectedPlatform = nil }
                    )

                    ForEach(ConfigurationProfile.PlatformType.allCases, id: \.self) { platform in
                        ConfigurationFilterChip(
                            title: platform.displayName,
                            icon: platform.icon,
                            isSelected: selectedPlatform == platform,
                            action: { selectedPlatform = platform }
                        )
                    }
                }

                // Type filter with wrapping
                FlowLayout(spacing: 8) {
                    ConfigurationFilterChip(
                        title: "All Types",
                        isSelected: selectedType == nil,
                        action: { selectedType = nil }
                    )

                    ForEach(ConfigurationProfile.ProfileType.allCases, id: \.self) { type in
                        ConfigurationFilterChip(
                            title: type.displayName,
                            icon: type.icon,
                            isSelected: selectedType == type,
                            action: { selectedType = type }
                        )
                    }
                }
            }
            .padding()
            .background(Theme.Colors.secondaryBackground)

            Divider()

            // Profiles list
            if viewModel.isLoading && viewModel.profiles.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading profiles...")
                    Spacer()
                }
            } else if filteredProfiles.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Configuration Profiles" : "No Results",
                        systemImage: searchText.isEmpty ? "gearshape.2" : "magnifyingglass",
                        description: Text(searchText.isEmpty ?
                            "Create your first configuration profile to get started" :
                            "No profiles match '\(searchText)'")
                    )
                    Spacer()
                }
            } else {
                List(selection: $selectedProfile) {
                    ForEach(ConfigurationProfile.PlatformType.allCases, id: \.self) { platform in
                        if let profiles = profilesByPlatform[platform], !profiles.isEmpty {
                            Section(header: Label(platform.displayName, systemImage: platform.icon)) {
                                ForEach(profiles) { profile in
                                    ProfileRowView(profile: profile)
                                        .tag(profile)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 300, idealWidth: 350)
    }

    // MARK: - Actions

    private func deleteProfile(_ profile: ConfigurationProfile) async {
        await viewModel.deleteProfile(profile)
        profileToDelete = nil
        if selectedProfile?.id == profile.id {
            selectedProfile = nil
        }
    }
}

struct ProfileRowView: View {
    let profile: ConfigurationProfile

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(profile.displayName)
                        .font(.headline)
                    if profile.isAssigned {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                HStack {
                    Label(profile.profileType.displayName, systemImage: profile.profileType.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let templateName = profile.templateDisplayName {
                        Text("• \(templateName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if let description = profile.profileDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                if let assignmentCount = profile.assignments?.count, assignmentCount > 0 {
                    Label("\(assignmentCount)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConfigurationFilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(15)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ConfigurationListView()
        .environmentObject(AppState())
}