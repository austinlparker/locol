import SwiftUI
import Charts
import os

struct MetricsView: View {
    @StateObject private var viewModel = MetricsViewModel()
    @State private var selectedTimeRange: TimeRange = .hour
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricsView")
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 500))], spacing: 16) {
                // Regular metrics section
                if !viewModel.groupedMetrics.regular.isEmpty {
                    Section {
                        ForEach(viewModel.groupedMetrics.regular, id: \.0) { key, metrics in
                            if let type = metrics.first?.type {
                                switch type {
                                case .counter:
                                    CounterCard(metrics: metrics, viewModel: viewModel)
                                case .gauge:
                                    GaugeCard(metrics: metrics)
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
                if !viewModel.groupedMetrics.histograms.isEmpty {
                    Section {
                        ForEach(viewModel.groupedMetrics.histograms, id: \.0) { key, metrics in
                            if let lastMetric = metrics.last,
                               let histogram = lastMetric.histogram {
                                HistogramCard(metric: lastMetric, histogram: histogram)
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
                    viewModel.startScraping()
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

struct CounterCard: View {
    let metrics: [Metric]
    let viewModel: MetricsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(metrics.first?.name ?? "")
                .font(.headline)
            if let labels = metrics.first?.labels,
               !labels.isEmpty {
                Text(labels.formattedLabels())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Chart
            TimeSeriesChartView(metrics: metrics)
                .frame(height: 200)
            
            // Stats
            HStack(spacing: 16) {
                // Total
                if let lastValue = metrics.last?.value {
                    StatBox(
                        title: "Total",
                        value: String(format: "%.0f", lastValue)
                    )
                }
                
                // Rate
                if let key = metrics.first?.id,
                   let rate = viewModel.getRate(for: key) {
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
    let metrics: [Metric]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(metrics.first?.name ?? "")
                .font(.headline)
            if let labels = metrics.first?.labels,
               !labels.isEmpty {
                Text(labels.formattedLabels())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Chart
            TimeSeriesChartView(metrics: metrics)
                .frame(height: 200)
            
            // Current value
            if let lastValue = metrics.last?.value {
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
    let metric: Metric
    let histogram: HistogramMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(metric.name)
                .font(.headline)
            if !metric.labels.isEmpty {
                Text(metric.labels.formattedLabels())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Stats
            HStack(spacing: 16) {
                StatBox(title: "Count", value: String(format: "%.0f", histogram.count))
                StatBox(title: "Sum", value: String(format: "%.2f", histogram.sum))
                StatBox(title: "Average", value: String(format: "%.2f", histogram.average))
                StatBox(title: "p50", value: String(format: "%.2f", histogram.p50))
                StatBox(title: "p95", value: String(format: "%.2f", histogram.p95))
                StatBox(title: "p99", value: String(format: "%.2f", histogram.p99))
            }
            
            // Histogram chart
            HistogramChartView(histogram: histogram)
                .frame(height: 200)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
}

struct TimeSeriesChartView: View {
    let metrics: [Metric]
    
    var body: some View {
        Chart {
            ForEach(metrics) { metric in
                LineMark(
                    x: .value("Time", metric.timestamp),
                    y: .value("Value", metric.value)
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
