import SwiftUI
import DuckDB

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
            let timestamps = result.column(at: 0).cast(to: DuckDB.Timestamp.self).map { $0?.microseconds ?? 0 }.map { Date(timeIntervalSince1970: TimeInterval($0) / 1_000_000) }
            let droppedCounts = result.column(at: 1).cast(to: Int32.self)
            let keys = result.column(at: 2).cast(to: String.self)
            let values = result.column(at: 3).cast(to: String.self)
            
            // Create attribute pairs
            var attributes: [(key: String, value: String)] = []
            for i in 0..<min(keys.count, values.count) {
                if let key = keys[UInt64(i)], let value = values[UInt64(i)] {
                    attributes.append((key: key, value: value))
                }
            }
            
            // Create resource
            if let timestamp = timestamps.first, let droppedCount = droppedCounts.first {
                resource = ResourceRow(
                    id: resourceId,
                    timestamp: timestamp,
                    droppedAttributesCount: droppedCount ?? 0,
                    attributes: attributes
                )
            }
        } catch {
            print("Failed to load resource: \(error)")
            resource = nil
        }
    }
} 