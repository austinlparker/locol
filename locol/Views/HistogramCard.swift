import SwiftUI
import Charts

struct HistogramCard: View {
    let metric: Metric
    let histogram: HistogramMetric
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(metric: metric)
                StatsGrid(histogram: histogram)
                HistogramChartView(histogram: histogram)
            }
            .padding(16)
        }
    }
}

private struct CardHeader: View {
    let metric: Metric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.name)
                .font(.headline)
                .foregroundStyle(.primary)
            if !metric.labels.isEmpty {
                Text(metric.labels.formattedLabels())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatsGrid: View {
    let histogram: HistogramMetric
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatView(title: "Count", value: String(format: "%.0f", histogram.count))
            StatView(title: "Sum", value: String(format: "%.2f", histogram.sum))
            StatView(title: "Average", value: String(format: "%.2f", histogram.average))
            StatView(title: "p50", value: String(format: "%.2f", histogram.p50))
            StatView(title: "p95", value: String(format: "%.2f", histogram.p95))
            StatView(title: "p99", value: String(format: "%.2f", histogram.p99))
        }
        .padding(.vertical, 8)
    }
}

private struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

private struct HistogramChartView: View {
    let histogram: HistogramMetric
    @State private var selectedBucket: HistogramMetric.Bucket? = nil
    
    private func formatBucketLabel(_ value: Double) -> String {
        if value.isInfinite {
            return "∞"
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        if value < 0.01 {
            return String(format: "%.2e", value)
        }
        return String(format: "%.2f", value)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Distribution")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            BucketChart(
                histogram: histogram,
                selectedBucket: $selectedBucket,
                formatBucketLabel: formatBucketLabel
            )
        }
    }
}

private struct BucketChart: View {
    let histogram: HistogramMetric
    @Binding var selectedBucket: HistogramMetric.Bucket?
    let formatBucketLabel: (Double) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart {
                // Bucket bars
                ForEach(histogram.nonInfiniteBuckets) { bucket in
                    if let index = histogram.nonInfiniteBuckets.firstIndex(where: { $0.id == bucket.id }) {
                        let bucketValue = histogram.bucketValue(at: index)
                        BarMark(
                            x: .value("Upper Bound", bucket.upperBound),
                            y: .value("Count", bucketValue)
                        )
                        .foregroundStyle(Color.blue.opacity(0.7))
                    }
                }
                
                // Percentile markers
                RuleMark(x: .value("p50", histogram.p50))
                    .foregroundStyle(by: .value("Series", "p50"))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                RuleMark(x: .value("p95", histogram.p95))
                    .foregroundStyle(by: .value("Series", "p95"))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                RuleMark(x: .value("p99", histogram.p99))
                    .foregroundStyle(by: .value("Series", "p99"))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                if let selected = selectedBucket,
                   let index = histogram.nonInfiniteBuckets.firstIndex(where: { $0.id == selected.id }) {
                    let bucketValue = histogram.bucketValue(at: index)
                    
                    RuleMark(x: .value("Selected", selected.upperBound))
                        .foregroundStyle(.gray.opacity(0.3))
                    
                    BarMark(
                        x: .value("Upper Bound", selected.upperBound),
                        y: .value("Count", bucketValue)
                    )
                    .foregroundStyle(Color.blue)
                }
            }
            .chartForegroundStyleScale([
                "p50": Color.green,
                "p95": Color.orange,
                "p99": Color.red
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let count = value.as(Double.self) {
                        AxisValueLabel {
                            Text(String(format: "%.0f", count))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    if let number = value.as(Double.self) {
                        AxisValueLabel {
                            Text(formatBucketLabel(number))
                                .font(.caption)
                                .rotationEffect(.degrees(-45))
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
                BucketChartOverlay(
                    proxy: proxy,
                    histogram: histogram,
                    selectedBucket: $selectedBucket
                )
            }
            
            // Legend or Tooltip area with fixed height
            if let selected = selectedBucket,
               let index = histogram.nonInfiniteBuckets.firstIndex(where: { $0.id == selected.id }) {
                let bucketValue = histogram.bucketValue(at: index)
                let lowerBound = histogram.lowerBoundForBucket(at: index)
                ChartTooltip(
                    upperBound: selected.upperBound,
                    count: selected.count,
                    bucketValue: bucketValue,
                    lowerBound: lowerBound,
                    totalCount: histogram.count
                )
            } else {
                ChartLegend()
            }
        }
    }
}

private struct BucketChartOverlay: View {
    let proxy: ChartProxy
    let histogram: HistogramMetric
    @Binding var selectedBucket: HistogramMetric.Bucket?
    
    var body: some View {
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
                            selectedBucket = nil
                            return
                        }
                        
                        // Find closest bucket based on x position
                        let relativeXPosition = x / geometry[plotFrame].width
                        let bucketIndex = Int(relativeXPosition * Double(histogram.nonInfiniteBuckets.count))
                        if bucketIndex >= 0, bucketIndex < histogram.nonInfiniteBuckets.count {
                            selectedBucket = histogram.nonInfiniteBuckets[bucketIndex]
                        }
                    case .ended:
                        selectedBucket = nil
                    }
                }
        }
    }
}

private struct ChartTooltip: View {
    let upperBound: Double
    let count: Double
    let bucketValue: Double
    let lowerBound: Double
    let totalCount: Double
    
    private var percentage: Double {
        (count / totalCount) * 100
    }
    
    private func formatValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(formatValue(lowerBound)) - \(formatValue(upperBound))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("•")
                .foregroundStyle(.secondary)
            Text("\(Int(count))")
                .font(.caption.bold())
            Text("(\(String(format: "%.1f%%", percentage)))")
                .font(.caption)
                .foregroundColor(.secondary)
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
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 12, height: 8)
                Text("Bucket Count")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(["p50", "p95", "p99"], id: \.self) { percentile in
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(percentileColor(for: percentile))
                        .frame(width: 12, height: 1)
                    Text(percentile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(height: 28)
        .frame(maxWidth: .infinity)
    }
    
    private func percentileColor(for percentile: String) -> Color {
        switch percentile {
        case "p50": return .green
        case "p95": return .orange
        case "p99": return .red
        default: return .gray
        }
    }
}

#if DEBUG
struct HistogramCard_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let labels = ["operation": "request", "path": "/api/data"]
        
        let metric = Metric(
            name: "Test Histogram",
            type: .histogram,
            help: "test histogram",
            labels: labels,
            timestamp: now,
            value: 1000,
            histogram: nil
        )
        
        let histogram = HistogramMetric(
            buckets: [
                HistogramMetric.Bucket(id: 0, upperBound: 10.0, count: 100),
                HistogramMetric.Bucket(id: 1, upperBound: 50.0, count: 300),
                HistogramMetric.Bucket(id: 2, upperBound: 100.0, count: 600),
                HistogramMetric.Bucket(id: 3, upperBound: 500.0, count: 850),
                HistogramMetric.Bucket(id: 4, upperBound: Double.infinity, count: 1000)
            ],
            sum: 5432.1,
            count: 1000,
            timestamp: now,
            labels: labels
        )
        
        return HistogramCard(metric: metric, histogram: histogram)
            .frame(width: 800)
            .padding()
    }
} 
#endif
