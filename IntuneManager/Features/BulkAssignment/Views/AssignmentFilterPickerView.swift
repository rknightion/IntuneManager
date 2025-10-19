import SwiftUI

struct AssignmentFilterPickerView: View {
    let appType: Application.AppType
    let selectedFilterId: String?
    let onSelect: (AssignmentFilter) -> Void

    @ObservedObject private var filterService = AssignmentFilterService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showOtherPlatforms = false

    private var recommendedFilterIds: Set<String> {
        Set(filterService.filters(for: appType).map(\.id))
    }

    private var recommendedFilters: [AssignmentFilter] {
        applySearch(filterService.filters.filter { recommendedFilterIds.contains($0.id) })
    }

    private var otherFilters: [AssignmentFilter] {
        applySearch(filterService.filters.filter { !recommendedFilterIds.contains($0.id) })
    }

    private var isLoading: Bool {
        filterService.isLoading && filterService.filters.isEmpty
    }

    var body: some View {
        pickerContainer
            .task {
                await filterService.fetchFilters()
            }
    }

    @ViewBuilder
    private var pickerContainer: some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            NavigationStack {
                pickerContent
            }
        } else {
            NavigationView {
                pickerContent
            }
#if !os(macOS)
            .navigationViewStyle(StackNavigationViewStyle())
#endif
        }
    }

    private var pickerContent: some View {
        VStack(spacing: 12) {
            searchField

            if isLoading {
                ProgressView("Loading filters…")
                    .padding(.top, 20)
                Spacer()
            } else if filterService.filters.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No assignment filters found")
                        .font(.headline)
                    Text("Create filters in the Intune portal to target assignments to specific devices.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else {
                List {
                    if !recommendedFilters.isEmpty {
                        Section(header: Text("Recommended")) {
                            ForEach(recommendedFilters) { filter in
                                filterRow(filter, highlight: true)
                            }
                        }
                    }

                    if showOtherPlatforms && !otherFilters.isEmpty {
                        Section(header: Text("Other Platforms")) {
                            ForEach(otherFilters) { filter in
                                filterRow(filter, highlight: false)
                            }
                        }
                    }
                }
#if os(macOS)
                .listStyle(.inset)
#else
                .listStyle(.insetGrouped)
#endif

                if !otherFilters.isEmpty {
                    Toggle(isOn: $showOtherPlatforms) {
                        Text("Show filters for other platforms")
                            .font(.caption)
                    }
#if os(macOS)
                    .toggleStyle(.switch)
#endif
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .navigationTitle("Assignment Filters")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search filters…", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(8)
        .padding([.horizontal, .top])
    }

    private func filterRow(_ filter: AssignmentFilter, highlight: Bool) -> some View {
        Button {
            onSelect(filter)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: highlight ? "star.fill" : "line.horizontal.3.decrease.circle")
                    .foregroundColor(highlight ? .yellow : .accentColor)
                    .font(.subheadline)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(filter.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        if filter.id == selectedFilterId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }

                    Text(filter.platform.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !filter.rule.isEmpty {
                        Text(filter.rule)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    if let description = filter.filterDescription, !description.isEmpty {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func applySearch(_ filters: [AssignmentFilter]) -> [AssignmentFilter] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return filters }
        return filters.filter { filter in
            filter.displayName.localizedCaseInsensitiveContains(trimmed) ||
            filter.rule.localizedCaseInsensitiveContains(trimmed) ||
            (filter.filterDescription?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }
}
