import SwiftUI
import Charts

struct HistogramCard: View {
    let metric: Metric
    let histogram: HistogramMetric
    @State private var selectedPoint: (bucket: HistogramMetric.Bucket, count: Int)? = nil
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                Text(metric.name)
                    .font(.headline)
                
                // Chart
                BucketChart(histogram: histogram, selectedPoint: $selectedPoint)
                    .frame(height: 200)
            }
            .padding()
        }
    }
}

private struct BucketChart: View {
    let histogram: HistogramMetric
    @Binding var selectedPoint: (bucket: HistogramMetric.Bucket, count: Int)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Distribution")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ChartContainer {
                Chart {
                    ForEach(histogram.nonInfiniteBuckets, id: \.id) { bucket in
                        BarMark(
                            x: .value("Bucket", bucket.id),
                            y: .value("Count", bucket.bucketValue)
                        )
                        .foregroundStyle(bucket.bucketValue > 0 ? Color.blue : Color.blue.opacity(0.1))
                    }
                    
                    if let selectedPoint = selectedPoint {
                        RuleMark(x: .value("Selected", selectedPoint.bucket.id))
                            .foregroundStyle(.gray.opacity(0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let index = value.as(Int.self),
                           let bucket = histogram.bucketAtIndex(index) {
                            AxisValueLabel {
                                Text(formatBucketLabel(bucket.upperBound))
                                    .font(.caption)
                                    .rotationEffect(.degrees(-45))
                                    .offset(y: 10)
                            }
                            AxisTick()
                            AxisGridLine()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let val = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(val))")
                                    .font(.caption)
                            }
                        }
                        AxisTick()
                        AxisGridLine()
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
                                    
                                    guard let bucketIndex = proxy.value(atX: x) as Int?,
                                          let bucket = histogram.bucketAtIndex(bucketIndex) else {
                                        return
                                    }
                                    
                                    selectedPoint = (bucket: bucket, count: Int(bucket.bucketValue))
                                    
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
                            if histogram.nonInfiniteBuckets.contains(where: { $0.id == selectedPoint.bucket.id }) {
                                Text("\(formatBucketLabel(selectedPoint.bucket.lowerBound)) - \(formatBucketLabel(selectedPoint.bucket.upperBound))")
                                    .font(.caption)
                            }
                            HStack(spacing: 8) {
                                MetricLegendItem(
                                    color: .blue,
                                    label: "\(selectedPoint.count) samples"
                                )
                                Text("(\(Int(selectedPoint.bucket.percentage))%)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    BaseTooltip {
                        HStack(spacing: 16) {
                            Text("\(Int(histogram.totalCount)) samples")
                                .font(.caption)
                            HStack(spacing: 8) {
                                MetricLegendItem(color: .green, label: "p50: \(formatBucketLabel(histogram.p50))")
                                MetricLegendItem(color: .yellow, label: "p95: \(formatBucketLabel(histogram.p95))")
                                MetricLegendItem(color: .red, label: "p99: \(formatBucketLabel(histogram.p99))")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func formatBucketLabel(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

#if DEBUG
struct HistogramCard_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let labels = [
            "processor": "batch",
            "service_instance_id": "f8b0a006-7bd8-4890-a411-3db118b918cb",
            "service_name": "otelcol-contrib",
            "service_version": "0.117.0"
        ]
        
        // Create buckets from the OpenTelemetry data
        let bucketBoundaries = [10.0, 25.0, 50.0, 75.0, 100.0, 250.0, 500.0, 750.0, 1000.0, 2000.0, 3000.0, 4000.0, 5000.0, 6000.0, 7000.0, 8000.0, 9000.0, 10000.0, 20000.0, 30000.0, 50000.0, 100000.0]
        
        var samples: [(labels: [String: String], value: Double)] = []
        
        // Add bucket samples with cumulative counts
        for bound in bucketBoundaries {
            var bucketLabels = labels
            bucketLabels["le"] = String(bound)
            // All buckets up to 2000 have count 0, then count 1 for the rest
            samples.append((labels: bucketLabels, value: bound <= 2000 ? 0 : 1))
        }
        
        // Add infinity bucket
        var infLabels = labels
        infLabels["le"] = "+Inf"
        samples.append((labels: infLabels, value: 1))
        
        // Add sum and count
        samples.append((labels: labels, value: 2393))  // sum
        samples.append((labels: labels, value: 1))     // count
        
        // Create histogram from samples
        let histogram = HistogramMetric.from(
            samples: samples,
            timestamp: now
        )!
        
        let metric = Metric(
            name: "otelcol_processor_batch_batch_send_size",
            type: .histogram,
            help: "Number of units in the batch",
            labels: labels,
            timestamp: now,
            value: 2393,
            histogram: histogram
        )
        
        return HistogramCard(metric: metric, histogram: histogram)
            .frame(width: 800)
            .padding()
    }
} 
#endif
