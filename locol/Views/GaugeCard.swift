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
    @State private var visualization: GaugeVisualization = .number
    @State private var selectedValue: (date: Date, value: Double)? = nil
    
    private var currentValue: Double {
        metrics.last?.value ?? 0
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(metrics: metrics, visualization: $visualization)
                
                // Visualization
                switch visualization {
                case .number:
                    NumberView(value: currentValue)
                case .radial:
                    RadialView(value: currentValue)
                case .lineChart:
                    LineChartView(metrics: metrics, selectedValue: $selectedValue)
                }
            }
            .padding(16)
        }
    }
}

private struct CardHeader: View {
    let metrics: [Metric]
    @Binding var visualization: GaugeVisualization
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metrics.first?.name ?? "")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let labels = metrics.first?.labels,
                       !labels.isEmpty {
                        Text(labels.formattedLabels())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Visualization toggle
            Picker("", selection: $visualization) {
                ForEach([GaugeVisualization.number, .radial, .lineChart], id: \.self) { type in
                    Image(systemName: type.icon)
                        .help(String(describing: type))
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .labelsHidden()
        }
    }
}

private struct NumberView: View {
    let value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Value")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f", value))
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}

private struct RadialView: View {
    let value: Double
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Gauge(value: min(max(value, 0), value + 100), in: 0...(value + 100)) {
                Text(String(format: "%.1f", value))
            } currentValueLabel: {
                Text(String(format: "%.1f", value))
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

private struct ChartTooltip: View {
    let date: Date
    let value: Double
    
    var body: some View {
        HStack(spacing: 8) {
            Text(date, format: .dateTime.hour().minute().second())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("•")
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f", value))
                .font(.caption.bold())
                .foregroundStyle(.primary)
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
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            Text("Value")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .frame(height: 28)
        .frame(maxWidth: .infinity)
    }
}

private struct ChartOverlay: View {
    let proxy: ChartProxy
    let metrics: [Metric]
    @Binding var selectedValue: (date: Date, value: Double)?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
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
                            
                            // Find closest metric based on x position
                            let relativeXPosition = x / geometry[plotFrame].width
                            let dateRange = metrics.map(\.timestamp)
                            guard let minDate = dateRange.min(),
                                  let maxDate = dateRange.max() else { return }
                            
                            let date = Date(timeIntervalSince1970: 
                                minDate.timeIntervalSince1970 +
                                (maxDate.timeIntervalSince1970 - minDate.timeIntervalSince1970) * relativeXPosition
                            )
                            
                            if let closest = metrics.min(by: {
                                abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
                            }) {
                                selectedValue = (closest.timestamp, closest.value)
                            }
                        case .ended:
                            selectedValue = nil
                        }
                    }
            }
        }
    }
}

private struct LineChartView: View {
    let metrics: [Metric]
    @Binding var selectedValue: (date: Date, value: Double)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Value Over Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Chart {
                    ForEach(metrics) { metric in
                        LineMark(
                            x: .value("Time", metric.timestamp),
                            y: .value("Value", metric.value)
                        )
                        .foregroundStyle(by: .value("Series", "Value"))
                        .interpolationMethod(.monotone)
                    }
                    
                    if let selected = selectedValue {
                        RuleMark(
                            x: .value("Time", selected.date)
                        )
                        .foregroundStyle(.gray.opacity(0.3))
                        
                        PointMark(
                            x: .value("Time", selected.date),
                            y: .value("Value", selected.value)
                        )
                        .foregroundStyle(.primary)
                    }
                }
                .chartForegroundStyleScale([
                    "Value": Color.blue
                ])
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let val = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.1f", val))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.hour().minute())
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .frame(height: 200)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(.background.opacity(0.5))
                        .border(.quaternary)
                }
                .chartOverlay(alignment: .top) { proxy in
                    ChartOverlay(
                        proxy: proxy,
                        metrics: metrics,
                        selectedValue: $selectedValue
                    )
                }
                
                // Legend or Tooltip area with fixed height
                if let selected = selectedValue {
                    ChartTooltip(date: selected.date, value: selected.value)
                } else {
                    ChartLegend()
                }
            }
        }
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
