import SwiftUI
import Charts

struct HistogramCard: View {
    let metric: Metric
    let histogram: HistogramMetric
    @State private var selectedBucket: HistogramMetric.Bucket? = nil
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                Text(metric.name)
                    .font(.headline)
                
                // Chart
                BucketChart(histogram: histogram, metric: metric, selectedBucket: $selectedBucket)
                    .frame(height: 200)
            }
            .padding()
        }
    }
}

private struct BucketChart: View {
    let histogram: HistogramMetric
    let metric: Metric
    @Binding var selectedBucket: HistogramMetric.Bucket?
    
    private var chartContent: some View {
        Chart {
            ForEach(histogram.nonInfiniteBuckets) { bucket in
                BarMark(
                    x: .value("Bucket", Double(bucket.id)),
                    y: .value("Count", bucket.bucketValue),
                    width: 30
                )
                .foregroundStyle(bucket.id == selectedBucket?.id ? Color.blue : Color.blue.opacity(0.7))
            }
            
            RuleMark(x: .value("p50", Double(histogram.p50Index)))
                .foregroundStyle(.green)
            
            RuleMark(x: .value("p95", Double(histogram.p95Index)))
                .foregroundStyle(.yellow)
            
            RuleMark(x: .value("p99", Double(histogram.p99Index)))
                .foregroundStyle(.red)
        }
        .chartXScale(domain: histogram.chartDomain)
        .chartXAxis {
            AxisMarks { value in
                if let index = value.as(Double.self)?.rounded(.down),
                   let bucket = histogram.bucketAtIndex(Int(index)) {
                    AxisValueLabel {
                        Text(metric.formatValueWithInferredUnit(bucket.upperBound))
                            .font(.caption)
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    Text(String(format: "%.0f", value.as(Double.self)!))
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
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Distribution")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                chartContent
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        guard let plotFrame = proxy.plotFrame,
                                              let bucketIndex = proxy.value(atX: location.x - geometry[plotFrame].origin.x) as Double? else {
                                            selectedBucket = nil
                                            return
                                        }
                                        
                                        selectedBucket = histogram.bucketAtIndex(Int(round(bucketIndex)))
                                        
                                    case .ended:
                                        selectedBucket = nil
                                    }
                                }
                        }
                    }
                
                if let selectedBucket = selectedBucket {
                    ChartTooltip(bucket: selectedBucket, metric: metric)
                } else {
                    ChartLegend(histogram: histogram, metric: metric)
                }
            }
        }
    }
}

private struct ChartTooltip: View {
    let bucket: HistogramMetric.Bucket
    let metric: Metric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(metric.formatValueWithInferredUnit(bucket.lowerBound)) - \(metric.formatValueWithInferredUnit(bucket.upperBound))")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                LabelDisplay(labels: metric.labels, showAll: false, showOnlyPrimary: true)
                Text("\(Int(bucket.bucketValue)) samples (\(String(format: "%.1f%%", bucket.percentage)))")
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
    let histogram: HistogramMetric
    let metric: Metric
    
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                LabelDisplay(labels: metric.labels, showAll: false)
                Text("\(Int(histogram.count)) samples")
                    .font(.caption.bold())
            }
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("p50: \(metric.formatValueWithInferredUnit(histogram.p50))")
                    .font(.caption.bold())
            }
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                Text("p95: \(metric.formatValueWithInferredUnit(histogram.p95))")
                    .font(.caption.bold())
            }
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("p99: \(metric.formatValueWithInferredUnit(histogram.p99))")
                    .font(.caption.bold())
            }
        }
        .padding(.vertical, 6)
        .frame(height: 28)
        .frame(maxWidth: .infinity)
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
