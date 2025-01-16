import SwiftUI
import Charts
import os

private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricsView")

// Helper extension for label formatting
extension Dictionary where Key == String, Value == String {
    func formattedLabelsString() -> String {
        guard !isEmpty else { return "" }
        return self
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }
}

// Base protocol for metric views
protocol MetricViewType {
    var metricName: String { get }
    var description: String { get }
    var values: [(timestamp: Date, value: Double, labels: [String: String])] { get }
    var labels: [String: String] { get }
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
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

// Basic chart component
struct BasicChartView: View {
    let values: [(timestamp: Date, value: Double, labels: [String: String])]
    let color: Color
    var height: CGFloat = 200
    var showYAxis: Bool = true
    private let maxPoints = 100
    @State private var selectedPoint: (timestamp: Date, value: Double, labels: [String: String])?
    @State private var tooltipPosition: CGPoint = .zero
    
    private var displayValues: [(timestamp: Date, value: Double, labels: [String: String])] {
        // Ensure values are sorted by timestamp
        Array(values.suffix(maxPoints)).sorted { $0.timestamp < $1.timestamp }
    }
    
    private var yRange: ClosedRange<Double> {
        let values = displayValues.map(\.value)
        guard !values.isEmpty else { return 0...1 }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = maxValue - minValue
        return (minValue - range * 0.1)...(maxValue + range * 0.1)
    }
    
    private func findClosestPoint(at location: CGPoint, in proxy: ChartProxy, frame: CGRect) -> (point: (timestamp: Date, value: Double, labels: [String: String]), xPosition: CGFloat)? {
        let xPosition = location.x - frame.origin.x
        guard let date: Date = proxy.value(atX: xPosition, as: Date.self),
              !displayValues.isEmpty else { return nil }
        
        let point = displayValues.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
        guard let foundPoint = point else { return nil }
        
        // Convert the point's timestamp back to x coordinate
        if let pointLocation = proxy.position(for: (x: foundPoint.timestamp, y: foundPoint.value)) {
            return (foundPoint, pointLocation.x + frame.origin.x)
        }
        return nil
    }
    
    private var legendText: String {
        guard let firstLabels = values.first?.labels else { return "" }
        return firstLabels.formattedLabelsString()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart(displayValues, id: \.timestamp) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color.gradient)
                .interpolationMethod(.catmullRom)
                
                if selectedPoint?.timestamp == point.timestamp {
                    PointMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .symbolSize(100)
                }
            }
            .chartYScale(domain: yRange)
            .frame(height: height)
            .chartYAxis(showYAxis ? .automatic : .hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour().minute().second())
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if let (point, xPos) = findClosestPoint(at: location, in: proxy, frame: geometry.frame(in: .local)) {
                                    withAnimation(.easeInOut(duration: 0.05)) {
                                        selectedPoint = point
                                        tooltipPosition = CGPoint(x: xPos, y: 0)
                                    }
                                }
                            case .ended:
                                withAnimation(.easeInOut(duration: 0.05)) {
                                    selectedPoint = nil
                                }
                            }
                        }
                }
            }
            .overlay(alignment: .bottom) {
                if let point = selectedPoint {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                            Text(formatValue(point.value))
                                .font(.callout)
                                .foregroundStyle(color)
                            Text("at")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(point.timestamp.formatted(.dateTime.hour().minute().second()))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(6)
                    .background(.background.opacity(0.95))
                    .cornerRadius(6)
                    .shadow(radius: 1)
                    .padding(.bottom, 8)
                    .zIndex(1)
                    .transition(.opacity)
                }
            }
            
            if !legendText.isEmpty {
                Text(legendText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
    }
}

// Counter metric view
struct CounterMetricView: View, MetricViewType {
    let metricName: String
    let description: String
    let values: [(timestamp: Date, value: Double, labels: [String: String])]
    let labels: [String: String]
    @ObservedObject private var metricsManager = MetricsManager.shared
    
    private func calculateRates(for values: [(timestamp: Date, value: Double, labels: [String: String])]) -> [(timestamp: Date, value: Double, labels: [String: String])] {
        // Need at least 2 points for rate calculation
        guard values.count >= 2 else { return [] }
        
        // Window size for rate calculation (similar to Prometheus default range)
        let windowSize: TimeInterval = 300 // 5 minutes
        
        var rates: [(timestamp: Date, value: Double, labels: [String: String])] = []
        
        // Calculate rates for each point using a sliding window
        for i in 0..<values.count {
            let currentTime = values[i].timestamp
            
            // Find points within the window
            let windowStart = currentTime.addingTimeInterval(-windowSize)
            let windowPoints = values.filter { 
                $0.timestamp <= currentTime && $0.timestamp >= windowStart 
            }
            
            // Need at least 2 points in window for calculation
            guard windowPoints.count >= 2 else { continue }
            
            // Prepare points for linear regression
            var sumX: Double = 0
            var sumY: Double = 0
            var sumXX: Double = 0
            var sumXY: Double = 0
            let n = Double(windowPoints.count)
            
            // Calculate relative timestamps to avoid floating point precision issues
            let firstTimestamp = windowPoints[0].timestamp.timeIntervalSince1970
            
            for point in windowPoints {
                let x = point.timestamp.timeIntervalSince1970 - firstTimestamp
                var y = point.value
                
                // Handle counter resets
                if let prevPoint = windowPoints.first(where: { $0.timestamp < point.timestamp }),
                   y < prevPoint.value {
                    y += prevPoint.value // On reset, add previous value
                }
                
                sumX += x
                sumY += y
                sumXX += x * x
                sumXY += x * y
            }
            
            // Calculate rate using linear regression
            let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
            
            // Convert slope from per-second to per-second (it already is, as we used seconds)
            rates.append((
                timestamp: currentTime,
                value: max(0, slope), // Rates should never be negative
                labels: values[i].labels
            ))
        }
        
        return rates
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetricHeaderView(metricName: metricName, description: description)
            BasicChartView(
                values: calculateRates(for: values),
                color: .blue
            )
            
            if let lastRate = calculateRates(for: values).last?.value {
                Text("Rate: \(formatValue(lastRate))/s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1, y: 1)
    }
}

// Gauge metric view
struct GaugeMetricView: View, MetricViewType {
    let metricName: String
    let description: String
    let values: [(timestamp: Date, value: Double, labels: [String: String])]
    let labels: [String: String]
    @ObservedObject private var metricsManager = MetricsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetricHeaderView(metricName: metricName, description: description)
            
            // Center the value vertically in the same space a chart would take
            Spacer()
            if let lastValue = values.last?.value {
                Text(formatValue(lastValue))
                    .font(.system(size: 48, weight: .medium, design: .monospaced))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .minimumScaleFactor(0.5) // Allow text to scale down if needed
                    .lineLimit(1)
            }
            Spacer()
            
            if !labels.isEmpty {
                Text(labels.formattedLabelsString())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .frame(height: 300) // Match the height of chart views
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1, y: 1)
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

// Optimized histogram chart view
struct HistogramChartView: View {
    let buckets: [(le: Double, count: Double)]
    let totalCount: Double
    let labels: [String: String]
    @State private var selectedBucket: (le: Double, count: Double)?
    
    var body: some View {
        VStack(spacing: 8) {
            // Summary statistics
            HStack(spacing: 16) {
                Text("Total Count: \(formatValue(totalCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let lastBucket = buckets.last {
                    Text("Max: \(formatValue(lastBucket.le))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Chart(buckets, id: \.le) { bucket in
                BarMark(
                    x: .value("Upper Bound", bucket.le),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(.green.gradient)
                
                if selectedBucket?.le == bucket.le {
                    RuleMark(
                        x: .value("Selected", bucket.le)
                    )
                    .foregroundStyle(.secondary.opacity(0.3))
                }
            }
            .frame(height: 250)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatValue(v))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let xPosition = location.x - geometry.frame(in: .local).minX
                                
                                if let value = proxy.value(atX: xPosition, as: Double.self),
                                   let closest = buckets.min(by: { abs($0.le - value) < abs($1.le - value) }) {
                                    withAnimation(.easeInOut(duration: 0.05)) {
                                        selectedBucket = closest
                                    }
                                }
                            case .ended:
                                withAnimation(.easeInOut(duration: 0.05)) {
                                    selectedBucket = nil
                                }
                            }
                        }
                }
            }
            .overlay(alignment: .top) {
                if let bucket = selectedBucket {
                    HStack(spacing: 4) {
                        Text("≤ \(formatValue(bucket.le))")
                            .font(.callout)
                            .foregroundStyle(.green)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(formatValue(bucket.count)) samples")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int((bucket.count / totalCount) * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                    .background(.background.opacity(0.95))
                    .cornerRadius(6)
                    .shadow(radius: 1)
                }
            }
            
            if !labels.isEmpty {
                Text(labels.formattedLabelsString())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
    }
}

// Histogram metric view
struct HistogramMetricView: View, MetricViewType {
    let metricName: String
    let description: String
    let values: [(timestamp: Date, value: Double, labels: [String: String])]
    let labels: [String: String]
    @ObservedObject private var metricsManager = MetricsManager.shared
    
    private func getCurrentHistogram() -> HistogramData? {
        // Remove any _bucket, _sum, or _count suffixes to get the base name
        let baseName = metricName
            .replacingOccurrences(of: "_bucket", with: "")
            .replacingOccurrences(of: "_sum", with: "")
            .replacingOccurrences(of: "_count", with: "")
        
        let key = metricsManager.metricKey(name: baseName, labels: labels)
        logger.debug("Getting histogram data for key: \(key), base name: \(baseName)")
        
        let data = metricsManager.histogramData[key]?.last
        if let data = data {
            logger.debug("Found histogram data: buckets=\(data.buckets.count), sum=\(data.sum), count=\(data.count)")
        } else {
            logger.debug("No histogram data found for key: \(key)")
            logger.debug("Available histogram keys: \(metricsManager.histogramData.keys.joined(separator: ", "))")
            logger.debug("Available metric keys: \(metricsManager.metrics.keys.joined(separator: ", "))")
        }
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetricHeaderView(metricName: metricName, description: description)
            
            if let histogram = getCurrentHistogram() {
                // Summary Grid
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    GridRow {
                        Text("Average")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Count")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("p50")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("p90")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("p99")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    GridRow {
                        Text(formatValue(histogram.average))
                            .font(.system(.body, design: .monospaced))
                        Text(formatValue(histogram.count))
                            .font(.system(.body, design: .monospaced))
                        Text(formatValue(histogram.percentile(50)))
                            .font(.system(.body, design: .monospaced))
                        Text(formatValue(histogram.percentile(90)))
                            .font(.system(.body, design: .monospaced))
                        Text(formatValue(histogram.percentile(99)))
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(.vertical, 4)
                .onAppear {
                    logger.debug("Rendering histogram grid for \(metricName)")
                }
                
                // Bucket distribution chart
                let buckets = histogram.buckets.filter { !$0.le.isInfinite }
                HistogramChartView(
                    buckets: buckets,
                    totalCount: histogram.count,
                    labels: labels
                )
                .onAppear {
                    logger.debug("Rendering histogram chart for \(metricName) with \(buckets.count) buckets")
                }
            } else {
                ContentUnavailableView {
                    Label("No Data", systemImage: "chart.bar")
                } description: {
                    Text("No histogram data available")
                }
                .frame(height: 100)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1, y: 1)
        .onAppear {
            logger.debug("HistogramMetricView appeared for \(metricName)")
        }
    }
}

// Make TimeSeriesData identifiable
struct TimeSeriesData: Identifiable {
    let id: String
    let name: String
    let labels: [String: String]
    var values: [(timestamp: Date, value: Double, labels: [String: String])]
    let definition: MetricDefinition?
    
    // Keep last hour of data by default
    let maxAge: TimeInterval = 3600
    
    init(name: String, labels: [String: String], values: [(timestamp: Date, value: Double, labels: [String: String])], definition: MetricDefinition?) {
        self.id = MetricsManager.shared.metricKey(name: name, labels: labels)
        self.name = name
        self.labels = labels
        self.values = values
        self.definition = definition
    }
    
    mutating func addValue(_ value: Double, at timestamp: Date) {
        values.append((timestamp: timestamp, value: value, labels: labels))
        // Clean up old values
        let cutoff = Date().addingTimeInterval(-maxAge)
        values.removeAll { $0.timestamp < cutoff }
    }
}

// Regular metric row view
struct MetricRowView: View {
    let metrics: [TimeSeriesData]
    let columns: Int
    let spacing: CGFloat
    let itemWidth: CGFloat
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(metrics) { metric in
                if let definition = metric.definition {
                    Group {
                        switch definition.type {
                        case .counter:
                            CounterMetricView(
                                metricName: metric.name,
                                description: definition.description,
                                values: metric.values,
                                labels: metric.labels
                            )
                        case .gauge:
                            GaugeMetricView(
                                metricName: metric.name,
                                description: definition.description,
                                values: metric.values,
                                labels: metric.labels
                            )
                        case .histogram:
                            EmptyView() // Skip histograms as they're handled separately
                        }
                    }
                    .frame(width: itemWidth)
                    .frame(minHeight: 300)
                }
            }
            if metrics.count < columns {
                Spacer()
            }
        }
    }
}

// Main metrics view
struct MetricsView: View {
    @StateObject private var metricsManager = MetricsManager.shared
    @State private var hasInitialData = false
    
    private var metricCollection: MetricCollection {
        let collection = MetricCollection(metrics: metricsManager.metrics)
        logger.debug("MetricCollection created - Histograms: \(collection.histograms.count), Regular: \(collection.regular.count)")
        return collection
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if metricsManager.metrics.isEmpty {
                    ContentUnavailableView {
                        Label("No Metrics", systemImage: hasInitialData ? "chart.line.downtrend.xyaxis" : "arrow.clockwise")
                    } description: {
                        Text(hasInitialData ? "No metrics available" : "Loading metrics...")
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    let availableWidth = geometry.size.width - 32
                    let columns = max(1, min(3, Int(floor(availableWidth / 500))))
                    let spacing: CGFloat = 16
                    let itemWidth = (availableWidth - (spacing * CGFloat(columns - 1))) / CGFloat(columns)
                    
                    VStack(spacing: spacing) {
                        // Regular metrics grid
                        let rows = stride(from: 0, to: metricCollection.regular.count, by: columns).map {
                            Array(metricCollection.regular[$0..<min($0 + columns, metricCollection.regular.count)])
                        }
                        
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, rowMetrics in
                            MetricRowView(
                                metrics: rowMetrics,
                                columns: columns,
                                spacing: spacing,
                                itemWidth: itemWidth
                            )
                        }
                        
                        // Histogram metrics
                        ForEach(metricCollection.histograms) { metric in
                            if let definition = metric.definition {
                                HistogramMetricView(
                                    metricName: metric.name,
                                    description: definition.description,
                                    values: metric.values,
                                    labels: metric.labels
                                )
                                .frame(width: availableWidth)
                                .frame(minHeight: 400)
                                .onAppear {
                                    logger.debug("Histogram view appeared for: \(metric.name)")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            logger.debug("MetricsView appeared")
            metricsManager.startScraping()
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                hasInitialData = true
            }
        }
        .onDisappear {
            logger.debug("MetricsView disappeared")
            metricsManager.stopScraping()
        }
    }
} 