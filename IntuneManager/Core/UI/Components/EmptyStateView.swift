import SwiftUI

/// Reusable empty state view for consistent empty data presentation
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.tertiaryText)

            VStack(spacing: Theme.Spacing.small) {
                Text(title)
                    .font(Theme.Typography.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Theme.Typography.callout)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(Theme.Spacing.xLarge)
        .frame(maxWidth: 400)
    }
}

/// Error state view for consistent error presentation
struct ErrorStateView: View {
    let error: Error
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.error)

            VStack(spacing: Theme.Spacing.small) {
                Text("Something went wrong")
                    .font(Theme.Typography.title3)
                    .fontWeight(.semibold)

                Text(error.localizedDescription)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: retryAction) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(Theme.Typography.callout)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(Theme.Spacing.xLarge)
        .frame(maxWidth: 400)
    }
}

/// Loading state view for consistent loading presentation
struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xLarge)
        .frame(maxWidth: 400)
    }
}

#Preview {
    VStack(spacing: 40) {
        EmptyStateView(
            icon: "folder",
            title: "No Devices Found",
            message: "Start by syncing your devices from Microsoft Intune.",
            actionTitle: "Sync Devices",
            action: {}
        )

        ErrorStateView(
            error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to connect to Microsoft Graph API. Please check your network connection and try again."]),
            retryAction: {}
        )

        LoadingStateView(message: "Loading devices...")
    }
}