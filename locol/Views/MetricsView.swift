import SwiftUI
import Charts
import os

struct MetricsView: View {
    @ObservedObject private var metricsManager = MetricsManager.shared
    @State private var selectedTimeRange: TimeRange = .hour
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricsView")
    
    private var groupedMetrics: (regular: [(String, TimeSeriesData)], histograms: [(String, TimeSeriesData)]) {
        let allMetrics = metricsManager.metrics.sorted { $0.key < $1.key }
        
        // Split metrics by type
        let regular = allMetrics.filter { (key: String, value: TimeSeriesData) in
            guard let type = value.definition?.type else { return false }
            return type == .counter || type == .gauge
        }
        
        let histograms = allMetrics.filter { (key: String, value: TimeSeriesData) in
            guard let type = value.definition?.type else { return false }
            return type == .histogram
        }
        
        return (regular: regular, histograms: histograms)
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 500))], spacing: 16) {
                // Regular metrics section
                if !groupedMetrics.regular.isEmpty {
                    Section {
                        ForEach(groupedMetrics.regular, id: \.0) { key, metric in
                            if let type = metric.definition?.type {
                                switch type {
                                case .counter:
                                    CounterCard(metric: metric)
                                case .gauge:
                                    GaugeCard(metric: metric)
                                case .histogram:
                                    EmptyView() // Should never happen
                                }
                            }
                        }
                    } header: {
                        Text("Metrics")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
                
                // Histograms section
                if !groupedMetrics.histograms.isEmpty {
                    Section {
                        ForEach(groupedMetrics.histograms, id: \.0) { key, metric in
                            if let histogram = metric.values.last?.histogram {
                                HistogramCard(metric: histogram, name: key)
                            }
                        }
                    } header: {
                        Text("Histograms")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Metrics")
        .toolbar {
            ToolbarItem {
                Button(action: {
                    metricsManager.startScraping()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            
            ToolbarItem {
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.description).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
}

private func formatLabels(_ labels: [String: String]) -> String {
    labels.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
}

struct CounterCard: View {
    let metric: TimeSeriesData
    @ObservedObject private var metricsManager = MetricsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(metric.name)
                .font(.headline)
            if !metric.labels.isEmpty {
                Text(formatLabels(metric.labels))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Chart
            TimeSeriesChartView(metric: metric)
                .frame(height: 200)
            
            // Stats
            HStack(spacing: 16) {
                // Total
                if let lastValue = metric.values.last?.value {
                    StatBox(
                        title: "Total",
                        value: String(format: "%.0f", lastValue)
                    )
                }
                
                // Rate
                if let rate = metricsManager.getRate(
                    for: MetricKeyGenerator.generateKey(name: metric.name, labels: metric.labels)
                ) {
                    StatBox(
                        title: "Rate (/sec)",
                        value: String(format: "%.2f", rate)
                    )
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
}

struct GaugeCard: View {
    let metric: TimeSeriesData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(metric.name)
                .font(.headline)
            if !metric.labels.isEmpty {
                Text(formatLabels(metric.labels))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Chart
            TimeSeriesChartView(metric: metric)
                .frame(height: 200)
            
            // Current value
            if let lastValue = metric.values.last?.value {
                StatBox(
                    title: "Current Value",
                    value: String(format: "%.2f", lastValue)
                )
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
}

struct HistogramCard: View {
    let metric: HistogramMetric
    let name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(name)
                .font(.headline)
            if !metric.labels.isEmpty {
                Text(formatLabels(metric.labels))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Histogram chart
            HistogramChartView(histogram: metric)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
}

struct TimeSeriesChartView: View {
    let metric: TimeSeriesData
    
    var body: some View {
        Chart {
            ForEach(metric.values.indices, id: \.self) { index in
                let point = metric.values[index]
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
            }
        }
    }
}

enum TimeRange: String, CaseIterable {
    case hour = "1h"
    case day = "24h"
    case week = "7d"
    
    var description: String {
        rawValue
    }
    
    var seconds: TimeInterval {
        switch self {
        case .hour:
            return 3600
        case .day:
            return 86400
        case .week:
            return 604800
        }
    }
} 
