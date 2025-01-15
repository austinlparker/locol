import SwiftUI
import Charts

// Base protocol for metric views
protocol MetricViewType {
    var metricName: String { get }
    var description: String { get }
    var values: [(timestamp: Date, value: Double, labels: [String: String])] { get }
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
        guard let firstLabels = values.first?.labels,
              !firstLabels.isEmpty else { return "" }
        return firstLabels
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart(displayValues, id: \.timestamp) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color.gradient)
                .interpolationMethod(.linear)
                
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
    @ObservedObject var metricsManager: MetricsManager
    
    private func calculateRates(for values: [(timestamp: Date, value: Double, labels: [String: String])]) -> [(timestamp: Date, value: Double, labels: [String: String])] {
        guard values.count >= 2 else { return [] }
        
        var rates: [(timestamp: Date, value: Double, labels: [String: String])] = []
        var lastValue = values[0].value
        var lastTimestamp = values[0].timestamp
        
        for point in values.dropFirst() {
            let timeDiff = point.timestamp.timeIntervalSince(lastTimestamp)
            var valueDiff = point.value - lastValue
            
            if valueDiff < 0 {
                valueDiff = point.value
            }
            
            let rate = timeDiff > 0 ? valueDiff / timeDiff : 0
            rates.append((timestamp: point.timestamp, value: rate, labels: point.labels))
            
            lastValue = point.value
            lastTimestamp = point.timestamp
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
    @ObservedObject var metricsManager: MetricsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetricHeaderView(metricName: metricName, description: description)
            BasicChartView(
                values: values,
                color: .orange
            )
            
            if let lastValue = values.last?.value {
                Text("Value: \(formatValue(lastValue))")
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
    private let maxBuckets = 20 // Limit buckets to reduce complexity
    @State private var selectedBucket: (le: Double, count: Double)?
    @State private var tooltipPosition: CGPoint = .zero
    
    private var displayBuckets: [(le: Double, count: Double)] {
        // If we have more buckets than maxBuckets, sample them evenly
        if buckets.count > maxBuckets {
            let step = Double(buckets.count) / Double(maxBuckets)
            return stride(from: 0, to: Double(buckets.count), by: step)
                .map { Int($0) }
                .map { buckets[$0] }
        }
        return buckets
    }
    
    private func findClosestBucket(at location: CGPoint, in proxy: ChartProxy, frame: CGRect) -> (bucket: (le: Double, count: Double), xPosition: CGFloat)? {
        let xPosition = location.x - frame.origin.x
        guard let value: Double = proxy.value(atX: xPosition, as: Double.self) else { return nil }
        
        let bucket = displayBuckets.min(by: { abs($0.le - value) < abs($1.le - value) })
        guard let foundBucket = bucket else { return nil }
        
        // Convert the bucket's le value back to x coordinate
        if let bucketLocation = proxy.position(for: (x: foundBucket.le, y: foundBucket.count)) {
            return (foundBucket, bucketLocation.x + frame.origin.x)
        }
        return nil
    }
    
    private var legendText: String {
        guard !labels.isEmpty else { return "" }
        return labels
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }
    
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
            
            VStack(alignment: .leading, spacing: 4) {
                Chart(displayBuckets, id: \.le) { bucket in
                    BarMark(
                        x: .value("Upper Bound", formatValue(bucket.le)),
                        y: .value("Count", bucket.count)
                    )
                    .foregroundStyle(.green.gradient)
                    
                    if selectedBucket?.le == bucket.le {
                        RuleMark(
                            x: .value("Selected", formatValue(bucket.le))
                        )
                        .foregroundStyle(.secondary.opacity(0.3))
                    }
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
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
                                    if let (bucket, xPos) = findClosestBucket(at: location, in: proxy, frame: geometry.frame(in: .local)) {
                                        withAnimation(.easeInOut(duration: 0.05)) {
                                            selectedBucket = bucket
                                            tooltipPosition = CGPoint(x: xPos, y: 0)
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
                .overlay(alignment: .bottom) {
                    if let bucket = selectedBucket {
                        VStack(alignment: .leading, spacing: 2) {
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
}

// Histogram metric view
struct HistogramMetricView: View, MetricViewType {
    let metricName: String
    let description: String
    let values: [(timestamp: Date, value: Double, labels: [String: String])]
    let labels: [String: String]
    @ObservedObject var metricsManager: MetricsManager
    
    private func getCurrentHistogram() -> HistogramData? {
        let key = metricsManager.metricKey(name: metricName, labels: labels)
        return metricsManager.histogramData[key]?.last
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
                
                // Bucket distribution chart
                let buckets = histogram.buckets.filter { !$0.le.isInfinite }
                HistogramChartView(
                    buckets: buckets,
                    totalCount: histogram.count,
                    labels: labels
                )
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
    }
}

// Main metrics view
struct MetricsView: View {
    @ObservedObject var metricsManager: MetricsManager
    @State private var hasInitialData = false
    
    private var metrics: [TimeSeriesData] {
        Array(metricsManager.metrics.values)
            .filter { metric in
                // Filter out gauge metrics that are derived from histograms
                if let definition = metric.definition,
                   definition.type == .gauge,
                   metric.name.contains("_p") || metric.name.hasSuffix("_sum") || metric.name.hasSuffix("_count") {
                    return false
                }
                return true
            }
            // Sort metrics by name to maintain stable order
            .sorted { $0.name < $1.name }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if metrics.isEmpty {
                    ContentUnavailableView {
                        Label("No Metrics", systemImage: hasInitialData ? "chart.line.downtrend.xyaxis" : "arrow.clockwise")
                    } description: {
                        Text(hasInitialData ? "No metrics available" : "Loading metrics...")
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    let columns = max(1, min(3, Int(floor(geometry.size.width / 500))))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
                        ForEach(metrics, id: \.name) { metric in
                            if let definition = metric.definition {
                                Group {
                                    switch definition.type {
                                    case .counter:
                                        CounterMetricView(
                                            metricName: metric.name,
                                            description: definition.description,
                                            values: metric.values,
                                            labels: metric.labels,
                                            metricsManager: metricsManager
                                        )
                                    case .gauge:
                                        GaugeMetricView(
                                            metricName: metric.name,
                                            description: definition.description,
                                            values: metric.values,
                                            labels: metric.labels,
                                            metricsManager: metricsManager
                                        )
                                    case .histogram:
                                        HistogramMetricView(
                                            metricName: metric.name,
                                            description: definition.description,
                                            values: metric.values,
                                            labels: metric.labels,
                                            metricsManager: metricsManager
                                        )
                                        .gridCellColumns(columns)
                                    }
                                }
                                .frame(minHeight: definition.type == .histogram ? 400 : 300)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                hasInitialData = true
            }
        }
    }
} 