import SwiftUI

struct ReviewAssignmentView: View {
    @ObservedObject var viewModel: BulkAssignmentViewModel
    
    var summary: BulkAssignmentViewModel.AssignmentSummary {
        viewModel.getAssignmentSummary()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Card
                SummaryCard(summary: summary)
                
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
            
            HStack {
                Label("Estimated Time: \(summary.estimatedTime)", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Label(summary.intent.displayName, systemImage: summary.intent.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
