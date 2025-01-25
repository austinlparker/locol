import SwiftUI
import Charts

struct CounterCard: View {
    let name: String
    let series: [CounterSeries]
    @State private var selectedPoint: (timestamp: Date, points: [MetricPoint])? = nil
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                Text(name)
                    .font(.headline)
                
                // Chart
                RateChart(series: series, selectedPoint: $selectedPoint)
                    .frame(height: 200)
            }
            .padding()
        }
    }
}

private struct RateChart: View {
    let series: [CounterSeries]
    @Binding var selectedPoint: (timestamp: Date, points: [MetricPoint])?
    
    // Window size for rate calculation (in seconds)
    private let windowSize: TimeInterval = 60
    
    private var windowText: String {
        if windowSize >= 60 {
            return "\(Int(windowSize/60))m"
        } else {
            return "\(Int(windowSize))s"
        }
    }
    
    private func calculateSmoothRate(metrics: [Metric], at timestamp: Date) -> Double? {
        // Find metrics within our window
        let windowStart = timestamp.addingTimeInterval(-windowSize)
        let windowMetrics = metrics.filter { $0.timestamp >= windowStart && $0.timestamp <= timestamp }
            .sorted { $0.timestamp < $1.timestamp }
        
        guard windowMetrics.count >= 2,
              let first = windowMetrics.first,
              let last = windowMetrics.last else {
            return nil
        }
        
        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)
        guard timeDelta > 0 else { return nil }
        
        return (last.value - first.value) / timeDelta
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text("Rate Over Time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(windowText)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            ChartContainer {
                Chart {
                    ForEach(series, id: \.name) { series in
                        // Plot smoothed rates for each metric timestamp
                        ForEach(series.metrics.indices, id: \.self) { i in
                            if let rate = calculateSmoothRate(
                                metrics: series.metrics,
                                at: series.metrics[i].timestamp
                            ) {
                                LineMark(
                                    x: .value("Time", series.metrics[i].timestamp),
                                    y: .value("Rate", rate)
                                )
                                .foregroundStyle(by: .value("Series", series.name))
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.monotone)
                            }
                        }
                    }
                    
                    if let selectedPoint = selectedPoint {
                        RuleMark(x: .value("Time", selectedPoint.timestamp))
                            .foregroundStyle(.gray.opacity(0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let val = value.as(Double.self) {
                            AxisValueLabel {
                                Text(formatRate(val))
                                    .font(.caption)
                            }
                        }
                        AxisGridLine()
                        AxisTick()
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
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = location.x - geometry[plotFrame].origin.x
                                    guard x >= 0, x <= geometry[plotFrame].width else {
                                        selectedPoint = nil
                                        return
                                    }
                                    
                                    guard let timestamp = proxy.value(atX: x) as Date? else { return }
                                    
                                    var points: [MetricPoint] = []
                                    for series in series {
                                        if let rate = calculateSmoothRate(metrics: series.metrics, at: timestamp) {
                                            points.append(MetricPoint(
                                                series: series,
                                                value: rate,
                                                timestamp: timestamp
                                            ))
                                        }
                                    }
                                    
                                    selectedPoint = (timestamp: timestamp, points: points)
                                    
                                case .ended:
                                    selectedPoint = nil
                                }
                            }
                    }
                }
                
                // Legend or Tooltip area with fixed height
                if let selectedPoint = selectedPoint {
                    BaseTooltip {
                        VStack(alignment: .leading, spacing: 4) {
                            TimeLabel(timestamp: selectedPoint.timestamp)
                            ForEach(selectedPoint.points) { point in
                                HStack(spacing: 8) {
                                    MetricLegendItem(
                                        color: point.color,
                                        label: formatRate(point.value)
                                    )
                                    LabelDisplay(labels: point.series.labels, showAll: false, showOnlyPrimary: true)
                                }
                            }
                        }
                    }
                } else {
                    BaseTooltip {
                        HStack(spacing: 16) {
                            ForEach(series, id: \.name) { series in
                                HStack(spacing: 8) {
                                    MetricLegendItem(
                                        color: ChartColors.color(for: series.name),
                                        label: formatRate(series.rateInfo.rate)
                                    )
                                    LabelDisplay(labels: series.labels, showAll: false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func formatRate(_ rate: Double) -> String {
        if rate >= 1_000_000 {
            return String(format: "%.1fM/s", rate / 1_000_000)
        } else if rate >= 1_000 {
            return String(format: "%.1fK/s", rate / 1_000)
        } else if rate >= 100 {
            return String(format: "%.0f/s", rate)
        } else if rate >= 10 {
            return String(format: "%.1f/s", rate)
        } else {
            return String(format: "%.2f/s", rate)
        }
    }
}

struct MetricPoint: Identifiable {
    let id: String
    let series: CounterSeries
    let value: Double
    let timestamp: Date
    
    var color: Color {
        ChartColors.color(for: series.name)
    }
    
    init(series: CounterSeries, value: Double, timestamp: Date) {
        self.id = series.name
        self.series = series
        self.value = value
        self.timestamp = timestamp
    }
}

#Preview {
    let now = Date()
    let batchMetrics = [
        Metric(
            name: "processed_items",
            type: .counter,
            help: "Number of items processed",
            labels: ["processor": "batch"],
            timestamp: now.addingTimeInterval(-60),
            value: 0,
            histogram: nil
        ),
        Metric(
            name: "processed_items",
            type: .counter,
            help: "Number of items processed",
            labels: ["processor": "batch"],
            timestamp: now.addingTimeInterval(-30),
            value: 50,
            histogram: nil
        ),
        Metric(
            name: "processed_items",
            type: .counter,
            help: "Number of items processed",
            labels: ["processor": "batch"],
            timestamp: now,
            value: 100,
            histogram: nil
        )
    ]
    
    let streamMetrics = [
        Metric(
            name: "processed_items",
            type: .counter,
            help: "Number of items processed",
            labels: ["processor": "stream"],
            timestamp: now.addingTimeInterval(-60),
            value: 0,
            histogram: nil
        ),
        Metric(
            name: "processed_items",
            type: .counter,
            help: "Number of items processed",
            labels: ["processor": "stream"],
            timestamp: now.addingTimeInterval(-30),
            value: 125,
            histogram: nil
        ),
        Metric(
            name: "processed_items",
            type: .counter,
            help: "Number of items processed",
            labels: ["processor": "stream"],
            timestamp: now,
            value: 250,
            histogram: nil
        )
    ]
    
    let batchSeries = CounterSeries(
        name: "{processor=batch}",
        metrics: batchMetrics,
        labels: ["processor": "batch"],
        rateInfo: MetricsManager.RateInfo(
            rate: 1.67, // 100 items / 60 seconds
            timeWindow: 60,
            firstTimestamp: now.addingTimeInterval(-60),
            lastTimestamp: now
        )
    )
    
    let streamSeries = CounterSeries(
        name: "{processor=stream}",
        metrics: streamMetrics,
        labels: ["processor": "stream"],
        rateInfo: MetricsManager.RateInfo(
            rate: 4.17, // 250 items / 60 seconds
            timeWindow: 60,
            firstTimestamp: now.addingTimeInterval(-60),
            lastTimestamp: now
        )
    )
    
    CounterCard(name: "Processed Items", series: [batchSeries, streamSeries])
        .frame(width: 400)
        .padding()
} 

