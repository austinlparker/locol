import SwiftUI
import Charts
import os

struct MetricsView: View {
    let viewModel: MetricsViewModel
    @State private var selectedTimeRange: TimeRange = .oneMinute
    
    init(viewModel: MetricsViewModel = MetricsViewModel()) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            if let error = viewModel.error {
                Text(error)
                    .foregroundStyle(.red)
                    .padding()
            }
            
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedTimeRange) { _, newValue in
                viewModel.selectedTimeRange = newValue
            }
            
            List {
                ForEach(viewModel.groupedMetrics) { group in
                    Section {
                        switch group {
                        case .counters(let name, let series):
                            CounterCard(name: name, series: series)
                        case .gauge(let metrics):
                            GaugeCard(metrics: metrics)
                        case .histogram(let metric, let histogram):
                            HistogramCard(metric: metric, histogram: histogram)
                        }
                    }
                }
            }
        }
    }
}

enum RateInterval: String, CaseIterable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    
    var description: String {
        rawValue
    }
    
    var seconds: TimeInterval {
        switch self {
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 300
        case .fifteenMinutes:
            return 900
        }
    }
} 
