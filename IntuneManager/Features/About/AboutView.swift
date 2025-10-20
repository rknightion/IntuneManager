import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.large) {
                    // App Icon and Info
                    VStack(spacing: Theme.Spacing.medium) {
                        Image(systemName: "key.icloud.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Theme.Colors.primary)
                            .accessibilityLabel("IntuneManager App Icon")

                        Text("IntuneManager")
                            .font(Theme.Typography.largeTitle)
                            .fontWeight(.bold)

                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.top, Theme.Spacing.large)

                    // Description
                    Text("A professional Microsoft Intune management tool for IT administrators")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Divider()
                        .padding(.vertical)

                    // Features
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        SectionHeader(title: "Features")

                        FeatureRow(
                            icon: "iphone.badge.play",
                            title: "Device Management",
                            description: "View and manage all enrolled devices"
                        )

                        FeatureRow(
                            icon: "app.badge",
                            title: "Application Deployment",
                            description: "Deploy and manage applications"
                        )

                        FeatureRow(
                            icon: "person.3",
                            title: "Group Management",
                            description: "Organize devices and users in groups"
                        )

                        FeatureRow(
                            icon: "checkmark.shield",
                            title: "Secure Authentication",
                            description: "Uses Microsoft Authentication Library (MSAL) with PKCE flow"
                        )
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.vertical)

                    // Support Links
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        SectionHeader(title: "Support")

                        Link(destination: URL(string: "https://docs.microsoft.com/en-us/mem/intune/")!) {
                            LinkRow(
                                icon: "book",
                                title: "Microsoft Intune Documentation"
                            )
                        }

                        Link(destination: URL(string: "https://github.com/Azure-Samples/ms-identity-mobile-apple-swift-objc")!) {
                            LinkRow(
                                icon: "chevron.left.forwardslash.chevron.right",
                                title: "MSAL iOS Documentation"
                            )
                        }

                        Link(destination: URL(string: "https://portal.azure.com")!) {
                            LinkRow(
                                icon: "cloud",
                                title: "Azure Portal"
                            )
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.vertical)

                    // Legal
                    VStack(spacing: Theme.Spacing.small) {
                        Text("© 2024 IntuneManager")
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.tertiaryText)

                        Text("This app is not affiliated with Microsoft Corporation")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.tertiaryText)
                            .multilineTextAlignment(.center)

                        HStack(spacing: Theme.Spacing.large) {
                            Button("Privacy Policy") {
                                openPrivacyPolicy()
                            }
                            .font(Theme.Typography.caption)

                            Button("Terms of Use") {
                                openTermsOfUse()
                            }
                            .font(Theme.Typography.caption)
                        }
                        .padding(.top, Theme.Spacing.small)
                    }
                    .padding(.bottom, Theme.Spacing.xLarge)
                }
            }
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func openPrivacyPolicy() {
        if let url = URL(string: "https://www.example.com/privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openTermsOfUse() {
        if let url = URL(string: "https://www.example.com/terms") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Theme.Typography.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxSmall) {
                Text(title)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

struct LinkRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.Typography.body)

            Spacer()

            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
                .accessibilityHidden(true)
        }
        .foregroundColor(Theme.Colors.primary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), opens in browser")
        .accessibilityHint("Tap to open link")
    }
}

#Preview {
    AboutView()
}
