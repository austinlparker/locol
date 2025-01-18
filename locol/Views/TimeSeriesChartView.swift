import SwiftUI
import Charts

struct TimeSeriesChartView: View {
    let metrics: [Metric]
    
    var body: some View {
        Chart {
            ForEach(metrics) { metric in
                LineMark(
                    x: .value("Time", metric.timestamp),
                    y: .value("Value", metric.value)
                )
            }
        }
    }
} 