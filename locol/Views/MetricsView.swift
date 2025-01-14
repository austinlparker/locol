import SwiftUI
import Charts

// Base protocol for metric views
protocol MetricViewType {
    var metricName: String { get }
    var description: String { get }
    var values: [(timestamp: Date, value: Double)] { get }
    var labels: [String: String] { get }
    var metricsManager: MetricsManager { get }
}

// Common header view for all metric types
struct MetricHeaderView: View {
    let metricName: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metricName.replacingOccurrences(of: "otelcol_", with: ""))
                .font(.headline)
                .lineLimit(1)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }
}

// View for counter metrics
struct CounterMetricView: View, MetricViewType {
    let metricName: String
    let description: String
    let values: [(timestamp: Date, value: Double)]
    let labels: [String: String]
    @ObservedObject var metricsManager: MetricsManager
    
    private func calculateRates() -> [(timestamp: Date, value: Double)] {
        guard values.count >= 2 else { return [] }
        
        // Calculate raw rates first
        let rawRates = zip(values, values.dropFirst()).map { current, next in
            let timeDiff = next.timestamp.timeIntervalSince(current.timestamp)
            let valueDiff = next.value - current.value
            let rate = timeDiff > 0 ? valueDiff / timeDiff : 0
            return (timestamp: next.timestamp, value: rate)
        }
        
        // Apply exponential moving average for smoothing
        let alpha = 0.3 // Smoothing factor
        var smoothedRates: [(timestamp: Date, value: Double)] = []
        
        for (index, rate) in rawRates.enumerated() {
            if index == 0 {
                smoothedRates.append(rate)
            } else {
                let smoothedValue = alpha * rate.value + (1 - alpha) * smoothedRates[index - 1].value
                smoothedRates.append((timestamp: rate.timestamp, value: smoothedValue))
            }
        }
        
        return smoothedRates
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetricHeaderView(metricName: metricName, description: description)
            
            Chart {
                ForEach(calculateRates(), id: \.timestamp) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 100)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            
            HStack(spacing: 8) {
                Text("Rate: \(formatValue(calculateRates().last?.value ?? 0))/s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// View for gauge metrics
struct GaugeMetricView: View, MetricViewType {
    let metricName: String
    let description: String
    let values: [(timestamp: Date, value: Double)]
    let labels: [String: String]
    @ObservedObject var metricsManager: MetricsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetricHeaderView(metricName: metricName, description: description)
            
            Text(formatValue(values.last?.value ?? 0))
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(.orange)
                .padding(.vertical, 4)
            
            Chart {
                ForEach(values, id: \.timestamp) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.orange)
                }
            }
            .frame(height: 60)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// View for histogram metrics
struct HistogramMetricView: View, MetricViewType {
    let metricName: String
    let description: String
    let values: [(timestamp: Date, value: Double)]
    let labels: [String: String]
    let gridColumns: Int
    @ObservedObject var metricsManager: MetricsManager
    
    private func getCurrentHistogram() -> HistogramData? {
        let key = metricsManager.metricKey(name: metricName, labels: labels)
        let histData = metricsManager.histogramData[key]?.last
        
        CollectorLogger.shared.debug("""
            [\(metricName)] Histogram data:
            - Key: \(key)
            - Labels: \(labels)
            - Has data: \(histData != nil)
            - Buckets: \(histData?.buckets.count ?? 0)
            - Average: \(histData?.average ?? 0)
            - Count: \(histData?.count ?? 0)
            """)
        
        return histData
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetricHeaderView(metricName: metricName, description: description)
            
            // Current values display
            if let histogram = getCurrentHistogram() {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Average")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatValue(histogram.average))
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Count")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatValue(histogram.count))
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("p50")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatValue(histogram.percentile(50)))
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("p90")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatValue(histogram.percentile(90)))
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("p99")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatValue(histogram.percentile(99)))
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                .padding(.vertical, 4)
                
                // Bucket distribution chart
                Chart {
                    ForEach(histogram.buckets.filter { !$0.le.isInfinite }, id: \.le) { bucket in
                        BarMark(
                            x: .value("Upper Bound", formatValue(bucket.le)),
                            y: .value("Count", bucket.count)
                        )
                        .foregroundStyle(.green.gradient)
                    }
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                            .foregroundStyle(.primary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            } else {
                Text("No histogram data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// Main metric chart view that delegates to the appropriate type-specific view
struct MetricChartView: View {
    let metricName: String
    let description: String
    let type: MetricType
    let values: [(timestamp: Date, value: Double)]
    let labels: [String: String]
    let gridColumns: Int
    @ObservedObject var metricsManager: MetricsManager
    
    var body: some View {
        Group {
            switch type {
            case .counter:
                CounterMetricView(
                    metricName: metricName,
                    description: description,
                    values: values,
                    labels: labels,
                    metricsManager: metricsManager
                )
                .onAppear {
                    CollectorLogger.shared.debug("[\(metricName)] Counter view appeared with \(values.count) data points")
                }
            case .gauge:
                GaugeMetricView(
                    metricName: metricName,
                    description: description,
                    values: values,
                    labels: labels,
                    metricsManager: metricsManager
                )
                .onAppear {
                    CollectorLogger.shared.debug("[\(metricName)] Gauge view appeared with \(values.count) data points")
                }
            case .histogram:
                HistogramMetricView(
                    metricName: metricName,
                    description: description,
                    values: values,
                    labels: labels,
                    gridColumns: gridColumns,
                    metricsManager: metricsManager
                )
                .onAppear {
                    CollectorLogger.shared.debug("[\(metricName)] Histogram view appeared with \(values.count) data points")
                }
            }
        }
    }
}

// Helper function for value formatting
func formatValue(_ value: Double) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fM", value / 1_000_000)
    } else if value >= 1_000 {
        return String(format: "%.1fK", value / 1_000)
    } else if value < 0.01 {
        return String(format: "%.3f", value)
    } else if value.truncatingRemainder(dividingBy: 1) == 0 {
        return String(format: "%.0f", value)
    } else {
        return String(format: "%.2f", value)
    }
}

struct MetricsView: View {
    @ObservedObject var metricsManager: MetricsManager
    @State private var gridColumns = 2
    @State private var hasInitialData = false
    
    private func groupedMetrics() -> [TimeSeriesData] {
        let metrics = Array(metricsManager.metrics.values)
        var grouped: [String: TimeSeriesData] = [:]
        
        for metric in metrics {
            let name = metric.name
            // Skip derived metrics (percentiles, averages) as they'll be shown with their parent
            if name.hasSuffix("_p50") || name.hasSuffix("_p90") || 
               name.hasSuffix("_p99") || name.hasSuffix("_avg") {
                continue
            }
            grouped[name] = metric
            CollectorLogger.shared.debug("Grouped metric: \(name) with \(metric.values.count) points, type: \(String(describing: metric.definition?.type))")
        }
        
        return Array(grouped.values).sorted { $0.name < $1.name }
    }
    
    var body: some View {
        ScrollView {
            if metricsManager.metrics.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: hasInitialData ? "chart.line.downtrend.xyaxis" : "arrow.clockwise")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                        .symbolEffect(.bounce, value: !hasInitialData)
                    Text(hasInitialData ? "No metrics available" : "Loading metrics...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                VStack(spacing: 12) {
                    // Regular metrics in a grid
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: gridColumns),
                        spacing: 12
                    ) {
                        ForEach(groupedMetrics().filter { $0.definition?.type != .histogram }, id: \.name) { metric in
                            if let definition = metric.definition {
                                MetricChartView(
                                    metricName: metric.name,
                                    description: definition.description,
                                    type: definition.type,
                                    values: metric.values,
                                    labels: metric.labels,
                                    gridColumns: gridColumns,
                                    metricsManager: metricsManager
                                )
                            }
                        }
                    }
                    
                    // Histograms in full-width rows
                    ForEach(groupedMetrics().filter { $0.definition?.type == .histogram }, id: \.name) { metric in
                        if let definition = metric.definition {
                            MetricChartView(
                                metricName: metric.name,
                                description: definition.description,
                                type: definition.type,
                                values: metric.values,
                                labels: metric.labels,
                                gridColumns: gridColumns,
                                metricsManager: metricsManager
                            )
                        }
                    }
                }
                .padding(12)
            }
        }
        .onAppear {
            updateGridColumns()
            // After 15 seconds (one scrape interval), we consider the initial data load complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                hasInitialData = true
            }
        }
        .onChange(of: NSScreen.main?.visibleFrame.width) { oldValue, newValue in
            updateGridColumns()
        }
    }
    
    private func updateGridColumns() {
        if let width = NSScreen.main?.visibleFrame.width {
            // Adjust column count based on available width
            gridColumns = width > 1400 ? 3 : (width > 800 ? 2 : 1)
        }
    }
} 