import SwiftUI

struct ResourceExplorerView: View {
    @State private var searchText = ""
    @State private var selectedResourceGroup: ResourceAttributeGroup?
    @State private var resourceGroups: [ResourceAttributeGroup] = []
    @State private var filters: [AttributeFilter] = []
    @State private var isLoading = false
    @State private var error: Error?
    
    private let dataExplorer: DataExplorerProtocol
    
    init(dataExplorer: DataExplorerProtocol) {
        self.dataExplorer = dataExplorer
    }
    
    var filteredGroups: [ResourceAttributeGroup] {
        if searchText.isEmpty && filters.isEmpty {
            return resourceGroups
        }
        
        return resourceGroups.filter { group in
            // Apply text search
            let matchesSearch = searchText.isEmpty ||
                group.key.localizedCaseInsensitiveContains(searchText) ||
                group.value.localizedCaseInsensitiveContains(searchText)
            
            // Apply attribute filters
            let matchesFilters = filters.isEmpty || filters.allSatisfy { filter in
                !filter.isEnabled || (
                    filter.key == group.key &&
                    group.value.localizedCaseInsensitiveContains(filter.value)
                )
            }
            
            return matchesSearch && matchesFilters
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                SearchField(text: $searchText) { _ in
                    // Search is handled automatically through filteredGroups
                }
                    .padding(.horizontal)
                
                AttributeFilterView(
                    filters: $filters,
                    availableKeys: Array(Set(resourceGroups.map(\.key))).sorted()
                ) { _ in
                    // Filtering is handled automatically through filteredGroups
                }
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    ContentUnavailableView {
                        Label("Error Loading Resources", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    }
                } else if filteredGroups.isEmpty {
                    ContentUnavailableView {
                        Label("No Resources", systemImage: "square.3.layers.3d")
                    } description: {
                        if !searchText.isEmpty || !filters.isEmpty {
                            Text("Try adjusting your search or filters")
                        } else {
                            Text("Waiting for resource data...")
                        }
                    }
                } else {
                    List(filteredGroups, selection: $selectedResourceGroup) { group in
                        ResourceGroupRow(group: group)
                            .tag(group)
                    }
                    .listStyle(.inset)
                }
            }
        } detail: {
            if let group = selectedResourceGroup {
                ResourceDetailView(resourceGroup: group, dataExplorer: dataExplorer)
            } else {
                ContentUnavailableView {
                    Label("No Resource Selected", systemImage: "square.3.layers.3d")
                } description: {
                    Text("Select a resource to view its telemetry data")
                }
            }
        }
        .task {
            await loadResources()
        }
        .refreshable {
            await loadResources()
        }
    }
    
    private func loadResources() async {
        isLoading = true
        error = nil
        
        do {
            resourceGroups = await dataExplorer.getResourceGroups()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

// MARK: - Helper Views

private struct ResourceGroupRow: View {
    let group: ResourceAttributeGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.displayName)
                .font(.headline)
            
            HStack(spacing: 8) {
                Label("\(group.count) resources", systemImage: "square.3.layers.3d")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
} 
