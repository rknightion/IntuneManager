import SwiftUI

struct AssignmentProgressView: View {
    @ObservedObject var viewModel: BulkAssignmentViewModel
    @Environment(\.dismiss) private var dismiss
    
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
                            Text("\(progress.failed) failed")
                                .font(.caption)
                                .foregroundColor(.red)
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
            
            if !viewModel.isProcessing {
                VStack(spacing: 12) {
                    if !viewModel.failedAssignments.isEmpty {
                        Button("Retry Failed") {
                            Task {
                                await viewModel.retryFailedAssignments()
                            }
                        }
                        .buttonStyle(.borderedProminent)
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
        .frame(width: 400, height: 300)
    }
}