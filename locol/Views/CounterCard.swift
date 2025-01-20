import SwiftUI
import Charts

struct CounterCard: View {
    let name: String
    let series: [CounterSeries]
    @State private var selectedPoint: (timestamp: Date, points: [SeriesPoint])? = nil
    
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
    @Binding var selectedPoint: (timestamp: Date, points: [SeriesPoint])?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rate Over Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Chart {
                    ForEach(series, id: \.name) { (series: CounterSeries) in
                        ForEach(series.rates, id: \.timestamp) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Rate", point.rate)
                            )
                            .foregroundStyle(by: .value("Series", series.name))
                            .lineStyle(StrokeStyle(lineWidth: 2))
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
                        if let val = value.as(Double.self),
                           let firstMetric = series.first?.metrics.first {
                            AxisValueLabel {
                                Text(firstMetric.formatValueWithInferredUnit(val) + "/s")
                                    .font(.caption)
                            }
                        }
                        AxisGridLine()
                        AxisTick()
                    }
                }
                .chartLegend(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(.background.opacity(0.5))
                        .border(.quaternary)
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
                                    
                                    var points: [SeriesPoint] = []
                                    for series in series {
                                        // Find the closest rate point
                                        if let closestPoint = series.rates.min(by: { abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp)) }) {
                                            points.append(SeriesPoint(series: series, rate: closestPoint.rate))
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
                    ChartTooltip(timestamp: selectedPoint.timestamp, points: selectedPoint.points)
                } else {
                    ChartLegend(series: series)
                }
            }
        }
        .chartForegroundStyleScale([
            "processed_items{processor=batch}": ChartColors.color(for: "processed_items{processor=batch}"),
            "processed_items{processor=stream}": ChartColors.color(for: "processed_items{processor=stream}"),
            "processed_items{processor=filter}": ChartColors.color(for: "processed_items{processor=filter}")
        ])
    }
}

private struct ChartTooltip: View {
    let timestamp: Date
    let points: [SeriesPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timestamp.formatted(.dateTime.hour().minute().second()))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(points) { (point: SeriesPoint) in
                HStack(spacing: 8) {
                    Circle()
                        .fill(point.color)
                        .frame(width: 8, height: 8)
                    LabelDisplay(labels: point.series.labels, showAll: false, showOnlyPrimary: true)
                    Text((point.series.metrics.first?.formatValueWithInferredUnit(point.rate))! + "/s")
                        .font(.caption.bold())
                }
            }
        }
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

private struct ChartLegend: View {
    let series: [CounterSeries]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(series, id: \.name) { (series: CounterSeries) in
                HStack(spacing: 8) {
                    Circle()
                        .fill(ChartColors.color(for: series.name))
                        .frame(width: 8, height: 8)
                    LabelDisplay(labels: series.labels, showAll: false)
                    Text((series.metrics.first?.formatValueWithInferredUnit(series.currentRate))! + "/s")
                        .font(.caption.bold())
                }
            }
        }
        .padding(.vertical, 6)
        .frame(height: 28)
        .frame(maxWidth: .infinity)
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
    
    let filterMetrics = [
        Metric(
            name: "processed_items",
            type: .counter,
            help: "Number of items processed",
            labels: ["processor": "filter"],
            timestamp: now.addingTimeInterval(-60),
            value: 0,
            histogram: nil
        ),
        Metric(
            name: "processed_items",
            type: .counter,
            help: "Number of items processed",
            labels: ["processor": "filter"],
            timestamp: now.addingTimeInterval(-30),
            value: 37,
            histogram: nil
        ),
        Metric(
            name: "processed_items",
            type: .counter,
            help: "Number of items processed",
            labels: ["processor": "filter"],
            timestamp: now,
            value: 75,
            histogram: nil
        )
    ]
    
    return CounterCard(
        name: "Processed Items",
        series: [
            CounterSeries(
                name: "processed_items{processor=batch}",
                metrics: batchMetrics,
                labels: ["processor": "batch"],
                currentRate: 1.67
            ),
            CounterSeries(
                name: "processed_items{processor=stream}",
                metrics: streamMetrics,
                labels: ["processor": "stream"],
                currentRate: 4.17
            ),
            CounterSeries(
                name: "processed_items{processor=filter}",
                metrics: filterMetrics,
                labels: ["processor": "filter"],
                currentRate: 1.25
            )
        ]
    )
    .frame(width: 800)
    .padding()
} 

