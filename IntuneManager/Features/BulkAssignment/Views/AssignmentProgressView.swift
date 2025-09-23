import SwiftUI

struct AssignmentProgressView: View {
    @ObservedObject var viewModel: BulkAssignmentViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingErrorDetails = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Processing Assignments")
                .font(.title2)
                .fontWeight(.semibold)

            if let progress = viewModel.progress {
                ProgressView(value: progress.percentComplete, total: 100)
                    .progressViewStyle(.linear)
                    .frame(height: 10)

                HStack {
                    VStack(alignment: .leading) {
                        Text("\(progress.completed) of \(progress.total)")
                            .font(.headline)
                        Text(progress.currentOperation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        if progress.failed > 0 {
                            HStack {
                                Text("\(progress.failed) failed")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Button(action: { showingErrorDetails = true }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("\(Int(progress.percentComplete))%")
                            .font(.headline)
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            }

            // Summary section when processing is complete
            if !viewModel.isProcessing && (viewModel.completedAssignments.count > 0 || viewModel.failedAssignments.count > 0) {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)

                    HStack {
                        Label("\(viewModel.completedAssignments.count) Successful", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)

                        Spacer()

                        if !viewModel.failedAssignments.isEmpty {
                            Label("\(viewModel.failedAssignments.count) Failed", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    // Group errors by type for better visibility
                    if !viewModel.failedAssignments.isEmpty {
                        let errorGroups = Dictionary(grouping: viewModel.failedAssignments) { $0.errorMessage ?? "Unknown error" }
                        ForEach(Array(errorGroups.keys.sorted()), id: \.self) { errorType in
                            HStack {
                                Text("• \(errorType)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("(\(errorGroups[errorType]?.count ?? 0))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            if !viewModel.isProcessing {
                VStack(spacing: 12) {
                    if !viewModel.failedAssignments.isEmpty {
                        HStack(spacing: 12) {
                            Button("View Details") {
                                showingErrorDetails = true
                            }
                            .buttonStyle(.bordered)

                            Button("Retry Failed") {
                                Task {
                                    await viewModel.retryFailedAssignments()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button("Cancel") {
                    viewModel.cancelAssignment()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(width: 500, height: viewModel.failedAssignments.isEmpty ? 350 : 450)
        .sheet(isPresented: $showingErrorDetails) {
            AssignmentErrorDetailsView(failedAssignments: viewModel.failedAssignments)
        }
    }
}

// MARK: - Error Details View
struct AssignmentErrorDetailsView: View {
    let failedAssignments: [Assignment]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredAssignments: [Assignment] {
        if searchText.isEmpty {
            return failedAssignments
        } else {
            return failedAssignments.filter {
                $0.applicationName.localizedCaseInsensitiveContains(searchText) ||
                $0.groupName.localizedCaseInsensitiveContains(searchText) ||
                ($0.errorMessage ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack {
            HStack {
                Text("Failed Assignments")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            // Error summary
            let errorGroups = Dictionary(grouping: failedAssignments) { $0.errorMessage ?? "Unknown error" }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Array(errorGroups.keys.sorted()), id: \.self) { errorType in
                        VStack {
                            Text("\(errorGroups[errorType]?.count ?? 0)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(errorType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(minWidth: 100)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }

            // Detailed list
            List(filteredAssignments) { assignment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(assignment.applicationName)
                                .font(.headline)
                            Text("→ \(assignment.groupName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }

                    if let error = assignment.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    }

                    if assignment.retryCount > 0 {
                        Text("Retry attempts: \(assignment.retryCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .searchable(text: $searchText, prompt: "Search failed assignments")
        }
        .frame(width: 600, height: 500)
        .platformGlassBackground()
    }
}