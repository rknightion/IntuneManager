import SwiftUI

struct AddApplicationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddApplicationViewModel()
    @State private var selectedAppType: AndroidAppType?
    @State private var showingForm = false

    enum AndroidAppType: String, CaseIterable, Identifiable {
        case androidStore = "Android Store App"
        case androidEnterpriseSystem = "Android Enterprise System App"
        case bulkImportSystemApps = "Bulk Import System Apps"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .androidStore:
                return "storefront"
            case .androidEnterpriseSystem:
                return "building.2"
            case .bulkImportSystemApps:
                return "square.stack.3d.down.right"
            }
        }

        var description: String {
            switch self {
            case .androidStore:
                return "Add apps from the Google Play Store by providing the store URL"
            case .androidEnterpriseSystem:
                return "Add pre-installed Android system apps using their package name"
            case .bulkImportSystemApps:
                return "Import multiple system apps at once by pasting package IDs"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if !showingForm {
                    appTypeSelectionView
                } else {
                    if let appType = selectedAppType {
                        destinationView(for: appType)
                    }
                }
            }
            .navigationTitle("Add Application")
            #if os(macOS)
            .frame(minWidth: 600, minHeight: 500)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appTypeSelectionView: some View {
        VStack(spacing: 24) {
            Text("Select App Type")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)

            VStack(spacing: 16) {
                ForEach(AndroidAppType.allCases) { appType in
                    Button {
                        selectedAppType = appType
                        withAnimation {
                            showingForm = true
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: appType.icon)
                                .font(.system(size: 32))
                                .foregroundColor(.accentColor)
                                .frame(width: 50)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(appType.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(appType.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    @ViewBuilder
    private func destinationView(for appType: AndroidAppType) -> some View {
        switch appType {
        case .androidStore:
            AddAndroidStoreAppView(viewModel: viewModel) {
                dismiss()
            }
        case .androidEnterpriseSystem:
            AddAndroidEnterpriseSystemAppView(viewModel: viewModel) {
                dismiss()
            }
        case .bulkImportSystemApps:
            BulkImportSystemAppsView(viewModel: viewModel) {
                dismiss()
            }
        }
    }
}

#if os(macOS)
// macOS-specific color extension
extension Color {
    init(nsColor: NSColor) {
        self.init(nsColor)
    }
}
#else
// iOS-specific color extension
extension Color {
    init(nsColor: UIColor) {
        self.init(uiColor: nsColor)
    }
}
#endif
