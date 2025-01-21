import SwiftUI
import Charts

enum GaugeVisualization {
    case number
    case radial
    case lineChart
    
    var icon: String {
        switch self {
        case .number: return "number"
        case .radial: return "gauge.medium"
        case .lineChart: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct GaugeCard: View {
    let metrics: [Metric]
    @State private var selectedValue: (timestamp: Date, value: Double)? = nil
    @State private var visualization: GaugeVisualization = .lineChart
    
    private var seriesName: String {
        // Create a series name in the format "{key=value}" using the first label
        if let (key, value) = metrics[0].labels.first {
            return "{\(key)=\(value)}"
        }
        return "{unnamed}"
    }
    
    private var seriesColor: Color {
        ChartColors.color(for: seriesName)
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                Text(metrics[0].name)
                    .font(.headline)
                
                // Chart
                switch visualization {
                case .number:
                    NumberView(value: metrics.last?.value ?? 0, metric: metrics[0], color: seriesColor)
                case .radial:
                    RadialView(value: metrics.last?.value ?? 0, metric: metrics[0], color: seriesColor)
                case .lineChart:
                    LineChartView(metrics: metrics, selectedValue: $selectedValue, seriesName: seriesName)
                }
            }
            .padding()
        }
    }
}

private struct LineChartView: View {
    let metrics: [Metric]
    @Binding var selectedValue: (timestamp: Date, value: Double)?
    let seriesName: String
    
    private var seriesColor: Color {
        ChartColors.color(for: seriesName)
    }
    
    private var currentValue: Double {
        metrics.last?.value ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Value Over Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ChartContainer {
                Chart {
                    ForEach(metrics, id: \.timestamp) { metric in
                        LineMark(
                            x: .value("Time", metric.timestamp),
                            y: .value("Value", metric.value)
                        )
                        .foregroundStyle(seriesColor)
                    }
                    
                    if let selectedValue = selectedValue {
                        RuleMark(x: .value("Time", selectedValue.timestamp))
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
                        let val = value.as(Double.self)!
                        AxisValueLabel {
                            Text(metrics[0].formatValueWithInferredUnit(val))
                                .font(.caption)
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
                                        selectedValue = nil
                                        return
                                    }
                                    
                                    guard let timestamp = proxy.value(atX: x) as Date? else { return }
                                    
                                    // Find the closest metric point to the hovered timestamp
                                    if let closestMetric = metrics.min(by: {
                                        abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp))
                                    }) {
                                        selectedValue = (timestamp: closestMetric.timestamp, value: closestMetric.value)
                                    }
                                    
                                case .ended:
                                    selectedValue = nil
                                }
                            }
                    }
                }
                
                // Legend or Tooltip area with fixed height
                if let selectedValue = selectedValue {
                    BaseTooltip {
                        VStack(alignment: .leading, spacing: 4) {
                            TimeLabel(timestamp: selectedValue.timestamp)
                            HStack(spacing: 8) {
                                MetricLegendItem(
                                    color: seriesColor,
                                    label: metrics[0].formatValueWithInferredUnit(selectedValue.value)
                                )
                                LabelDisplay(labels: metrics[0].labels, showAll: false, showOnlyPrimary: true)
                            }
                        }
                    }
                } else {
                    BaseTooltip {
                        HStack(spacing: 8) {
                            MetricLegendItem(
                                color: seriesColor,
                                label: "Current: \(metrics[0].formatValueWithInferredUnit(currentValue))"
                            )
                            LabelDisplay(labels: metrics[0].labels, showAll: false)
                        }
                    }
                }
            }
        }
    }
}

private struct NumberView: View {
    let value: Double
    let metric: Metric
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Value")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(metric.formatValueWithInferredUnit(value))
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}

private struct RadialView: View {
    let value: Double
    let metric: Metric
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Gauge(value: min(max(value, 0), value + 100), in: 0...(value + 100)) {
                Text(metric.formatValueWithInferredUnit(value))
            } currentValueLabel: {
                Text(metric.formatValueWithInferredUnit(value))
                    .font(.system(.headline, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(color)
            .scaleEffect(2.5)
            .frame(height: 120)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

#Preview {
    let now = Date()
    let metrics = (0..<10).map { i in
        Metric(
            name: "Test Gauge",
            type: .gauge,
            help: "help text",
            labels: ["component": "memory", "type": "usage"],
            timestamp: now.addingTimeInterval(TimeInterval(i * 60)),
            value: Double.random(in: 50...80),
            histogram: nil
        )
    }
    
    return GaugeCard(metrics: metrics)
        .frame(width: 400)
        .padding()
}
