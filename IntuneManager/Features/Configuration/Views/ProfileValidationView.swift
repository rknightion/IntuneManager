import SwiftUI
import Combine

struct ProfileValidationView: View {
    let profile: ConfigurationProfile
    @StateObject private var viewModel = ProfileValidationViewModel()
    @State private var showingConflictDetails = false
    @State private var selectedConflict: ProfileConflict?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Validation Summary
                    validationSummaryCard

                    // Errors Section
                    if !(viewModel.validationReport?.errors.isEmpty ?? true) {
                        errorsSection
                    }

                    // Warnings Section
                    if !(viewModel.validationReport?.warnings.isEmpty ?? true) {
                        warningsSection
                    }

                    // Conflicts Section
                    if !(viewModel.conflictReport?.conflicts.isEmpty ?? true) {
                        conflictsSection
                    }

                    // Recommendations
                    if viewModel.hasIssues {
                        recommendationsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Profile Validation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { Task { await viewModel.revalidate() } }) {
                        Label("Revalidate", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await viewModel.validateProfile(profile)
            }
            .sheet(item: $selectedConflict) { conflict in
                ConflictDetailView(conflict: conflict)
                    .frame(minWidth: 600, minHeight: 400)
            }
        }
    }

    var validationSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: viewModel.validationIcon)
                    .font(.largeTitle)
                    .foregroundColor(viewModel.validationColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.validationStatus)
                        .font(.headline)

                    Text("Profile: \(profile.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            HStack(spacing: 20) {
                ValidationMetric(
                    value: viewModel.errorCount,
                    label: "Errors",
                    color: .red,
                    icon: "xmark.circle.fill"
                )

                ValidationMetric(
                    value: viewModel.warningCount,
                    label: "Warnings",
                    color: .orange,
                    icon: "exclamationmark.triangle.fill"
                )

                ValidationMetric(
                    value: viewModel.conflictCount,
                    label: "Conflicts",
                    color: .purple,
                    icon: "exclamationmark.2"
                )
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var errorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Errors", systemImage: "xmark.circle.fill")
                .font(.headline)
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.validationReport?.errors ?? [], id: \.field) { error in
                    ErrorRow(error: error)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }

    var warningsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Warnings", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.validationReport?.warnings ?? [], id: \.field) { warning in
                    WarningRow(warning: warning)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }

    var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Profile Conflicts", systemImage: "exclamationmark.2")
                .font(.headline)
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.conflictReport?.conflicts ?? []) { conflict in
                    ConflictRow(conflict: conflict) {
                        selectedConflict = conflict
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)
        }
    }

    var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recommendations", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct ValidationMetric: View {
    let value: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)

            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ErrorRow: View {
    let error: ValidationError

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: severityIcon)
                .foregroundColor(.red)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.field)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(severityText)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
        }
    }

    var severityIcon: String {
        switch error.severity {
        case .critical:
            return "exclamationmark.octagon.fill"
        case .high:
            return "exclamationmark.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .low:
            return "info.circle.fill"
        }
    }

    var severityText: String {
        switch error.severity {
        case .critical:
            return "Critical"
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }
}

struct WarningRow: View {
    let warning: ValidationWarning

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(warning.field)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(warning.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct ConflictRow: View {
    let conflict: ProfileConflict
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top) {
                Image(systemName: conflictTypeIcon)
                    .foregroundColor(.purple)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.conflictingProfileName)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text(conflict.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }

    var conflictTypeIcon: String {
        switch conflict.type {
        case .assignmentOverlap:
            return "person.2.fill"
        case .settingConflict:
            return "gearshape.2.fill"
        case .duplicate:
            return "doc.on.doc.fill"
        }
    }
}

struct ConflictDetailView: View {
    let conflict: ProfileConflict
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Conflict Header
                HStack {
                    Image(systemName: conflictIcon)
                        .font(.largeTitle)
                        .foregroundColor(severityColor)

                    VStack(alignment: .leading) {
                        Text(conflictTypeText)
                            .font(.headline)

                        Text("With: \(conflict.conflictingProfileName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Divider()

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)

                    Text(conflict.description)
                        .font(.body)
                }

                // Resolution
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Resolution")
                        .font(.headline)

                    Text(conflict.resolution)
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                // Severity
                HStack {
                    Text("Severity:")
                        .font(.headline)

                    Text(severityText)
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(severityColor.opacity(0.2))
                        .cornerRadius(4)

                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Conflict Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    var conflictIcon: String {
        switch conflict.type {
        case .assignmentOverlap:
            return "person.2.fill"
        case .settingConflict:
            return "gearshape.2.fill"
        case .duplicate:
            return "doc.on.doc.fill"
        }
    }

    var conflictTypeText: String {
        switch conflict.type {
        case .assignmentOverlap:
            return "Assignment Overlap"
        case .settingConflict:
            return "Setting Conflict"
        case .duplicate:
            return "Duplicate Profile"
        }
    }

    var severityColor: Color {
        switch conflict.severity {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low, .warning:
            return .yellow
        }
    }

    var severityText: String {
        switch conflict.severity {
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        case .warning:
            return "Warning"
        }
    }
}

// MARK: - View Model

@MainActor
final class ProfileValidationViewModel: ObservableObject {
    @Published var validationReport: ProfileValidationReport?
    @Published var conflictReport: ConflictDetectionReport?
    @Published var isLoading = false
    @Published var error: Error?

    private var profile: ConfigurationProfile?
    private let validationService = ProfileValidationService.shared
    private let configurationService = ConfigurationService.shared

    var errorCount: Int {
        validationReport?.errors.count ?? 0
    }

    var warningCount: Int {
        validationReport?.warnings.count ?? 0
    }

    var conflictCount: Int {
        conflictReport?.conflicts.count ?? 0
    }

    var hasIssues: Bool {
        errorCount > 0 || warningCount > 0 || conflictCount > 0
    }

    var validationStatus: String {
        if isLoading {
            return "Validating..."
        } else if validationReport?.isValid == false {
            return "Validation Failed"
        } else if conflictCount > 0 {
            return "Conflicts Detected"
        } else if warningCount > 0 {
            return "Validation Passed with Warnings"
        } else {
            return "Validation Passed"
        }
    }

    var validationIcon: String {
        if validationReport?.isValid == false {
            return "xmark.circle.fill"
        } else if conflictCount > 0 {
            return "exclamationmark.2"
        } else if warningCount > 0 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    var validationColor: Color {
        if validationReport?.isValid == false {
            return .red
        } else if conflictCount > 0 {
            return .purple
        } else if warningCount > 0 {
            return .orange
        } else {
            return .green
        }
    }

    var recommendations: [String] {
        var recs: [String] = []

        if errorCount > 0 {
            recs.append("Fix all critical errors before deploying this profile")
        }

        if conflictCount > 0 {
            recs.append("Review and resolve conflicts with existing profiles")
        }

        if warningCount > 0 {
            recs.append("Consider addressing warnings to improve profile quality")
        }

        if validationReport?.errors.contains(where: { $0.field.contains("assignments") }) == true {
            recs.append("Verify assignment targets are correct for your organization")
        }

        if validationReport?.errors.contains(where: { $0.field.contains("settings") }) == true {
            recs.append("Review and complete all required settings")
        }

        return recs
    }

    func validateProfile(_ profile: ConfigurationProfile) async {
        self.profile = profile
        isLoading = true
        defer { isLoading = false }

        // Perform validation
        validationReport = validationService.validateProfile(profile)

        // Detect conflicts
        let existingProfiles = configurationService.profiles.filter { $0.id != profile.id }
        conflictReport = validationService.detectConflicts(
            for: profile,
            against: existingProfiles
        )
    }

    func revalidate() async {
        guard let profile = profile else { return }
        await validateProfile(profile)
    }
}
