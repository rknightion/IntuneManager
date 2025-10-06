import SwiftUI

struct ConfigurationDetailView: View {
    let profile: ConfigurationProfile
    @State private var showingAssignmentEditor = false
    @State private var showingStatusView = false
    @State private var showingValidation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Info Section
                infoSection

                // Assignments Section
                assignmentsSection

                // Settings Section (placeholder for future)
                if let settings = profile.settings, !settings.isEmpty {
                    settingsSection(settings: settings)
                }

                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle(profile.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingAssignmentEditor = true }) {
                        Label("Manage Assignments", systemImage: "person.2")
                    }

                    Button(action: { showingValidation = true }) {
                        Label("Validate Profile", systemImage: "checkmark.shield")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAssignmentEditor) {
            ConfigurationAssignmentView(profile: profile)
        }
        .sheet(isPresented: $showingStatusView) {
            NavigationStack {
                ProfileStatusView(profile: profile)
            }
            .frame(minWidth: 900, minHeight: 700)
        }
        .sheet(isPresented: $showingValidation) {
            ProfileValidationView(profile: profile)
                .frame(minWidth: 700, minHeight: 600)
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: profile.profileType.icon)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text(profile.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let description = profile.profileDescription, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if profile.isAssigned {
                    Label("Assigned", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(15)
                }
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Information")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InfoCard(
                    title: "Platform",
                    value: profile.platformType.displayName,
                    icon: profile.platformType.icon
                )

                InfoCard(
                    title: "Type",
                    value: profile.profileType.displayName,
                    icon: profile.profileType.icon
                )

                InfoCard(
                    title: "Created",
                    value: profile.createdDateTime.formatted(date: .abbreviated, time: .shortened),
                    icon: "calendar"
                )

                InfoCard(
                    title: "Modified",
                    value: profile.lastModifiedDateTime.formatted(date: .abbreviated, time: .shortened),
                    icon: "clock"
                )

                if let templateName = profile.templateDisplayName {
                    InfoCard(
                        title: "Template",
                        value: templateName,
                        icon: "doc.text"
                    )
                }

                InfoCard(
                    title: "Version",
                    value: "\(profile.version)",
                    icon: "number"
                )
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Assignments")
                    .font(.headline)

                Spacer()

                Button(action: { showingAssignmentEditor = true }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            if let assignments = profile.assignments, !assignments.isEmpty {
                ForEach(assignments) { assignment in
                    AssignmentRow(assignment: assignment)
                }
            } else {
                HStack {
                    Image(systemName: "person.2.slash")
                        .foregroundColor(.secondary)
                    Text("No assignments configured")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Add Assignments") {
                        showingAssignmentEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    func settingsSection(settings: [ConfigurationSetting]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration Settings")
                .font(.headline)

            Text("\(settings.count) settings configured")
                .font(.caption)
                .foregroundColor(.secondary)

            // Placeholder for future settings display
            ForEach(settings.prefix(5)) { setting in
                HStack {
                    Image(systemName: setting.valueType.icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 20)

                    VStack(alignment: .leading) {
                        Text(setting.displayName)
                            .font(.subheadline)
                        if let description = setting.settingDescription {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if setting.isRequired {
                        Text("Required")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
            }

            if settings.count > 5 {
                Text("+ \(settings.count - 5) more settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: { showingStatusView = true }) {
                Label("View Deployment Status", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: { showingAssignmentEditor = true }) {
                Label("Manage Assignments", systemImage: "person.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct AssignmentRow: View {
    let assignment: ConfigurationAssignment

    var body: some View {
        HStack {
            Image(systemName: assignment.target.type == .exclusionGroup ? "person.2.slash" : "person.2")
                .foregroundColor(assignment.target.type == .exclusionGroup ? .red : .blue)

            VStack(alignment: .leading) {
                Text(assignment.target.groupName ?? assignment.target.type.rawValue)
                    .font(.subheadline)

                HStack {
                    Text(assignment.target.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let filter = assignment.filter {
                        Text("• \(filter.filterType.rawValue) filter")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
