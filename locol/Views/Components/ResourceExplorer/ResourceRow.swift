import SwiftUI

struct ResourceRowView: View {
    let resourceId: String
    @State private var resource: ResourceRow?
    @State private var isLoading = false
    
    private let dataExplorer: DataExplorerProtocol
    
    init(resourceId: String, dataExplorer: DataExplorerProtocol = DataExplorer.shared) {
        self.resourceId = resourceId
        self.dataExplorer = dataExplorer
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let resource = resource {
                Text(resourceId)
                    .font(.headline)
                
                // Show the first few attributes
                ForEach(Array(resource.attributes.prefix(3)), id: \.key) { attr in
                    HStack {
                        Text(attr.key)
                            .foregroundStyle(.secondary)
                        Text(attr.value)
                            .foregroundStyle(.primary)
                    }
                    .font(.caption)
                }
                
                if resource.attributes.count > 3 {
                    Text("+ \(resource.attributes.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Failed to load resource")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadResource()
        }
    }
    
    private func loadResource() async {
        isLoading = true
        defer { isLoading = false }
        
        // Query the database for this resource's details
        let query = """
            SELECT r.timestamp, r.dropped_attributes_count, ra.key, ra.value
            FROM resources r
            LEFT JOIN resource_attribute_mappings ram ON r.resource_id = ram.resource_id
            LEFT JOIN resource_attributes ra ON ram.attribute_id = ra.attribute_id
            WHERE r.resource_id = '\(resourceId)';
        """
        
        do {
            let result = try await dataExplorer.executeQuery(query)
            
            // Extract data from result
            let timestamps = result["timestamp"] as? [Date] ?? []
            let droppedCounts = result["dropped_attributes_count"] as? [Int32] ?? []
            let keys = result["key"] as? [String] ?? []
            let values = result["value"] as? [String] ?? []
            
            // Create attribute pairs
            var attributes: [(key: String, value: String)] = []
            for i in 0..<min(keys.count, values.count) {
                attributes.append((key: keys[i], value: values[i]))
            }
            
            // Create resource
            if let timestamp = timestamps.first, let droppedCount = droppedCounts.first {
                resource = ResourceRow(
                    id: resourceId,
                    timestamp: timestamp,
                    droppedAttributesCount: droppedCount,
                    attributes: attributes
                )
            }
        } catch {
            print("Failed to load resource: \(error)")
            resource = nil
        }
    }
} 