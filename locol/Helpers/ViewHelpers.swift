import SwiftUI
import Charts

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

// MARK: - Chart Components

struct ChartContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(.background.opacity(0.5))
                .border(.quaternary)
        }
    }
}

struct BaseTooltip<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background)
                    .shadow(radius: 2)
            }
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct MetricLegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption.bold())
        }
    }
}

struct TimeLabel: View {
    let timestamp: Date
    
    var body: some View {
        Text(timestamp.formatted(.dateTime.hour().minute().second()))
            .font(.caption)
            .foregroundStyle(.secondary)
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

// MARK: - Chart Colors

enum ChartColors {
    private static let colors: [Color] = [
        .blue,
        .orange,
        .green,
        .red,
        .purple,
        .yellow,
        .teal,
        .pink
    ]
    
    static func color(for seriesName: String) -> Color {
        // If the series name is in {key=value} format
        if let start = seriesName.firstIndex(of: "="),
           let end = seriesName.firstIndex(of: "}") {
            let processor = String(seriesName[seriesName.index(after: start)..<end])
            
            // Map common processor names to specific colors
            switch processor {
            case "batch": return .blue
            case "stream": return .orange
            case "filter": return .green
            default:
                // Fallback to hash-based color for unknown processors
                let colorIndex = abs(processor.hashValue) % colors.count
                return colors[colorIndex]
            }
        }
        
        // For other formats, extract meaningful parts from the name
        let components = seriesName.split(separator: "_")
        if components.contains("exporter") {
            return .blue
        } else if components.contains("processor") {
            return .orange
        } else if components.contains("receiver") {
            return .green
        } else if components.contains("scraper") {
            return .purple
        }
        
        // Fallback to hash-based color
        let colorIndex = abs(seriesName.hashValue) % colors.count
        return colors[colorIndex]
    }
}
