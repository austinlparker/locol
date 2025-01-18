import SwiftUI
import Charts

struct CounterCard: View {
    let metrics: [Metric]
    let viewModel: MetricsViewModel
    let rateInterval: RateInterval
    @State private var selectedRate: (date: Date, rate: Double)? = nil
    
    private var currentRate: Double? {
        guard let key = metrics.first?.id else { return nil }
        return viewModel.getRate(for: key, interval: rateInterval.seconds)
    }
    
    private var rateMetrics: [RateMetric] {
        guard metrics.count >= 2 else { return [] }
        
        return zip(metrics.dropLast(), metrics.dropFirst()).map { prev, curr in
            let timeDiff = curr.timestamp.timeIntervalSince(prev.timestamp)
            let valueDiff = curr.value - prev.value
            let rate = timeDiff > 0 ? valueDiff / timeDiff : 0
            return RateMetric(timestamp: curr.timestamp, rate: rate)
        }
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(metrics: metrics)
                StatsView(metrics: metrics, currentRate: currentRate, rateInterval: rateInterval)
                RateChartView(
                    rateMetrics: rateMetrics,
                    currentRate: currentRate,
                    rateInterval: rateInterval,
                    selectedRate: $selectedRate
                )
            }
            .padding(16)
        }
    }
}

private struct CardHeader: View {
    let metrics: [Metric]
    
    var body: some View {
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
    }
}

private struct StatsView: View {
    let metrics: [Metric]
    let currentRate: Double?
    let rateInterval: RateInterval
    
    var body: some View {
        HStack(spacing: 24) {
            if let lastValue = metrics.last?.value {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f", lastValue))
                        .font(.system(.title2, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            
            if let rate = currentRate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(rateInterval.description) Rate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f/sec", rate))
                        .font(.system(.title2, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct ChartTooltip: View {
    let date: Date
    let rate: Double
    
    var body: some View {
        HStack(spacing: 8) {
            Text(date, format: .dateTime.hour().minute().second())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("•")
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f/sec", rate))
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
    let rateInterval: RateInterval
    
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text("Instantaneous Rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: 12, height: 1)
                Text("\(rateInterval.description) Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .frame(height: 28)
        .frame(maxWidth: .infinity)
    }
}

private struct ChartOverlay: View {
    let proxy: ChartProxy
    let rateMetrics: [RateMetric]
    @Binding var selectedRate: (date: Date, rate: Double)?
    
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
                                selectedRate = nil
                                return
                            }
                            
                            // Find closest metric based on x position
                            let relativeXPosition = x / geometry[plotFrame].width
                            let timeRange = rateMetrics.map(\.timestamp)
                            guard let minTime = timeRange.min(),
                                  let maxTime = timeRange.max() else { return }
                            
                            let date = Date(timeIntervalSince1970: 
                                minTime.timeIntervalSince1970 +
                                (maxTime.timeIntervalSince1970 - minTime.timeIntervalSince1970) * relativeXPosition
                            )
                            
                            if let closest = rateMetrics.min(by: {
                                abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
                            }) {
                                selectedRate = (closest.timestamp, closest.rate)
                            }
                        case .ended:
                            selectedRate = nil
                        }
                    }
            }
        }
    }
}

private struct RateChartView: View {
    let rateMetrics: [RateMetric]
    let currentRate: Double?
    let rateInterval: RateInterval
    @Binding var selectedRate: (date: Date, rate: Double)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rate Over Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Chart {
                    ForEach(rateMetrics) { metric in
                        LineMark(
                            x: .value("Time", metric.timestamp),
                            y: .value("Rate", metric.rate)
                        )
                        .foregroundStyle(by: .value("Series", "Instantaneous Rate"))
                        .interpolationMethod(.monotone)
                    }
                    
                    if let rate = currentRate {
                        RuleMark(
                            y: .value("Current Rate", rate)
                        )
                        .foregroundStyle(by: .value("Series", "\(rateInterval.description) Average"))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                    
                    if let selected = selectedRate {
                        RuleMark(
                            x: .value("Time", selected.date)
                        )
                        .foregroundStyle(.gray.opacity(0.3))
                        
                        PointMark(
                            x: .value("Time", selected.date),
                            y: .value("Rate", selected.rate)
                        )
                        .foregroundStyle(.primary)
                    }
                }
                .chartForegroundStyleScale([
                    "Instantaneous Rate": Color.blue,
                    "\(rateInterval.description) Average": Color.red.opacity(0.5)
                ])
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let rate = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.1f", rate))
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
                        rateMetrics: rateMetrics,
                        selectedRate: $selectedRate
                    )
                }
                
                // Legend or Tooltip area with fixed height
                if let selected = selectedRate {
                    ChartTooltip(date: selected.date, rate: selected.rate)
                } else {
                    ChartLegend(rateInterval: rateInterval)
                }
            }
        }
    }
}

private struct RateMetric: Identifiable {
    let id = UUID()
    let timestamp: Date
    let rate: Double
}

#if DEBUG
struct CounterCard_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let metrics = (0..<10).map { i in
            Metric(
                name: "Test Counter",
                type: .counter,
                help: "help text",
                labels: ["service": "api", "endpoint": "/users"],
                timestamp: now.addingTimeInterval(TimeInterval(i * 60)),
                value: Double(i * 100),
                histogram: nil
            )
        }
        
        return CounterCard(
            metrics: metrics,
            viewModel: MetricsViewModel(),
            rateInterval: .oneMinute
        )
        .frame(width: 400)
        .padding()
    }
}
#endif 
