import SwiftUI

struct AuditLogDetailView: View {
    let log: AuditLog
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = "overview"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with activity name and status
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: activityIcon)
                                .font(.title2)
                                .foregroundColor(.accentColor)

                            Text(log.activity ?? log.displayName ?? "Audit Event")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Spacer()

                            if let result = log.activityResult {
                                Text(result.capitalized)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(statusColor.opacity(0.2))
                                    .foregroundColor(statusColor)
                                    .cornerRadius(8)
                            }
                        }

                        if let date = log.activityDateTime {
                            Label(date.formatted(date: .abbreviated, time: .standard), systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)

                    // Tab selector
                    Picker("View", selection: $selectedTab) {
                        Text("Overview").tag("overview")
                        Text("Actor Details").tag("actor")
                        if !(log.resources?.isEmpty ?? true) {
                            Text("Resources").tag("resources")
                        }
                        Text("Technical").tag("technical")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Tab content
                    switch selectedTab {
                    case "overview":
                        overviewSection
                    case "actor":
                        actorSection
                    case "resources":
                        resourcesSection
                    case "technical":
                        technicalSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Audit Log Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailRow(label: "Activity", value: log.activity ?? "N/A")
            DetailRow(label: "Display Name", value: log.displayName ?? "N/A")
            DetailRow(label: "Component", value: log.componentName ?? "N/A")
            DetailRow(label: "Category", value: log.category ?? "N/A")
            DetailRow(label: "Activity Type", value: log.activityType ?? "N/A")
            DetailRow(label: "Operation Type", value: log.activityOperationType ?? "N/A")
            DetailRow(label: "Result", value: log.activityResult ?? "N/A", color: statusColor)

            if let date = log.activityDateTime {
                DetailRow(label: "Date & Time", value: date.formatted(date: .complete, time: .complete))
                DetailRow(label: "Time Ago", value: date.formatted(.relative(presentation: .named)))
            }
        }
        .padding(.horizontal)
    }

    private var actorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let actor = log.actor {
                DetailRow(label: "User Principal Name", value: actor.userPrincipalName ?? "N/A")
                DetailRow(label: "User ID", value: actor.userId ?? "N/A")
                DetailRow(label: "Application", value: actor.applicationDisplayName ?? "N/A")
                DetailRow(label: "Application ID", value: actor.applicationId ?? "N/A")
                DetailRow(label: "Service Principal", value: actor.servicePrincipalName ?? "N/A")
                DetailRow(label: "IP Address", value: actor.ipAddress ?? "N/A")
                DetailRow(label: "Actor Type", value: actor.auditActorType ?? actor.type ?? "N/A")

                if let permissions = actor.userPermissions, !permissions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permissions")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        ForEach(permissions, id: \.self) { permission in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(permission)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            } else {
                Text("No actor information available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding(.horizontal)
    }

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let resources = log.resources, !resources.isEmpty {
                ForEach(Array(resources.enumerated()), id: \.offset) { index, resource in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Resource \(index + 1)", systemImage: "folder.circle.fill")
                                .font(.headline)
                            Spacer()
                        }

                        DetailRow(label: "Display Name", value: resource.displayName ?? "N/A")
                        DetailRow(label: "Type", value: resource.type ?? "N/A")
                        DetailRow(label: "Resource Type", value: resource.auditResourceType ?? "N/A")
                        DetailRow(label: "Resource ID", value: resource.resourceId ?? "N/A")

                        if let properties = resource.modifiedProperties, !properties.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Modified Properties", systemImage: "pencil.circle")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)

                                ForEach(Array(properties.enumerated()), id: \.offset) { _, property in
                                    PropertyChangeView(property: property)
                                }
                            }
                        }

                        if index < resources.count - 1 {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.03))
                    .cornerRadius(8)
                }
            } else {
                Text("No resource information available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding(.horizontal)
    }

    private var technicalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailRow(label: "Event ID", value: log.id)

            if let correlationId = log.correlationId {
                DetailRow(label: "Correlation ID", value: correlationId)
            }

            // Show raw JSON representation
            if let jsonData = try? JSONEncoder().encode(log),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Raw JSON", systemImage: "doc.text")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal) {
                        Text(prettyPrintJSON(jsonString))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helper Properties

    private var statusColor: Color {
        switch log.activityResult?.lowercased() {
        case "success": return .green
        case "failure", "failed": return .red
        case "pending": return .orange
        default: return .blue
        }
    }

    private var activityIcon: String {
        if let type = log.activityType?.lowercased() {
            if type.contains("create") || type.contains("add") {
                return "plus.circle.fill"
            } else if type.contains("update") || type.contains("edit") || type.contains("modify") {
                return "pencil.circle.fill"
            } else if type.contains("delete") || type.contains("remove") {
                return "trash.circle.fill"
            } else if type.contains("assign") {
                return "person.2.circle.fill"
            } else if type.contains("sync") {
                return "arrow.triangle.2.circlepath.circle.fill"
            }
        }
        return "circle.fill"
    }

    private func prettyPrintJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let label: String
    let value: String
    var color: Color?

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundColor(color ?? .primary)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct PropertyChangeView: View {
    let property: AuditProperty

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(property.displayName ?? "Property")
                .font(.subheadline)
                .fontWeight(.medium)

            if let oldValue = property.oldValue {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Old Value")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(oldValue)
                            .font(.caption)
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                    }
                    Spacer()
                }
            }

            if let newValue = property.newValue {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Value")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(newValue)
                            .font(.caption)
                            .foregroundColor(.green)
                            .textSelection(.enabled)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.03))
        .cornerRadius(8)
    }
}