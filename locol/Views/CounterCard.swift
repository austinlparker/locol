import SwiftUI
import Charts

struct CounterCard: View {
    let name: String
    let series: [CounterSeries]
    @State private var selectedPoint: (timestamp: Date, rates: [(series: CounterSeries, rate: Double)])? = nil
    
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
    @Binding var selectedPoint: (timestamp: Date, rates: [(series: CounterSeries, rate: Double)])?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rate Over Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Chart {
                    ForEach(series, id: \.name) { series in
                        ForEach(series.metrics.indices.dropLast(), id: \.self) { index in
                            let current = series.metrics[index]
                            let next = series.metrics[index + 1]
                            let rate = (next.value - current.value) / next.timestamp.timeIntervalSince(current.timestamp)
                            
                            LineMark(
                                x: .value("Time", current.timestamp),
                                y: .value("Rate", rate)
                            )
                            .foregroundStyle(by: .value("Series", series.labels.formattedPrimaryLabels()))
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
                                    
                                    var rates: [(series: CounterSeries, rate: Double)] = []
                                    for series in series {
                                        if let index = series.metrics.firstIndex(where: { $0.timestamp >= timestamp }),
                                           index > 0 {
                                            let current = series.metrics[index - 1]
                                            let next = series.metrics[index]
                                            let rate = (next.value - current.value) / next.timestamp.timeIntervalSince(current.timestamp)
                                            rates.append((series: series, rate: rate))
                                        }
                                    }
                                    
                                    selectedPoint = (timestamp: timestamp, rates: rates)
                                    
                                case .ended:
                                    selectedPoint = nil
                                }
                            }
                    }
                }
                
                // Legend or Tooltip area with fixed height
                if let selectedPoint = selectedPoint {
                    ChartTooltip(timestamp: selectedPoint.timestamp, rates: selectedPoint.rates)
                } else {
                    ChartLegend(series: series)
                }
            }
        }
    }
}

private struct ChartTooltip: View {
    let timestamp: Date
    let rates: [(series: CounterSeries, rate: Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timestamp.formatted(.dateTime.hour().minute().second()))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(rates, id: \.series.name) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    LabelDisplay(labels: item.series.labels, showAll: false, showOnlyPrimary: true)
                    Text((item.series.metrics.first?.formatValueWithInferredUnit(item.rate))! + "/s")
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
            ForEach(series, id: \.name) { series in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue)
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
    CounterCard(
        name: "Test Counter",
        series: [
            CounterSeries(
                name: "test_counter{label=value1}",
                metrics: [
                    Metric(
                        name: "test_counter",
                        type: .counter,
                        help: "Test counter metric",
                        labels: ["label": "value1"],
                        timestamp: Date().addingTimeInterval(-60),
                        value: 0,
                        histogram: nil
                    ),
                    Metric(
                        name: "test_counter",
                        type: .counter,
                        help: "Test counter metric",
                        labels: ["label": "value1"],
                        timestamp: Date().addingTimeInterval(-30),
                        value: 50,
                        histogram: nil
                    ),
                    Metric(
                        name: "test_counter",
                        type: .counter,
                        help: "Test counter metric",
                        labels: ["label": "value1"],
                        timestamp: Date(),
                        value: 100,
                        histogram: nil
                    )
                ],
                labels: ["label": "value1"],
                currentRate: 1.67
            ),
            CounterSeries(
                name: "test_counter{label=value2}",
                metrics: [
                    Metric(
                        name: "test_counter",
                        type: .counter,
                        help: "Test counter metric",
                        labels: ["label": "value2"],
                        timestamp: Date().addingTimeInterval(-60),
                        value: 0,
                        histogram: nil
                    ),
                    Metric(
                        name: "test_counter",
                        type: .counter,
                        help: "Test counter metric",
                        labels: ["label": "value2"],
                        timestamp: Date().addingTimeInterval(-30),
                        value: 25,
                        histogram: nil
                    ),
                    Metric(
                        name: "test_counter",
                        type: .counter,
                        help: "Test counter metric",
                        labels: ["label": "value2"],
                        timestamp: Date(),
                        value: 50,
                        histogram: nil
                    )
                ],
                labels: ["label": "value2"],
                currentRate: 0.83
            )
        ]
    )
} 

