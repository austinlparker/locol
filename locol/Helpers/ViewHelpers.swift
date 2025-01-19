import SwiftUI

// MARK: - Shared Components

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Label Helpers

extension Dictionary where Key == String, Value == String {
    // Primary labels are the most important identifiers
    static let primaryLabels: Set<String> = [
        "exporter",     // Identifies export destinations
        "processor",    // Identifies processor components
        "receiver",     // Identifies receiver components
        "scraper"      // Identifies scraper components
    ]
    
    // Secondary labels provide additional context but aren't essential for identification
    static let secondaryLabels: Set<String> = [
        "service_instance_id",
        "service_name",
        "service_version",
        "data_type",
        "otel_signal",
        "transport"
    ]
    
    // Format only the primary labels for compact display
    func formattedPrimaryLabels() -> String {
        let primaryPairs = filter { Self.primaryLabels.contains($0.key) }
            .sorted(by: { a, b in Self.primaryLabels.firstIndex(of: a.key)! < Self.primaryLabels.firstIndex(of: b.key)! })
        return primaryPairs.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    }
    
    // Format all labels
    func formattedLabels() -> String {
        map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    }
    
    // Get labels not in primary set
    var secondaryLabelsDict: [String: String] {
        filter { !Self.primaryLabels.contains($0.key) }
    }
    
    // Check if there are any secondary labels
    var hasSecondaryLabels: Bool {
        !secondaryLabelsDict.isEmpty
    }
}

// MARK: - Label Views

struct LabelDisplay: View {
    let labels: [String: String]
    let showAll: Bool
    let showOnlyPrimary: Bool
    @State private var showingDetails = false
    
    init(labels: [String: String], showAll: Bool, showOnlyPrimary: Bool = false) {
        self.labels = labels
        self.showAll = showAll
        self.showOnlyPrimary = showOnlyPrimary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Primary labels always shown
            if !labels.formattedPrimaryLabels().isEmpty {
                HStack(spacing: 4) {
                    Text(labels.formattedPrimaryLabels())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    if !showAll && !showOnlyPrimary && labels.hasSecondaryLabels {
                        Button {
                            showingDetails = true
                        } label: {
                            Image(systemName: "ellipsis.curlybraces")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingDetails) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("All Labels")
                                    .font(.headline)
                                Text(labels.formattedLabels())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(minWidth: 200)
                        }
                    }
                }
            }
            
            // Secondary labels shown if showAll is true and not in tooltip mode
            if showAll && !showOnlyPrimary && labels.hasSecondaryLabels {
                Text(labels.secondaryLabelsDict.formattedLabels())
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
    }
}
