import SwiftUI

struct TemplateSelectionView: View {
    @StateObject private var viewModel = ConfigurationViewModel()
    @State private var searchText = ""
    @State private var selectedPlatform: String? = nil
    @Environment(\.dismiss) private var dismiss
    let onSelectTemplate: (ConfigurationTemplate) -> Void

    var filteredTemplates: [ConfigurationTemplate] {
        var templates = viewModel.templates

        // Filter by search
        if !searchText.isEmpty {
            templates = templates.filter { template in
                template.displayName.localizedCaseInsensitiveContains(searchText) ||
                (template.templateDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Filter by platform
        if let platform = selectedPlatform {
            templates = templates.filter { template in
                template.platformTypes.contains(platform)
            }
        }

        // Filter out deprecated templates
        templates = templates.filter { !$0.isDeprecated }

        return templates.sorted { $0.displayName < $1.displayName }
    }

    var templatesByCategory: [String: [ConfigurationTemplate]] {
        Dictionary(grouping: filteredTemplates) { template in
            template.templateType
        }
    }

    var availablePlatforms: [String] {
        let allPlatforms = Set(viewModel.templates.flatMap { $0.platformTypes })
        return Array(allPlatforms).sorted()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search and filters
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search templates...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    // Platform filter
                    if !availablePlatforms.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(
                                    title: "All Platforms",
                                    isSelected: selectedPlatform == nil,
                                    action: { selectedPlatform = nil }
                                )

                                ForEach(availablePlatforms, id: \.self) { platform in
                                    FilterChip(
                                        title: platformDisplayName(platform),
                                        icon: platformIcon(platform),
                                        isSelected: selectedPlatform == platform,
                                        action: { selectedPlatform = platform }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Theme.Colors.secondaryBackground)

                Divider()

                // Templates list
                if viewModel.isLoading && viewModel.templates.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView("Loading templates...")
                        Spacer()
                    }
                } else if filteredTemplates.isEmpty {
                    VStack {
                        Spacer()
                        ContentUnavailableView(
                            searchText.isEmpty ? "No Templates Available" : "No Results",
                            systemImage: searchText.isEmpty ? "doc.text" : "magnifyingglass",
                            description: Text(searchText.isEmpty ?
                                "No configuration templates are available" :
                                "No templates match '\(searchText)'")
                        )
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(templatesByCategory.keys.sorted(), id: \.self) { category in
                                if let templates = templatesByCategory[category], !templates.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(categoryDisplayName(category))
                                            .font(.headline)
                                            .padding(.horizontal)

                                        ForEach(templates) { template in
                                            TemplateCard(
                                                template: template,
                                                onSelect: {
                                                    onSelectTemplate(template)
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Select Template")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        Task {
                            await viewModel.loadTemplates(forceRefresh: true)
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .frame(width: 800, height: 600)
        }
        .task {
            await viewModel.loadTemplates()
        }
    }

    private func platformDisplayName(_ platform: String) -> String {
        switch platform.lowercased() {
        case "ios", "ipados": return "iOS/iPadOS"
        case "macos": return "macOS"
        case "android": return "Android"
        case "windows", "windows10": return "Windows"
        default: return platform
        }
    }

    private func platformIcon(_ platform: String) -> String {
        switch platform.lowercased() {
        case "ios", "ipados": return "iphone"
        case "macos": return "desktopcomputer"
        case "android": return "android"
        case "windows", "windows10": return "pc"
        default: return "questionmark.square"
        }
    }

    private func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "configurationPolicy": return "Configuration Policies"
        case "endpointSecurityTemplate": return "Endpoint Security"
        case "baseline": return "Security Baselines"
        case "deviceCompliance": return "Compliance Policies"
        default: return category.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(15)
        }
        .buttonStyle(.plain)
    }
}

struct TemplateCard: View {
    let template: ConfigurationTemplate
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if let description = template.templateDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack {
                        // Platforms
                        if !template.platformTypes.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "desktopcomputer")
                                    .font(.caption2)
                                Text(template.platformTypes.joined(separator: ", "))
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }

                        // Settings count
                        if template.settingsCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "gearshape")
                                    .font(.caption2)
                                Text("\(template.settingsCount) settings")
                                    .font(.caption2)
                            }
                            .foregroundColor(.green)
                        }

                        // Technologies
                        if !template.technologies.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "cpu")
                                    .font(.caption2)
                                Text(template.technologies.prefix(2).joined(separator: ", "))
                                    .font(.caption2)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}