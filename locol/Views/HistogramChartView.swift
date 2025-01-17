import SwiftUI
import Charts

struct HistogramChartView: View {
    let histogram: HistogramMetric
    @State private var selectedBucket: (upperBound: Double, count: Double)? = nil
    
    private var nonInfBuckets: [(upperBound: Double, count: Double)] {
        histogram.buckets.filter { !$0.upperBound.isInfinite }
            .sorted { $0.upperBound < $1.upperBound }
            .map { (upperBound: $0.upperBound, count: $0.count) }
    }
    
    private var maxCount: Double {
        histogram.buckets.map(\.count).max() ?? 0
    }
    
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
            // Stats row
            HStack(spacing: 16) {
                StatBox(title: "Count", value: String(format: "%.0f", histogram.count))
                StatBox(title: "Sum", value: String(format: "%.2f", histogram.sum))
                StatBox(title: "Average", value: String(format: "%.2f", histogram.average))
                StatBox(title: "p50", value: String(format: "%.2f", histogram.p50))
                StatBox(title: "p95", value: String(format: "%.2f", histogram.p95))
                StatBox(title: "p99", value: String(format: "%.2f", histogram.p99))
            }
            
            // Chart
            Chart {
                // Bucket bars
                ForEach(nonInfBuckets.indices, id: \.self) { index in
                    let bucket = nonInfBuckets[index]
                    let previousCount = index > 0 ? nonInfBuckets[index - 1].count : 0
                    let bucketValue = bucket.count - previousCount
                    
                    BarMark(
                        x: .value("Upper Bound", formatBucketLabel(bucket.upperBound)),
                        y: .value("Count", bucketValue)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                }
                
                // Cumulative line
                ForEach(nonInfBuckets.indices, id: \.self) { index in
                    let bucket = nonInfBuckets[index]
                    LineMark(
                        x: .value("Upper Bound", formatBucketLabel(bucket.upperBound)),
                        y: .value("Cumulative", bucket.count)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.monotone)
                }
                
                // Percentile markers
                RuleMark(
                    x: .value("Median", formatBucketLabel(histogram.p50))
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                RuleMark(
                    x: .value("p95", formatBucketLabel(histogram.p95))
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                RuleMark(
                    x: .value("p99", formatBucketLabel(histogram.p99))
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let string = value.as(String.self) {
                            Text(string)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
            }
            .frame(height: 200)
            .chartBackground { proxy in
                ZStack(alignment: .topLeading) {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if !hovering {
                                    selectedBucket = nil
                                }
                            }
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = location.x - geometry[plotFrame].origin.x
                                    selectedBucket = findBucket(at: x, proxy: proxy, geometry: geometry)
                                case .ended:
                                    selectedBucket = nil
                                }
                            }
                    }
                }
            }
            
            // Selected bucket info
            if let bucket = selectedBucket {
                HStack {
                    Text("≤ \(formatBucketLabel(bucket.upperBound))")
                        .foregroundStyle(.secondary)
                    Text("Count: \(String(format: "%.0f", bucket.count))")
                        .foregroundStyle(.primary)
                }
                .font(.caption)
                .padding(.vertical, 4)
            }
        }
    }
    
    private func findBucket(at x: CGFloat, proxy: ChartProxy, geometry: GeometryProxy) -> (upperBound: Double, count: Double)? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let relativeX = x / geometry[plotFrame].width
        let bucketWidth = geometry[plotFrame].width / CGFloat(nonInfBuckets.count)
        let index = Int(relativeX * CGFloat(nonInfBuckets.count))
        
        guard index >= 0 && index < nonInfBuckets.count else {
            return nil
        }
        
        return nonInfBuckets[index]
    }
}

#Preview {
    let previewBuckets = [
        HistogramMetric.Bucket(upperBound: 0.1, count: 10.0),
        HistogramMetric.Bucket(upperBound: 0.2, count: 25.0),
        HistogramMetric.Bucket(upperBound: 0.5, count: 45.0),
        HistogramMetric.Bucket(upperBound: 1.0, count: 80.0),
        HistogramMetric.Bucket(upperBound: Double.infinity, count: 100.0)
    ]
    
    HistogramChartView(histogram: HistogramMetric(
        buckets: previewBuckets,
        sum: 75.0,
        count: 100.0,
        timestamp: Date(),
        labels: [:]
    ))
    .padding()
} 
