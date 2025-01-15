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
                .accessibilityAddTraits(.isHeader)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .accessibilityLabel("Description: \(description)")
        }
    }
}

// Common tooltip view for charts
struct MetricTooltipView: View {
    let timestamp: Date
    let value: Double
    let values: [(timestamp: Date, value: Double)]
    let color: Color
    let xPosition: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current value and timestamp
            HStack {
                Text(formatValue(value))
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(color)
                Text("at")
                    .foregroundStyle(.secondary)
                Text(timestamp, format: .dateTime.hour().minute().second())
                    .foregroundStyle(.secondary)
            }
            
            // Mini sparkline
            Chart(values, id: \.timestamp) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color.opacity(0.5))
                
                if point.timestamp == timestamp {
                    PointMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                }
            }
            .frame(width: 120, height: 40)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
        .padding(8)
        .background(.background)
        .cornerRadius(8)
        .shadow(radius: 2)
        .position(x: xPosition, y: 20)
    }
}

// Helper view for chart overlays
struct ChartOverlayView: View {
    let values: [(timestamp: Date, value: Double)]
    let onSelection: (Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let x = value.location.x
                            let xScale = geometry.size.width / CGFloat(values.count - 1)
                            let index = Int((x / xScale).rounded())
                            if index >= 0 && index < values.count {
                                onSelection(index)
                            }
                        }
                )
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
            
            ChartView(
                values: calculateRates(),
                color: .blue
            )
            
            HStack(spacing: 8) {
                Text("Rate: \(formatValue(calculateRates().last?.value ?? 0))/s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1, y: 1)
    }
}

struct ChartView: View {
    let values: [(timestamp: Date, value: Double)]
    let color: Color
    var height: CGFloat = 100
    var showYAxis: Bool = true
    @State private var selectedPoint: (timestamp: Date, value: Double)?
    
    private func findClosestPoint(at xPosition: CGFloat, in size: CGSize) -> (timestamp: Date, value: Double)? {
        guard !values.isEmpty else { return nil }
        
        let relativeXPosition = max(0, min(xPosition, size.width)) / size.width
        let timeRange = values.last!.timestamp.timeIntervalSince(values.first!.timestamp)
        let date = values.first!.timestamp.addingTimeInterval(timeRange * Double(relativeXPosition))
        
        return values.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
    }
    
    var body: some View {
        Chart {
            ForEach(values, id: \.timestamp) { dataPoint in
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Value", dataPoint.value)
                )
                .foregroundStyle(color.gradient)
                .interpolationMethod(.catmullRom)
            }
            
            if let point = selectedPoint {
                RuleMark(x: .value("Time", point.timestamp))
                    .foregroundStyle(.gray.opacity(0.3))
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
            }
        }
        .frame(height: height)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis(showYAxis ? .automatic : .hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            selectedPoint = findClosestPoint(at: location.x, in: geometry.size)
                        case .ended:
                            selectedPoint = nil
                        }
                    }
                    .overlay {
                        if let point = selectedPoint {
                            VStack(alignment: .leading) {
                                Text(formatValue(point.value))
                                    .font(.headline)
                                    .foregroundStyle(color)
                                Text(point.timestamp.formatted(.dateTime.hour().minute().second()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(.background)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            .offset(y: -height/2)
                        }
                    }
            }
        }
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
                .foregroundStyle(.orange)
                .padding(.vertical, 4)
                .accessibilityLabel("Current value: \(formatValue(values.last?.value ?? 0))")
            
            ChartView(
                values: values,
                color: .orange,
                height: 60
            )
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1, y: 1)
    }
}

struct HistogramChartView: View {
    let buckets: [(le: Double, count: Double)]
    let totalCount: Double
    @State private var selectedBucket: (le: Double, count: Double)?
    
    private func findClosestBucket(at xPosition: CGFloat, in size: CGSize) -> (le: Double, count: Double)? {
        guard !buckets.isEmpty else { return nil }
        
        let relativeXPosition = max(0, min(xPosition, size.width)) / size.width
        let index = Int((relativeXPosition * Double(buckets.count - 1)).rounded())
        return (0..<buckets.count).contains(index) ? buckets[index] : nil
    }
    
    var body: some View {
        Chart {
            ForEach(buckets.indices, id: \.self) { index in
                let bucket = buckets[index]
                BarMark(
                    x: .value("Upper Bound", formatValue(bucket.le)),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(.green.gradient)
                .annotation(position: .top) {
                    Text(formatValue(bucket.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let bucket = selectedBucket {
                RuleMark(
                    x: .value("Upper Bound", formatValue(bucket.le))
                )
                .foregroundStyle(.gray.opacity(0.3))
            }
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
                    .foregroundStyle(.primary)
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
                            selectedBucket = findClosestBucket(at: location.x, in: geometry.size)
                        case .ended:
                            selectedBucket = nil
                        }
                    }
                    .overlay {
                        if let bucket = selectedBucket {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("≤ \(formatValue(bucket.le))")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                Text("Count: \(formatValue(bucket.count))")
                                    .foregroundStyle(.secondary)
                                Text("\(Int((bucket.count / totalCount) * 100))% of total")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(.background)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                    }
            }
        }
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
        return metricsManager.histogramData[key]?.last
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetricHeaderView(metricName: metricName, description: description)
            
            if let histogram = getCurrentHistogram() {
                // Current values display
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        StatView(title: "Average", value: formatValue(histogram.average))
                        StatView(title: "Count", value: formatValue(histogram.count))
                        StatView(title: "p50", value: formatValue(histogram.percentile(50)))
                        StatView(title: "p90", value: formatValue(histogram.percentile(90)))
                        StatView(title: "p99", value: formatValue(histogram.percentile(99)))
                    }
                }
                .padding(.vertical, 4)
                
                // Bucket distribution chart
                let buckets = histogram.buckets.filter { !$0.le.isInfinite }
                HistogramChartView(
                    buckets: buckets,
                    totalCount: histogram.count
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

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .medium))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
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
    
    private func groupedMetrics() -> [(String, [TimeSeriesData])] {
        let metrics = Array(metricsManager.metrics.values)
        var grouped: [MetricType: [TimeSeriesData]] = [:]
        
        for metric in metrics {
            let name = metric.name
            // Skip derived metrics (percentiles, averages) as they'll be shown with their parent
            if name.hasSuffix("_p50") || name.hasSuffix("_p90") || 
               name.hasSuffix("_p99") || name.hasSuffix("_avg") {
                continue
            }
            if let definition = metric.definition {
                grouped[definition.type, default: []].append(metric)
            }
        }
        
        return [
            ("Counters", grouped[.counter]?.sorted(by: { $0.name < $1.name }) ?? []),
            ("Gauges", grouped[.gauge]?.sorted(by: { $0.name < $1.name }) ?? []),
            ("Histograms", grouped[.histogram]?.sorted(by: { $0.name < $1.name }) ?? [])
        ]
    }
    
    var body: some View {
        ScrollView {
            if metricsManager.metrics.isEmpty {
                ContentUnavailableView {
                    Label("No Metrics", systemImage: hasInitialData ? "chart.line.downtrend.xyaxis" : "arrow.clockwise")
                        .symbolEffect(.bounce, value: !hasInitialData)
                } description: {
                    Text(hasInitialData ? "No metrics available" : "Loading metrics...")
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedMetrics(), id: \.0) { group in
                        if !group.1.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.0)
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                
                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(minimum: 100), spacing: 8), count: group.0 == "Histograms" ? 1 : gridColumns),
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(group.1, id: \.name) { metric in
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
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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