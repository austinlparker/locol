import SwiftUI
import Charts
import os

// MARK: - Views
struct MetricsView: View {
    @State var viewModel: MetricsViewModel
    @State private var searchText: String = ""
    @State private var selectedType: MetricType?
    
    var filteredGroups: [MetricGroup] {
        var groups = viewModel.groupedMetrics
        
        // Apply search filter
        if !searchText.isEmpty {
            groups = groups.filter { group in
                switch group {
                case .counters(let name, _):
                    return name.localizedCaseInsensitiveContains(searchText)
                case .gauge(let metrics):
                    return metrics[0].name.localizedCaseInsensitiveContains(searchText) ||
                           metrics[0].help?.localizedCaseInsensitiveContains(searchText) ?? false ||
                           metrics[0].labels.contains { $0.value.localizedCaseInsensitiveContains(searchText) }
                case .histogram(let metric, _):
                    return metric.name.localizedCaseInsensitiveContains(searchText) ||
                           metric.help?.localizedCaseInsensitiveContains(searchText) ?? false ||
                           metric.labels.contains { $0.value.localizedCaseInsensitiveContains(searchText) }
                }
            }
        }
        
        // Apply type filter
        if let selectedType {
            groups = groups.filter { group in
                switch group {
                case .counters: return selectedType == .counter
                case .gauge(let metrics): return metrics[0].type == selectedType
                case .histogram(let metric, _): return metric.type == selectedType
                }
            }
        }
        
        return groups
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            HStack {
                SearchField("Search metrics", text: $searchText)
                
                Picker("Filter", selection: $selectedType) {
                    Text("All").tag(nil as MetricType?)
                    ForEach(MetricType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type as MetricType?)
                    }
                }
                .frame(width: 120)
            }
            .padding()
            
            // Time range selector
            Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                ForEach(TimeRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom)
            
            // Metrics list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredGroups, id: \.id) { group in
                        switch group {
                        case .counters(let name, let series):
                            CounterCard(name: name, series: series)
                        case .gauge(let metrics):
                            GaugeCard(metrics: metrics)
                        case .histogram(let metric, let histogram):
                            HistogramCard(metric: metric, histogram: histogram)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Supporting Views
struct MetricRowView: View {
    let metric: Metric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.name)
                    .font(.headline)
                
                Spacer()
                
                Text(metric.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            if let help = metric.help {
                Text(help)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if !metric.labels.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(Array(metric.labels), id: \.key) { key, value in
                        HStack(spacing: 4) {
                            Text(key)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(value)
                                .font(.caption)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            
            Text(metric.formatValueWithInferredUnit(metric.value))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 4)
    }
}

enum RateInterval: String, CaseIterable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    
    var description: String {
        rawValue
    }
    
    var seconds: TimeInterval {
        switch self {
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 300
        case .fifteenMinutes:
            return 900
        }
    }
} 
