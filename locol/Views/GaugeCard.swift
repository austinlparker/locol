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
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                Text(metrics[0].name)
                    .font(.headline)
                
                // Chart
                switch visualization {
                case .number:
                    NumberView(value: metrics.last?.value ?? 0, metric: metrics[0])
                case .radial:
                    RadialView(value: metrics.last?.value ?? 0, metric: metrics[0])
                case .lineChart:
                    LineChartView(metrics: metrics, selectedValue: $selectedValue)
                }
            }
            .padding()
        }
    }
}

private struct LineChartView: View {
    let metrics: [Metric]
    @Binding var selectedValue: (timestamp: Date, value: Double)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Value Over Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Chart {
                    ForEach(metrics, id: \.timestamp) { metric in
                        LineMark(
                            x: .value("Time", metric.timestamp),
                            y: .value("Value", metric.value)
                        )
                        .foregroundStyle(Color.blue)
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
                                        selectedValue = nil
                                        return
                                    }
                                    
                                    guard let timestamp = proxy.value(atX: x) as Date?,
                                          let value = proxy.value(atX: x, as: Double.self) else { return }
                                    
                                    selectedValue = (timestamp: timestamp, value: value)
                                    
                                case .ended:
                                    selectedValue = nil
                                }
                            }
                    }
                }
                
                // Legend or Tooltip area with fixed height
                if let selectedValue = selectedValue {
                    ChartTooltip(timestamp: selectedValue.timestamp, value: selectedValue.value, metric: metrics[0])
                } else {
                    ChartLegend(value: metrics.last?.value ?? 0, metric: metrics[0])
                }
            }
        }
    }
}

private struct ChartTooltip: View {
    let timestamp: Date
    let value: Double
    let metric: Metric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timestamp.formatted(.dateTime.hour().minute().second()))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                LabelDisplay(labels: metric.labels, showAll: false, showOnlyPrimary: true)
                Text(metric.formatValueWithInferredUnit(value))
                    .font(.caption.bold())
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
    let value: Double
    let metric: Metric
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            LabelDisplay(labels: metric.labels, showAll: false)
            Text(metric.formatValueWithInferredUnit(value))
                .font(.caption.bold())
        }
        .padding(.vertical, 6)
        .frame(height: 28)
        .frame(maxWidth: .infinity)
    }
}

private struct NumberView: View {
    let value: Double
    let metric: Metric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Value")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(metric.formatValueWithInferredUnit(value))
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}

private struct RadialView: View {
    let value: Double
    let metric: Metric
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Gauge(value: min(max(value, 0), value + 100), in: 0...(value + 100)) {
                Text(metric.formatValueWithInferredUnit(value))
            } currentValueLabel: {
                Text(metric.formatValueWithInferredUnit(value))
                    .font(.system(.headline, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .scaleEffect(2.5)
            .frame(height: 120)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

#if DEBUG
struct GaugeCard_Previews: PreviewProvider {
    static var previews: some View {
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
} 
#endif
