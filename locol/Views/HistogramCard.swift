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
        if value == 0 {
            return "0"
        }
        if value >= 1_000_000 {
            return String(format: "%.0fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        }
        if value < 0.01 {
            return String(format: "%.2e", value)
        }
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        if value >= 10 {
            return String(format: "%.1f", value)
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
                ForEach(histogram.nonInfiniteBuckets) { bucket in
                    BarMark(
                        x: .value("Bucket", (bucket.upperBound + bucket.lowerBound) / 2 as Double),
                        y: .value("Count", bucket.bucketValue as Double)
                    )
                    .foregroundStyle(bucket.id == selectedBucket?.id ? Color.blue : Color.blue.opacity(0.7))
                }
                
                RuleMark(
                    x: .value("p50", histogram.p50 as Double)
                )
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                RuleMark(
                    x: .value("p95", histogram.p95 as Double)
                )
                .foregroundStyle(Color.orange)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                RuleMark(
                    x: .value("p99", histogram.p99 as Double)
                )
                .foregroundStyle(Color.red)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            //.chartXScale(domain: histogram.xAxisDomain)
            //.chartYScale(domain: .automatic(includesZero: true))
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
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
                                    selectedBucket = nil
                                    return
                                }
                                
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
            
            if let selected = selectedBucket {
                ChartTooltip(
                    upperBound: selected.upperBound,
                    count: selected.count,
                    bucketValue: selected.bucketValue,
                    lowerBound: selected.lowerBound,
                    totalCount: histogram.count
                )
            } else {
                ChartLegend()
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
        
        // Create 10 fixed-width buckets from 0 to 100ms
        let bucketBoundaries = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
        
        var samples: [(labels: [String: String], value: Double)] = []
        let totalSamples = 1000.0
        let mean = 50.0  // Center at 50ms
        let stdDev = 15.0  // Most data between 20-80ms
        
        // Generate bucket samples
        var prevProb = 0.0
        for bound in bucketBoundaries {
            // Calculate probability for this bucket using the normal CDF
            let z = (bound - mean) / stdDev
            let prob = (1.0 + erf(z / sqrt(2.0))) / 2.0
            
            var bucketLabels = labels
            bucketLabels["le"] = String(bound)
            samples.append((labels: bucketLabels, value: prob * totalSamples))
            
            prevProb = prob
        }
        
        // Add infinity bucket
        var infLabels = labels
        infLabels["le"] = "+Inf"
        samples.append((labels: infLabels, value: totalSamples))
        
        // Add _sum and _count
        samples.append((labels: labels, value: totalSamples * mean))  // sum
        samples.append((labels: labels, value: totalSamples))  // count
        
        // Create histogram from samples
        let histogram = HistogramMetric.from(
            samples: samples,
            timestamp: now
        )!
        
        let metric = Metric(
            name: "Response Time (ms)",
            type: .histogram,
            help: "API response time distribution",
            labels: labels,
            timestamp: now,
            value: totalSamples * mean,
            histogram: histogram
        )
        
        return HistogramCard(metric: metric, histogram: histogram)
            .frame(width: 800)
            .padding()
    }
} 
#endif
