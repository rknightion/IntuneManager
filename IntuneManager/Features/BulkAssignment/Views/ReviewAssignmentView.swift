import SwiftUI

struct ReviewAssignmentView: View {
    @ObservedObject var viewModel: BulkAssignmentViewModel
    
    var summary: BulkAssignmentViewModel.AssignmentSummary {
        viewModel.getAssignmentSummary()
    }
    
    var compatibilityWarnings: [String] {
        var warnings: [String] = []

        // Get the intersection of supported platforms from all selected apps
        let platformSets = viewModel.selectedApplications.map { $0.supportedPlatforms }
        let commonPlatforms = platformSets.first.map { first in
            platformSets.dropFirst().reduce(first) { $0.intersection($1) }
        } ?? []

        if commonPlatforms.isEmpty && !viewModel.selectedApplications.isEmpty {
            warnings.append("⚠️ Selected apps have no common platform support. Assignments may fail for incompatible devices.")
        } else if !commonPlatforms.isEmpty {
            let unsupportedPlatforms = Application.DevicePlatform.allCases.filter {
                $0 != .unknown && !commonPlatforms.contains($0)
            }
            if !unsupportedPlatforms.isEmpty {
                let platformNames = unsupportedPlatforms.map { $0.displayName }.joined(separator: ", ")
                warnings.append("ℹ️ Selected apps do not support: \(platformNames)")
            }
        }

        // Check for VPP apps and Windows groups
        let hasVppApps = viewModel.selectedApplications.contains {
            $0.appType == .iosVppApp || $0.appType == .macOSVppApp
        }
        let hasWindowsOnlyApps = viewModel.selectedApplications.contains {
            app in
            let platforms = app.supportedPlatforms
            return platforms.count == 1 && platforms.contains(.windows)
        }

        if hasVppApps && hasWindowsOnlyApps {
            warnings.append("⚠️ Mixing VPP apps with Windows-only apps. These will fail on incompatible devices.")
        }

        return warnings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Compatibility Warnings
                if !compatibilityWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(compatibilityWarnings, id: \.self) { warning in
                            HStack {
                                Text(warning)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }

                // Summary Card
                SummaryCard(summary: summary, targetPlatform: viewModel.targetPlatform)
                
                // Selected Applications
                SectionView(title: "Selected Applications (\(summary.applicationCount))") {
                    ForEach(Array(viewModel.selectedApplications), id: \.id) { app in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(app.displayName)
                                    .lineLimit(1)
                                Spacer()
                                Text("→ \(summary.groupCount) groups")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 8) {
                                Label(app.appType.displayName, systemImage: app.appType.icon)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                // Show supported platforms
                                if !app.supportedPlatforms.isEmpty {
                                    HStack(spacing: 2) {
                                        ForEach(Array(app.supportedPlatforms.sorted { $0.rawValue < $1.rawValue }), id: \.self) { platform in
                                            Image(systemName: platform.icon)
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }

                                if let version = app.version, !version.isEmpty {
                                    Text("v\(version)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if let publisher = app.publisher, !publisher.isEmpty {
                                    Text(publisher)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Selected Groups
                SectionView(title: "Selected Groups (\(summary.groupCount))") {
                    ForEach(Array(viewModel.selectedGroups), id: \.id) { group in
                        HStack {
                            Text(group.displayName)
                                .lineLimit(1)
                            Spacer()
                            Text("← \(summary.applicationCount) apps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
        }
    }
}

struct SummaryCard: View {
    let summary: BulkAssignmentViewModel.AssignmentSummary
    let targetPlatform: Application.DevicePlatform?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Assignments")
                        .font(.headline)
                    Text("\(summary.totalAssignments)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                Spacer()
                Image(systemName: summary.intent.icon)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Estimated Time: \(summary.estimatedTime)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Label(summary.intent.displayName, systemImage: summary.intent.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let platform = targetPlatform {
                    Label("Target Platform: \(platform.displayName)", systemImage: platform.icon)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
}
